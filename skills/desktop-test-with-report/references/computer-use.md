# Driving a desktop app with computer-use (portable notes)

Provider-neutral guidance for operating a native desktop app through a
**computer-use** capability (desktop screenshot + mouse + keyboard) and getting
**file-backed** evidence out of it. Written for any agent/host — where it says
"the host app", read "whatever process runs your shell/tools".

## The toolset (names vary by host)

- `screenshot` — capture the screen the capability sees; returns an image to the
  agent. Coordinates in later click/type calls are read from the **latest**
  screenshot.
- `left_click` / `double_click` / `right_click` / `type` / `key` / `scroll` /
  `left_click_drag` — interact at coordinates / send keystrokes.
- `open_application` — bring an app to the front (launch if needed).
- `request_access` — grant the session control of specific apps (call first).
- A batch form (e.g. `computer_batch`) — run a predictable sequence in one call;
  it re-checks the frontmost app before **each** action.

## Access and tiers

Call `request_access` for each target app before acting. Apps are granted at a
tier:

- **Native apps → full** (click + type + everything).
- **Terminals / IDEs → click only** (no typing) — use your shell tool for input.
- **Browsers → read only** (no click/type) — drive web apps with a real
  browser-automation tool instead, not computer-use.

`open_application` works at any tier (bringing an app forward is read-level).

## The driving loop

```
screenshot            # see current state
click / type / key    # act on coordinates from THAT screenshot
screenshot            # re-observe — never assume the result
```

Re-screenshot after **every** state change; old coordinates go stale the moment
anything moves, re-renders, or a menu opens. Batch only truly predictable runs.

## Focus and occlusion — the two big pitfalls

1. **Focus bounces.** Notifications, terminals, and the agent's own window steal
   the frontmost slot. computer-use actions **fail when a non-granted app is
   frontmost** ("X is not in the allowed applications and is currently in
   front"). Mitigation: call `open_application <target>` immediately before a
   click, and prefer the batch form (it re-checks frontmost per action). After
   any failure, re-screenshot — the foreground may have changed.

2. **The target window can be occluded** by other real windows (including the
   agent's own UI). The computer-use `screenshot` hides non-granted apps at the
   compositor level, so it looks clean — but a real OS-level screen capture (see
   below) does **not** filter, so occluding windows show up there.

## Getting a file-backed screenshot (the crux for posting evidence)

To attach a screenshot to a PR/issue you need an actual **file** on disk that
your upload tool can read. Two facts make this non-obvious:

- The computer-use `screenshot` (even a "save to disk" variant) typically
  delivers the image to the **chat/UI**, not to a file path your shell or a
  separate upload tool can open. Don't rely on it for the upload path.
- A native OS capture gives you a real file. On **macOS** that is
  `screencapture`:

  ```bash
  screencapture -x out.png                 # main display, no sound
  screencapture -x d1.png d2.png d3.png    # one file PER display
  ```

  - **Requires Screen Recording permission** for the host app running your
    shell. Without it `screencapture` fails with *"could not create image from
    display"*. This is a one-time OS grant (System Settings → Privacy &
    Security → Screen Recording); it may require relaunching the host app to
    take effect. If there are two similarly-named host entries, grant the exact
    one that owns your shell process (check the process ancestry).
  - **No compositor filtering** — it captures the real screen, so any other
    window on that display (terminals, the agent's own window, unrelated apps)
    appears. Make sure only the target is visible, or crop (below).
  - **Multi-display:** the target app may be on a non-main display. Capture all
    displays and pick the right file by resolution.

### When the target window is occluded

Bringing a native window reliably **above** every other window is the hard part:

- `open_application` / `open -b <bundleid>` raise it in the compositor view but
  not always above every real window.
- Scripting the window (raise / read bounds / resize) via the OS automation
  bridge (e.g. macOS System Events) needs **Accessibility permission**, which
  may not be granted.
- Capturing a single window by its window id (e.g. macOS `screencapture -l<id>`)
  needs the id, which requires a window-list API (CGWindowList via pyobjc/JXA) —
  often unavailable.

Pragmatic fallbacks, in order:

1. **Maximize / arrange** so the target fills its display (cover the rest).
2. **Ask the human** to move the obstructing window — cheap and reliable.
3. **Crop** the display capture to the target region with an image tool, e.g.
   ImageMagick: `magick in.png -crop WxH+X+Y +repage out.png`.

## Permissions summary (macOS)

| Need | Permission | Symptom when missing |
| --- | --- | --- |
| Drive apps (click/type) | per-app grant via `request_access` | action blocked / app not allowed |
| File-backed capture (`screencapture`) | **Screen Recording** (host app) | "could not create image from display" |
| Script/raise/resize windows | **Accessibility** (host app) | "not allowed assistive access" (-1719) |

## Safety

- **Never enter credentials** (tokens, passwords, card numbers) — if the app
  gates on auth, stop and have the human do it, then continue.
- **Destructive/irreversible native actions** (delete, send, pay) need explicit
  confirmation — desktop apps touch the real machine.
- A real OS capture can include **whatever is on screen** — verify a shot has no
  private content before sharing it.
