#!/usr/bin/env node
//
// check-agent-docs.mjs — fail when an agent doc points at something that is not there
// (docs/adr/0010-agent-docs-are-checked-mechanically.md).
//
// Scans AGENTS.md, CLAUDE.md, .agents/*.md and .claude/skills/*/SKILL.md in the meta-repo
// and both submodules (they are plain folders under the root) for:
//   - relative Markdown links [text](path) to a file or folder that does not exist;
//   - `@path` imports in CLAUDE.md that do not exist;
//   - `task <name>` with no such task in any Taskfile.yml;
//   - `npm run <name>` with no such script in any package.json.
//
// Deliberate limits, see the ADR: existence only, never meaning ("`task lint` runs the
// tests" passes while `lint` exists); names are matched against the union of every
// Taskfile and package.json, because the root AGENTS.md says `npm run check` and means
// the frontend's; anchors are not checked; files outside the four globs are not read.
//
// Usage: node scripts/check-agent-docs.mjs [root]   (root defaults to the meta-repo)
//
import { existsSync, globSync, readFileSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";

const root = resolve(process.argv[2] ?? join(import.meta.dirname, ".."));
const glob = (patterns) =>
  globSync(patterns, {
    cwd: root,
    exclude: (name) => name === "node_modules" || name === ".git",
  }).sort();

const docs = glob([
  "**/AGENTS.md",
  "**/CLAUDE.md",
  "**/.agents/*.md",
  "**/.claude/skills/*/SKILL.md",
]);

// Task names are the two-space-indented keys of the top-level `tasks:` block — a YAML
// parser would be a dependency for one block of one shape.
const taskNames = (text) => {
  const names = [];
  let inside = false;
  for (const line of text.split("\n")) {
    if (/^tasks:\s*$/.test(line)) {
      inside = true;
      continue;
    }
    if (inside && /^\S/.test(line)) inside = false;
    const m = inside && line.match(/^ {2}['"]?([\w:.-]+)['"]?:/);
    if (m) names.push(m[1]);
  }
  return names;
};

const read = (rel) => readFileSync(join(root, rel), "utf8");
const tasks = new Set(glob(["**/Taskfile.yml"]).flatMap((f) => taskNames(read(f))));
const scripts = new Set(
  glob(["**/package.json"]).flatMap((f) => Object.keys(JSON.parse(read(f)).scripts ?? {})),
);

const findings = [];
for (const doc of docs) {
  const text = read(doc);
  const exists = (target) => existsSync(join(root, dirname(doc), target));
  for (const [, target] of text.matchAll(/\[[^\]]*\]\(([^)\s#]+)(?:#[^)]*)?\)/g)) {
    if (!/^[a-z]+:/.test(target) && !exists(target)) findings.push(`${doc}: broken link -> ${target}`);
  }
  if (doc.endsWith("CLAUDE.md")) {
    for (const [, target] of text.matchAll(/^@(\S+)/gm)) {
      if (!exists(target)) findings.push(`${doc}: broken import -> @${target}`);
    }
  }
  for (const name of new Set([...text.matchAll(/`task ([\w:.-]+)/g)].map((m) => m[1]))) {
    if (!tasks.has(name)) findings.push(`${doc}: unknown task -> task ${name}`);
  }
  for (const name of new Set([...text.matchAll(/`npm run ([\w:.-]+)/g)].map((m) => m[1]))) {
    if (!scripts.has(name)) findings.push(`${doc}: unknown npm script -> npm run ${name}`);
  }
}

console.log(`checked ${docs.length} agent docs under ${relative(process.cwd(), root) || "."}`);
console.log(findings.join("\n") || "OK");
process.exit(findings.length ? 1 : 0);
