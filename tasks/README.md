# tasks/

Full-stack task specs for work that spans `liteend` and/or `litefront`.

## How to use

1. Copy [`TEMPLATE.md`](./TEMPLATE.md) to a new file, e.g. `tasks/0001-add-user-avatar.md`.
2. Fill in the goal, affected projects, and the checklist.
3. Work through the checklist; check items off as you go.
4. Remember the git topology (see root `AGENTS.md`): commit code **inside** each submodule,
   then commit the updated pointers in the meta-repo.

Keep one file per task. Use a numeric prefix for ordering. Move finished tasks to a
`tasks/done/` subfolder if the list grows, or just leave them checked off.
