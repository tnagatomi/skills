---
name: agent-test-with-report
description: Drive the agent-browser CLI to exercise the features a pull request changes, then post an evidence-only findings report back to the PR. Depends on the agent-browser skill (https://github.com/vercel-labs/agent-browser) for the actual browser operation. Use this skill when the user wants an agent to manually test a PR in a real running app and leave a report on the PR, with phrases like "agent-test this PR", "browser-test the PR and comment results", "run exploratory testing and post a report", "check this change in the running app and report on the PR". The report collects evidence (operations, screenshots, findings, unverified scope) for a human reviewer — it never produces a pass/fail verdict.
---

# Agent Test with Report

This skill turns a pull request into a structured, evidence-based manual test run. It reads the PR's diff and description to decide **what** to exercise, delegates the **how** of browser operation to the **agent-browser skill** (https://github.com/vercel-labs/agent-browser), and posts a fixed-format report back to the PR via `gh`.

The report is **evidence, not a verdict**. It records what was done, what was seen, and — crucially — what was *not* covered, so a human reviewer can decide in seconds. Merge decisions stay with humans and CI; this skill never outputs "✅ Approved" or any pass/fail judgement.

## Precondition: the agent-browser skill must be installed

This skill cannot operate the browser on its own — it relies on the **agent-browser skill** for every navigation, click, fill, and screenshot. Before doing anything else, confirm it is available (it appears in your list of available skills, and `agent-browser` resolves as a CLI).

If it is **not** available, **stop immediately**. Do not start reading the PR or driving a browser. Tell the user it is required and how to install it:

> The `agent-test-with-report` skill depends on the `agent-browser` skill, which isn't installed. Install it with `npm i -g agent-browser && agent-browser install` (see https://github.com/vercel-labs/agent-browser), then re-run this skill.

Only proceed once the agent-browser skill is confirmed available.

## Precondition (optional): a GitHub-authenticated browser profile

Inline screenshot attachment (step 8) needs the agent-browser browser signed in to GitHub. agent-browser's default profile is **headless and ephemeral** — a fresh temp `user-data-dir` every run — so it is never logged in, and attachment silently can't happen. To enable it, set up a **persistent profile once** and reuse the same path on every run:

```bash
agent-browser open https://github.com/login --headed --profile ~/.agent-browser/profiles/github
```

`--profile <path>` is any directory you pick; it becomes Chrome's `user-data-dir`, so the GitHub session (cookies, localStorage) persists there across runs. `~/.agent-browser/profiles/github` is a sensible default. Log in **by hand** in the window that opens — credentials and 2FA belong to the user, never to the skill, which must never perform, script, or store the login. The skill only *checks* this state at run time (step 8).

This precondition is **optional**: without it the run still completes and falls back to the text-only post.

## Principles (do not bend these)

- **Evidence, not verdicts.** Report findings; never emit an approval or pass/fail call. The reviewer and CI decide.
- **Capture and attach generously.** Screenshot every meaningful state, not just the end — and attach many of them to the comment, not one summary shot. A reviewer would rather scroll a gallery than trust a sentence. **Anything that diverges from the expected behaviour gets its own screenshot, called out inline next to the finding** — surprises are the highest-value evidence, so never drop them to save space.
- **Always declare the unverified scope.** "Not verified" is a required section. A report that looks complete but hides its gaps is worse than an honest partial one.
- **Suggest missing test coverage; never commit test code.** When a behaviour you exercised isn't guarded by an automated test, say so in the report as a suggestion. Do not add or commit tests in this run — that bloats the diff and shifts the review focus.
- **Leave room for exploration.** After the scripted checks, spend a fixed exploration phase poking at the change freely and report any "this feels off" observations. The skill only sees the points it was told to check; the value of an agent is also catching what wasn't written down.

## Workflow

### 1. Identify the PR and load its context

Resolve the target PR (default: the PR for the current branch). Read its **description** and **diff**:

```bash
gh pr view --json number,title,body,labels,files
gh pr diff
```

From the description, extract any "intent of the change" and "what to verify" notes — the PR author's stated review points are your primary test charter. From the diff, identify which user-facing features/screens the change touches.

### 2. Decide whether to run, and at what depth

Skip the browser run when the change can't be meaningfully exercised in a UI:

- **Mechanical skip by diff path:** docs-only, CI/config-only, or test-code-only changes → skip.
- **Otherwise choose depth, not yes/no:** *smoke* (walk the main path the diff touches) vs *full* (main path + edge cases + exploration). Bias toward smoke for small/low-risk diffs.

**On skip, still post a one-line report** stating the reason (e.g. "Skipped: docs-only change, no UI surface touched"). A silent skip is indistinguishable from a missed run.

### 3. Determine the test target

Default to the **local development environment**. Resolve the base URL in this order:

1. A URL or environment the user explicitly specified for this run.
2. A running local dev server (e.g. `http://localhost:3000`). If the app isn't running, start it per the project's conventions (`CLAUDE.md` / `README.md` / `package.json` scripts), or ask the user how to start it.
3. Any preview/staging URL the user points you at.

Confirm the target is reachable before driving the browser. Note the exact base URL in the report so the run is reproducible.

### 4. Derive the test points

Combine two sources into a short, explicit checklist:

- The PR author's "what to verify" notes from the description.
- The features the diff touches (new/changed flows, forms, states, error paths).

State the checklist before acting so the user can see your charter.

### 5. Drive the browser via the agent-browser skill

Invoke the **agent-browser skill** to execute the checklist against the target. For each point: navigate, perform the user actions, observe the result, and **capture a screenshot as evidence**. Save screenshots to a run directory (e.g. `.agent-test/screenshots/`) and keep their paths — you'll reference them in the report.

Keep the agent-browser skill focused on *how* to operate the browser; this skill owns *what* to check and *how to report it*.

### 6. Exploration phase

After the checklist, spend a bounded exploration pass (a few minutes / a handful of interactions) touching the changed area freely — odd inputs, rapid navigation, empty/long values, back-button, reload. Record anything that feels wrong, even if you can't tell whether it's a real bug. These go in the "Out-of-scope observations" section for human triage.

### 7. Note automated-test gaps

For each behaviour you verified by hand, ask: would an automated test catch a regression here? List the gaps as suggestions in the report. Do **not** write or commit tests now.

### 8. Compose and post the report

Fill the template below, then post it to the PR.

**First, check GitHub auth** (don't wait until posting). Open `https://github.com` in the persistent `--profile` from the optional precondition and check the logged-in signal — the fastest is `agent-browser eval "document.querySelector('meta[name=user-login]')?.content || 'LOGGED_OUT'"`: a username means signed in, `LOGGED_OUT` (or the marketing homepage) means not. Two outcomes:

- **Signed in → post through agent-browser so screenshots render inline.** `gh` can't upload images to a comment, but the authenticated browser can. Use the **posting recipe** below — it avoids hunting for selectors each run. GitHub hosts uploads at `github.com/user-attachments/assets/…`; those URLs inherit the repo's visibility, so they render inline **and** stay private on private repos.
- **Not signed in → don't drive a login** (2FA will block you). Surface this message to the user, then fall back to the text-only post below:

  > To attach screenshots inline I need the agent-browser browser signed in to GitHub, but it isn't. Run this once, log in by hand (your credentials + 2FA), then re-run the skill:
  > ```bash
  > agent-browser open https://github.com/login --headed --profile ~/.agent-browser/profiles/github
  > ```
  > Posting a text-only report for now.

#### Posting recipe (agent-browser → GitHub PR comment)

These are the current selectors for github.com's server-rendered PR conversation box; **if one isn't found, the UI changed — `snapshot -i` the comment area to relocate it** rather than guessing.

| What | Selector |
| --- | --- |
| Comment textarea | `#new_comment_field` |
| Hidden attachment input | `#fc-new_comment_field` |
| Submit | the `button[type=submit]` **inside `#new_comment_field`'s form** whose text is exactly `Comment` |

1. **Open the PR on the GitHub-authenticated profile.** Always pass the profile: `agent-browser open https://github.com/<owner>/<repo>/pull/<n> --headed --profile ~/.agent-browser/profiles/github`. A bare `agent-browser open <url>` (no `--profile`) spins up a **fresh, logged-out** session — you'll see `#new_comment_field` missing and `meta[name=user-login]` empty. ⚠️ If a daemon is already running with other options, `--headed`/`--profile` are **silently ignored** — run `agent-browser close --all` first, then open. **Re-confirm auth after opening the PR** (`meta[name=user-login]` returns your username) before filling.
2. **Fill** the report up to where the first screenshot goes: `agent-browser fill '#new_comment_field' "<markdown>"`.
3. **Upload each screenshot at its caption — one fully-confirmed upload at a time.** Attach as many as you took, not one. For every shot, in order: focus the textarea and put the caret at the end (`setSelectionRange(value.length, value.length)`), type its caption line (`agent-browser keyboard inserttext "**<caption>**\n"`), then `agent-browser upload '#fc-new_comment_field' <shot.png>`. GitHub inserts an `<img src="https://github.com/user-attachments/assets/…">` at the caret. **Never fire the next upload until the current one is confirmed** — GitHub's file input drops a second upload that arrives while the first is still in flight, so overlapping uploads silently lose images. Poll until the textarea's `user-attachments` **count has incremented by exactly one** (give it a generous window, ~20s; a `![Uploading…]()` placeholder means still in flight). **If the count doesn't advance, the upload was dropped — re-upload that same file** before moving on. After the loop, assert the final count equals the number of screenshots; if short, re-upload the missing one(s) at the end.
4. **Append the rest** of the report (Findings onward), caret at end, via `agent-browser keyboard inserttext "<rest>"`. **Interleave divergence shots inline:** when a finding describes behaviour that differed from the expectation, attach its screenshot right there (same caption→upload→wait loop), not only in the top gallery.
5. **Submit by the form-scoped `Comment` button.** Don't use a bare `find role button "Comment"` — the PR page has other elements named "Comment" (review widgets, the diff viewer) and you'll grab the wrong, often-covered one. Scope to the comment form and pick the submit button by exact text, then click it:
   ```bash
   agent-browser eval "var f=document.querySelector('#new_comment_field').closest('form');var b=[...f.querySelectorAll('button[type=submit]')].find(x=>x.textContent.trim()==='Comment');b.id='ab-submit';'tagged'"
   agent-browser scrollintoview '#ab-submit' && agent-browser click '#ab-submit'
   ```
   ⚠️ **Never click the form's _first_ `button[type=submit]` by position — it is `Close with comment`, which _closes the PR_.** Pick by text, not order. If you ever trip this, recover immediately: `gh pr reopen <n>`.
6. **Verify it landed** (don't scrape the DOM): `gh pr view <n> --json state,comments --jq '{state, last: .comments[-1] | {author:.author.login, hasImg:(.body|test("user-attachments"))}}'`. Confirm `state == OPEN` and `hasImg == true`.

**Fallback — text-only via the bundled helper.** When there are no screenshots (e.g. a skip report), or the browser isn't signed in to GitHub, post the markdown with:

```bash
scripts/post-report.sh <report.md> [pr]
```

`[pr]` defaults to the current branch's PR; the script posts the file via `gh pr comment`. Images can't be embedded this way — reference the saved screenshot paths in the report, and state explicitly in the report's Evidence/Not-verified sections that screenshots were **not** attached inline and why (so a silent text-only post isn't mistaken for "no screenshots were taken").

## Report template (posted to the PR)

Write the report — and any message you surface to the user (e.g. the not-signed-in prompt in step 8) — in the **agent's configured output language**. Don't hard-code a language; follow whatever the running agent is set to (its language setting / the project's convention). The section labels below are examples in English: render them, and all prose, in that language. The structure, the required "Not verified" section, and the no-verdict rule stay the same regardless of language.

```md
## 🤖 Agent test report

**Target:** <base URL the run hit> · **Depth:** smoke | full · **Commit:** <sha>

### Summary of change
<1–3 lines: what this PR does, from the description + diff>

### Test points
<the checklist from step 4 — what you set out to verify>

### Operations performed
<ordered list of the user actions you took>

### Evidence (screenshots)
<A gallery — attach a shot for each meaningful state, not one summary. Caption each.>
**<caption 1>**
<image 1>
**<caption 2>**
<image 2>
<…as many as you took…>

### Findings
<observations from the scripted checks. Neutral, specific. No verdict. Where a
result diverged from the test point, say so AND attach its screenshot right here
(not only in the gallery) — surprises are the highest-value evidence.>

### Out-of-scope observations
<exploration-phase "this feels off" notes for human triage, each with its own screenshot where you can. "None" if nothing.>

### Missing automated-test coverage (suggestions)
<behaviours exercised by hand that no automated test seems to guard. Suggestions only.>

### Not verified
<REQUIRED. What you could not or did not check, and why: blocked flows,
auth you lacked, data you couldn't set up, areas left for the human.>

---
*Evidence for review — not a pass/fail verdict. Merge decision stays with the reviewer and CI.*
```

## Guardrails

- **Never emit a verdict.** No "Approved", no ✅/❌ pass-fail. Findings only.
- **Never leave "Not verified" empty.** If you genuinely covered everything, say so explicitly and why you're confident — but that is rare.
- **Never commit test code or other changes** as part of this run. Suggestions go in the report, not the diff.
- **Never expose secrets** in the report — redact tokens, credentials, and private data captured in screenshots or logs.
- **Don't fabricate evidence.** Only reference screenshots that exist; only claim operations you actually performed.
- **Don't run against production** or any environment where your actions cause real side effects (payments, emails, deletions) unless the user explicitly confirms it's safe.

## When to stop and check in

Pause and ask the user when:

- You can't resolve or reach a test target (no running app, unknown start command).
- The change requires data, auth, or a flow you can't set up yourself.
- An action would be destructive or irreversible (payments, account deletion, outbound messages).
- The diff's intent is unclear and the PR description gives no review points — guessing the charter wastes the run.
