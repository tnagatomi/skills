---
name: chunked-impl
description: Implement a feature or fix incrementally by splitting the work into small chunks and building each chunk test-first with the tdd skill's red-green-refactor loop, then committing once tests are green. Depends on the tdd skill (https://github.com/mattpocock/skills/tree/main/skills/engineering/tdd) for the per-chunk red-green-refactor discipline. Use this skill whenever the user asks to implement, build, or fix something with phrases like "implement X chunk by chunk", "commit as you go", "test and commit each step", "incremental implementation", "split this into small commits", or any time the user wants steady, verifiable progress with a clean git history rather than a single big change. Prefer this skill for non-trivial changes that have (or should have) automated tests.
---

# Chunked Implementation

This skill provides the outer loop — splitting a change into small chunks and landing each as its own commit — and delegates the inner loop of building each chunk to the **tdd skill** (https://github.com/mattpocock/skills/tree/main/skills/engineering/tdd), which drives a red-green-refactor cycle. The tdd skill must be installed and available; invoke it for the implementation of every chunk.

Deliver non-trivial changes as a sequence of small, independently verifiable commits. Each chunk is built test-first via red-green-refactor, ends in a green test run, and is then committed. Nothing is committed until tests are green. The refactor phase of the tdd loop is where the just-written code gets cleaned up before it lands.

This matters because small, tested commits make regressions easy to bisect, make reviews easier, and let the user stop, resume, or roll back at any point without losing context.

## Precondition: the tdd skill must be installed

This skill cannot function without the **tdd skill** — it drives the red-green-refactor loop for every chunk. Before doing anything else, confirm the tdd skill is available (it appears in your list of available skills).

If the tdd skill is **not** available, **stop immediately**. Do not start planning chunks or writing code. Tell the user it's required and how to install it:

> The `chunked-impl` skill depends on the `tdd` skill, which isn't installed. Install it from https://github.com/mattpocock/skills/tree/main/skills/engineering/tdd, then re-run this skill.

Only proceed to step 1 once the tdd skill is confirmed available.

## Workflow

Follow these steps. Treat them as a loop, not a one-shot script.

### 1. Plan the chunks

Before writing any code, sketch the chunks out loud to the user and confirm direction. A chunk is:

- **Small**: ideally 5–50 lines of diff, done in one focused change.
- **Self-contained**: it compiles and its tests pass on its own.
- **Meaningful**: it represents one logical step (e.g., "add schema", "parse input", "wire handler", "add edge-case test").

Frame each chunk as one or a few observable behaviors — this list is what the tdd loop will turn into tracer-bullet tests in step 3, so describe behaviors ("rejects empty tokens"), not implementation steps ("add an if-statement").

Use `TaskCreate` to record the chunk list so both you and the user can see progress.

If the change is trivial (one-line fix, typo), say so and skip this skill — the overhead isn't worth it.

### 2. Verify the starting state is green

Before the first chunk, run the project's test command once to confirm the baseline is clean. If it's already failing, stop and surface that to the user — don't bury pre-existing failures under new commits. If the project has no test runner set up at all, stop and tell the user; offer to set up the test framework as the first chunk rather than proceeding untested (the tdd loop needs a way to run tests).

How to find the test command, in order:

1. Check `CLAUDE.md` / `AGENTS.md` / `README.md` for the canonical command.
2. Inspect `package.json`, `Makefile`, `pyproject.toml`, `go.mod`, `Cargo.toml`, etc.
3. Ask the user if it's ambiguous.

Record the command so every chunk uses the same one.

### 3. Build the chunk with the tdd skill (red-green-refactor)

Invoke the **tdd skill** and apply its red-green-refactor loop to this chunk, using the chunk's behaviors from step 1 as the behavior list:

- **Red**: write one test for the next behavior in the chunk; watch it fail.
- **Green**: write the minimal code to make that test pass.
- Repeat one behavior at a time (vertical slices / tracer bullets) until the chunk's behaviors are covered. Don't write all the chunk's tests up front — that's the horizontal-slice anti-pattern the tdd skill warns against.
- **Refactor**: once the chunk is green, look for refactor candidates — extract duplication, deepen modules, apply SOLID where natural. This is the cleanup pass that lands the chunk in good shape; never refactor while red, and re-run tests after each refactor step.

Stay within the chunk's scope. Resist the urge to "fix one more thing while I'm here" — that's what the next chunk is for. If implementing the chunk balloons well past its planned size, that's a signal the chunk was too big — stop, return to step 1, and re-plan with smaller chunks.

### 4. Confirm the chunk is green

The tdd loop already runs tests as it goes; before committing, confirm the chunk is green as a whole. Prefer scoping to the affected package/file when the suite is slow (e.g., `pytest path/to/test_foo.py`, `go test ./pkg/...`, `npm test -- path/to.test.ts`). Run the full suite at least at the end of the chunk, and any time you touch shared code (type definitions, common utilities, config files, build/CI scripts).

- **Green**: proceed to step 5.
- **Red**: fix the issue in place before committing. Do not commit a red chunk. Do not disable tests to make them pass.

### 5. Commit

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

One chunk = one commit. The tests and refactor from step 3 fold into the same commit — they're part of landing this chunk cleanly, not separate commits.

### 6. Update todos and continue

Mark the chunk done, then return to step 3 for the next chunk. Give the user a one-line status update ("chunk 2/5 green, committed as `abc1234`") so they can follow along without asking.

## Guardrails

- **Never skip hooks** (`--no-verify`) to force a commit through. If a pre-commit hook fails, treat it as a red test.
- **Never amend a previous commit** to fold in a new chunk — create a new commit so the history stays honest.
- **Never refactor while tests are red** — get the chunk to green first, then clean up.
- **Never commit secret-bearing environment files** (`.env`, `.env.*`, local credential files), even when the user asks. Commit only sanitized templates such as `.env.example` after verifying they contain placeholders instead of real secrets.
- **Never commit generated artifacts** unless the user has asked for them (build outputs, large binaries).
- **Never `git add -A` / `git add .`** — stage the chunk's files explicitly so unrelated working-tree changes don't sneak in.
- **If the baseline is red**, don't start. Surface it.
- **If there's no test runner**, tell the user. Offer to set it up as the first chunk rather than proceeding untested.
- **Don't auto-push.** Commits stay local unless the user asks to push.

## When to stop and check in

Pause and ask the user when:

- A chunk's tests keep failing in ways that suggest the plan was wrong.
- You discover the change touches more surface area than the plan anticipated.
- A chunk needs a destructive or hard-to-reverse action (migrations, schema changes, dependency bumps).

A short check-in beats a long detour.
