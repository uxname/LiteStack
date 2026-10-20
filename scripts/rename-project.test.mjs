// Self-test for rename-project.sh: run it on clones of both submodules and check that the
// template Go module path survives nowhere in backend/ except prose (*.md). The script
// picks its files by a list of patterns; a build file outside that list (it was
// backend/Dockerfile once) keeps the old path and nothing fails until the image is built.
// Run: node --test scripts/rename-project.test.mjs
import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";

const meta = join(import.meta.dirname, "..");
const sh = (cmd, args, cwd) => execFileSync(cmd, args, { cwd, encoding: "utf8" });

test("rename leaves the template module path only in prose", { skip: !existsSync(join(meta, "backend/.git")) }, () => {
  const root = mkdtempSync(join(tmpdir(), "rename-"));
  try {
    for (const d of ["backend", "frontend"]) sh("git", ["clone", "-q", join(meta, d), join(root, d)], root);
    mkdirSync(join(root, "scripts"));
    copyFileSync(join(meta, "scripts/rename-project.sh"), join(root, "scripts/rename-project.sh"));
    sh("bash", ["scripts/rename-project.sh", "--name", "acme-app", "--repo-owner", "acme"], root);
    // git grep exits 1 on no match, which is a pass here
    const left = spawnSync("git", ["grep", "-lF", "uxname/liteend-go"], { cwd: join(root, "backend"), encoding: "utf8" }).stdout.split("\n").filter(Boolean).filter((f) => !f.endsWith(".md"));
    assert.deepEqual(left, []);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
