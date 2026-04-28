---
name: chunked-impl
description: Implement a feature or fix incrementally by splitting the work into small chunks, running tests after each chunk, refactoring the just-written code with the /simplify skill once tests pass, and committing. Use this skill whenever the user asks to implement, build, or fix something with phrases like "implement X chunk by chunk", "commit as you go", "test and commit each step", "incremental implementation", "split this into small commits", or any time the user wants steady, verifiable progress with a clean git history rather than a single big change. Prefer this skill for non-trivial changes that have (or should have) automated tests.
---

# Chunked Implementation

Deliver non-trivial changes as a sequence of small, independently verifiable commits. Each chunk ends in a green test run, a `/simplify` pass to clean up what was just written, another green test run, and a commit. Nothing is committed until tests are green.

This matters because small, tested commits make regressions easy to bisect, make reviews easier, and let the user stop, resume, or roll back at any point without losing context.

## Workflow

Follow these steps. Treat them as a loop, not a one-shot script.

### 1. Plan the chunks

Before writing any code, sketch the chunks out loud to the user and confirm direction. A chunk is:

- **Small**: ideally 5–50 lines of diff, done in one focused change.
- **Self-contained**: it compiles and its tests pass on its own.
- **Meaningful**: it represents one logical step (e.g., "add schema", "parse input", "wire handler", "add edge-case test").

Use `TaskCreate` / `TodoWrite` to record the chunk list so both you and the user can see progress.

If the change is trivial (one-line fix, typo), say so and skip this skill — the overhead isn't worth it.

### 2. Verify the starting state is green

Before the first chunk, run the project's test command once to confirm the baseline is clean. If it's already failing, stop and surface that to the user — don't bury pre-existing failures under new commits.

How to find the test command, in order:

1. Check `CLAUDE.md` / `AGENTS.md` / `README.md` for the canonical command.
2. Inspect `package.json`, `Makefile`, `pyproject.toml`, `go.mod`, `Cargo.toml`, etc.
3. Ask the user if it's ambiguous.

Record the command so every chunk uses the same one.

### 3. Implement one chunk

Edit only what that chunk needs. Resist the urge to "fix one more thing while I'm here" — that's what the next chunk is for. Writing the test alongside or just before the implementation is encouraged when it's natural, but strict test-first is not required.

### 4. Run tests for the chunk

Run the test command. Prefer scoping to the affected package/file when the suite is slow (e.g., `pytest path/to/test_foo.py`, `go test ./pkg/...`, `npm test -- path/to.test.ts`). Run the full suite at least at the end, and any time you touch shared code.

- **Green**: proceed to step 5.
- **Red**: fix the issue in place. Do not commit a red chunk. Do not disable tests to make them pass. If the fix balloons, that's a signal the chunk was too big — split it.

### 5. Refactor with `/simplify`

Once the chunk is green, **always** invoke the `/simplify` skill on this chunk's diff. Whether the code needs simplifying is `/simplify`'s call, not yours — never pre-judge the chunk as "trivial" or "fine as-is" and skip the invocation. Even a one-line config bump gets `/simplify` run on it; a fast "nothing to change" response is the confirmation, and that's the point.

Apply any fixes it surfaces, then re-run the test command from step 4. If its edits broke anything, fix them before committing.

### 6. Commit

Stage only the files belonging to this chunk (`git add <specific files>`, not `git add -A`) and commit with a [Conventional Commits v1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) message. Use scopeless form (`type: description`) — the Conventional Commits scope is optional, and this project prefers to omit it. The subject line should be short and describe what changed; include a body with the **why** whenever the reason isn't obvious from the diff (non-trivial trade-offs, context the reader won't have, why this approach over alternatives). Skip the body only when the change genuinely speaks for itself.

```
feat: add tokenizer for quoted strings
fix: reject empty bearer tokens
test: cover discount edge cases
refactor: extract connection pool
```

Example with a body (why is non-obvious):

```
fix: reject empty bearer tokens

Previously an empty Authorization header passed validation and fell
through to the DB lookup, which returned the first row. Explicit
rejection avoids the lookup and closes the auth-bypass path.
```

One chunk = one commit (the refactor from step 5 is folded into the same commit, not a separate one, since it's part of landing this chunk cleanly). Never amend a previous commit to fold in a new chunk — create a new commit so the history stays honest.

### 7. Update the todo list and loop

Mark the chunk done, then return to step 3 for the next chunk. Give the user a one-line status update ("chunk 2/5 green, committed as `abc1234`") so they can follow along without asking.

## Guardrails

- **Never skip hooks** (`--no-verify`) to force a commit through. If a pre-commit hook fails, treat it as a red test.
- **Never commit generated artifacts** unless the user has asked for them (build outputs, `.env`, large binaries).
- **Never `git add -A` / `git add .`** — stage the chunk's files explicitly so unrelated working-tree changes don't sneak in.
- **If the baseline is red**, don't start. Surface it.
- **If tests don't exist**, tell the user. Offer to add them as the first chunk rather than proceeding untested.
- **Don't auto-push.** Commits stay local unless the user asks to push.

## When to stop and check in

Pause and ask the user when:

- A chunk's tests keep failing in ways that suggest the plan was wrong.
- You discover the change touches more surface area than the plan anticipated.
- A chunk needs a destructive or hard-to-reverse action (migrations, schema changes, dependency bumps).

A short check-in beats a long detour.
