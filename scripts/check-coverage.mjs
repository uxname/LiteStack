#!/usr/bin/env node
//
// check-coverage.mjs — fail when a requirement has no docc: tag anywhere in the code
// (docs/adr/0011-requirements-in-docc-bind-prototype-and-code.md).
//
// A requirement is a block (a paragraph with its code ` ^k7f2`) of a document whose kind
// is marked "x-docc-covered": true in docs/schemas — the whole kind, or only the fields
// marked so. Each one needs at least one tag, in any file docc.json's trace.scan reaches:
// the prototype or the product, either counts. Notes (every other kind) need none.
//
// docc itself only checks whole documents (DOC403) and checks that every tag is fresh
// (DOC209, DOC402); this is the per-paragraph half. protokit's check-sync.mjs does the
// same for a prototype, but it leaves with the prototype — this one stays.
//
// Usage: node scripts/check-coverage.mjs [root]   (root defaults to the meta-repo)
//
import { execFileSync } from "node:child_process";
import { globSync, readdirSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";

const root = resolve(process.argv[2] ?? join(import.meta.dirname, ".."));
const config = JSON.parse(readFileSync(join(root, "docc.json"), "utf8"));

// kind → its covered fields, or null when every block of the kind is covered.
const schemasDir = join(root, config.src ?? "docs/src", "..", "schemas");
const covered = new Map();
for (const f of readdirSync(schemasDir).filter((f) => f.endsWith(".json"))) {
  const schema = JSON.parse(readFileSync(join(schemasDir, f), "utf8"));
  const fields = Object.entries(schema.properties ?? {})
    .filter(([, p]) => p["x-docc-covered"] === true)
    .map(([name]) => name);
  if (fields.length) covered.set(f.slice(0, -".json".length), new Set(fields));
  else if (schema["x-docc-covered"] === true) covered.set(f.slice(0, -".json".length), null);
}
// The field of a block is the first step of its JSON Pointer, unescaped.
const fieldOf = (p) => decodeURIComponent((p.split("/")[1] ?? "").replace(/~1/g, "/").replace(/~0/g, "~"));

let compiled;
try {
  compiled = execFileSync("docc", ["compile", "--format", "json"], { cwd: root, encoding: "utf8", maxBuffer: 64 << 20 });
} catch (e) {
  if (!e.stdout) throw e;
  compiled = e.stdout; // compile exits 1 while a hash is stale, and prints the pages anyway
}
const requirements = [];
for (const page of JSON.parse(compiled).pages) {
  if (!covered.has(page.kind)) continue;
  const fields = covered.get(page.kind);
  // A short document's fields come as props, a long one's as blocks: both carry codes.
  for (const block of [...page.blocks, ...(page.props ?? [])]) {
    if (block.code && (!fields || fields.has(fieldOf(block.p)))) requirements.push(`${page.id}#^${block.code}`);
  }
}

// The comment markers tags are written in: `//` (Go, TS), `#` (YAML, GraphQL), `--` (SQL).
const TAG = /(?:\/\/|#|--)\s*docc(?::begin)?:?\s+(.+)$/;
const files = globSync(config.trace?.scan ?? [], {
  cwd: root,
  exclude: (name) => name === "node_modules" || name === ".git",
});
const tagged = new Set();
for (const file of files) {
  let text;
  try {
    text = readFileSync(join(root, file), "utf8");
  } catch {
    continue; // a folder the mask matched
  }
  for (const line of text.split("\n")) {
    const m = line.match(TAG);
    if (!m || line.includes("docc:end")) continue;
    // `auth#^k7f2@3a9c ~e91d` → `auth#^k7f2`: the version hash and the fingerprint are docc's.
    for (const t of m[1].split(",")) tagged.add(t.trim().split(/\s/)[0].replace(/@.*$/, "").toLowerCase());
  }
}

const missing = requirements.filter((r) => !tagged.has(r));
console.log(`checked ${requirements.length} requirements against ${files.length} files`);
console.log(missing.map((r) => `${r}: no docc tag in the prototype or the product`).join("\n") || "OK");
process.exit(missing.length ? 1 : 0);
