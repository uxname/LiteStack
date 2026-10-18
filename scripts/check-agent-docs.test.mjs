// Self-test for check-agent-docs.mjs: one tree with every kind of reference intact, then
// the same tree with one breakage of each kind.
// Run: node --test scripts/check-agent-docs.test.mjs
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";

const checker = join(import.meta.dirname, "check-agent-docs.mjs");

const run = (files) => {
  const root = mkdtempSync(join(tmpdir(), "agent-docs-"));
  try {
    for (const [path, body] of Object.entries(files)) {
      mkdirSync(dirname(join(root, path)), { recursive: true });
      writeFileSync(join(root, path), body);
    }
    return spawnSync(process.execPath, [checker, root], { encoding: "utf8" });
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
};

const tree = (agents, claude) => ({
  "AGENTS.md": agents,
  "CLAUDE.md": claude,
  "back/Taskfile.yml": "version: '3'\ntasks:\n  test:cov:\n    cmds: [go test]\nvars:\n  notatask: x\n",
  "front/package.json": JSON.stringify({ scripts: { check: "biome" } }),
  "front/.agents/GUIDE.md": "Back to [root](../../AGENTS.md).",
  // A Taskfile under node_modules must not count as defining tasks.
  "node_modules/x/Taskfile.yml": "tasks:\n  ghost:\n",
});

test("a tree whose references all resolve passes", () => {
  const r = run(tree(
    "See [guide](./front/.agents/GUIDE.md#top), [site](https://x.dev), `task test:cov`, `npm run check`.",
    "@AGENTS.md\n",
  ));
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.match(r.stdout, /checked 3 agent docs/);
});

test("one breakage of each kind is reported, and nothing else", () => {
  const r = run(tree(
    "See [guide](./front/.agents/GUIDES.md), `task test:coverage`, `npm run checks`, `task ghost`, `task notatask`.",
    "@AGENTS-old.md\n",
  ));
  assert.equal(r.status, 1);
  assert.deepEqual(r.stdout.trim().split("\n").slice(1), [
    "AGENTS.md: broken link -> ./front/.agents/GUIDES.md",
    "AGENTS.md: unknown task -> task test:coverage",
    "AGENTS.md: unknown task -> task ghost",
    "AGENTS.md: unknown task -> task notatask",
    "AGENTS.md: unknown npm script -> npm run checks",
    "CLAUDE.md: broken import -> @AGENTS-old.md",
  ]);
});
