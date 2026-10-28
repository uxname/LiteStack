// Self-test for check-coverage.mjs: a project whose requirements are all tagged, then
// the same project with one untagged requirement, an untagged note and an SQL tag.
// Needs `docc` on PATH. Run: node --test scripts/check-coverage.test.mjs
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";

const checker = join(import.meta.dirname, "check-coverage.mjs");

const run = (files) => {
  const root = mkdtempSync(join(tmpdir(), "coverage-"));
  try {
    const all = {
      "docc.json": JSON.stringify({ src: "docs/src", out: "docs/out", commitOut: false, trace: { scan: ["app/**"] } }),
      "docs/schemas/page.json": JSON.stringify({ type: "object", additionalProperties: true }),
      "docs/schemas/req.json": JSON.stringify({ type: "object", "x-docc-covered": true, additionalProperties: true }),
      "docs/src/index.json": JSON.stringify({ title: "Index", kind: "page", body: ["A note nobody tags. ^n2te"] }),
      "docs/src/rules.json": JSON.stringify({
        title: "Rules",
        kind: "req",
        parent: "index",
        body: ["Lock after 5 minutes. ^kf2m", "Trash keeps 30 days. ^tr4s"],
      }),
      ...files,
    };
    for (const [path, body] of Object.entries(all)) {
      mkdirSync(dirname(join(root, path)), { recursive: true });
      writeFileSync(join(root, path), body);
    }
    return spawnSync(process.execPath, [checker, root], { encoding: "utf8" });
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
};

test("every requirement tagged somewhere passes; the untagged note does not count", () => {
  const r = run({
    "app/lock.go": "// docc:begin rules#^kf2m@aaaa ~bbbb\nconst lock = 5\n// docc:end\n",
    "app/node_modules/x.js": "// docc: rules#^tr4s\n",
    "app/trash.sql": "-- docc: rules#^tr4s@cccc ~dddd\nCREATE TABLE trash (id int);\n",
  });
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.match(r.stdout, /checked 2 requirements/);
});

test("an untagged requirement is reported, a tag under node_modules does not cover it", () => {
  const r = run({
    "app/lock.go": "// docc:begin rules#^kf2m@aaaa ~bbbb\nconst lock = 5\n// docc:end\n",
    "app/node_modules/x.js": "// docc: rules#^tr4s\n",
  });
  assert.equal(r.status, 1);
  assert.match(r.stdout, /rules#\^tr4s: no docc tag/);
  assert.doesNotMatch(r.stdout, /kf2m|n2te/);
});
