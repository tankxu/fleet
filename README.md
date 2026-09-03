<p align="center">
  <img src="docs/assets/fleet-icon.png" alt="Fleet app icon" width="128" />
</p>

<h1 align="center">Fleet</h1>
<p align="center">A native macOS terminal where every workspace is a live card on one board</p>

<p align="center">
  English | <a href="README.zh-CN.md">简体中文</a>
</p>

<p align="center">
  <a href="https://github.com/tankxu/fleet/releases/latest"><img src="https://img.shields.io/github/v/release/tankxu/fleet?label=download&color=2ea043" alt="Download" /></a>
  <a href="#license"><img src="https://img.shields.io/badge/license-GPL--3.0--or--later-555" alt="GPL-3.0-or-later" /></a>
  <img src="https://img.shields.io/badge/platform-macOS-555" alt="macOS" />
</p>

<p align="center">
  <img src="docs/assets/fleet-canvas.png" alt="Four coding agents running side by side as live cards on the Fleet canvas" width="100%" />
</p>

## What this is

Fleet is a fork of [cmux](https://github.com/manaflow-ai/cmux) — a native macOS
terminal, Swift and AppKit rather than Electron, built for running coding agents,
with [Ghostty](https://ghostty.org) as its terminal core.

Fleet keeps all of that and adds a **canvas**: instead of one workspace filling
the window while the rest wait in a sidebar, every workspace becomes a live card
on a single board. It installs alongside cmux rather than replacing it.

### What it inherits from cmux

Work is organised into *workspaces* — a directory plus the terminals open on it —
and the app is built around the fact that the one doing the typing is an agent:

- **Notification rings.** Panes get a ring and tabs light up when an agent needs
  you. A notification panel collects every pending one and jumps to the most
  recent unread.
- **Vertical tabs that carry context.** The sidebar shows the git branch, linked
  PR status and number, working directory, listening ports, and the latest
  notification text. Split horizontally and vertically.
- **A scriptable in-app browser.** Split a browser beside the terminal and drive
  it from a script, through an API ported from
  [agent-browser](https://github.com/vercel-labs/agent-browser). Import cookies,
  history, and sessions from Chrome, Firefox, Arc, and 20+ others so browser
  panes start authenticated.
- **SSH workspaces.** `fleet ssh user@remote` opens a workspace on a remote
  machine. Browser panes route through that machine's network, so localhost just
  works, and dragging an image into a remote session uploads it over scp.
- **Claude Code Teams.** `fleet claude-teams` runs Claude Code's teammate mode in
  one command. Teammates spawn as native splits with their own sidebar metadata
  and notifications — no tmux.
- **Programmable.** A CLI and socket API to create workspaces, split panes, send
  keystrokes, and automate the browser, plus per-project custom commands defined
  in `cmux.json` and launched from the command palette.
- **Session restore.** Reopen the app and the workspaces come back.

## The canvas

<p align="center">
  <img src="docs/assets/fleet-canvas-browser.png" alt="Canvas cards holding terminals, agent sessions, and the in-app browser at once" width="100%" />
</p>

Every workspace in a window is a card, and every card is a real terminal — not a
preview or a thumbnail. Cards run whatever a workspace holds: a shell, a Claude
Code or Codex session, split panes, the in-app browser. The point is to run
several agents at once and see all of them without cycling tabs.

- **Cards group, they don't just split.** The layout is an n-ary tree: one
  container holds any number of members, so three workspaces sit at equal width
  instead of collapsing into nested halves. Dragging one card next to another does
  not force a 1/2 split.
- **Drop targets read intent from position.** Dragging into a card's interior
  groups with it; dropping in the gap between cards, or at either end of a row,
  inserts as a sibling. Shift-click selects several cards at once, and the context
  menu's *Group workspace* / *Exit group* do the same thing as a drag, for when a
  drag is awkward.
- **Cards hold still.** They resize by proportion, remember that proportion, and
  never reposition themselves because a session got busy. A board you arranged
  stays arranged.
- **Titles say something useful.** One terminal shows its path. A running agent
  shows the agent and the session title, with that agent's icon. Several terminals
  in one card show the shared path.
- **Rename in place, close from the card.** Click a card's title to edit it
  inline, or use *Rename Workspace…* in its context menu; the name you set is
  never overwritten by the automatic one. *Close Workspace* sits in the same menu.
  The menu lives on the card header only — a card's body is a terminal, and
  right-clicking a terminal belongs to the terminal.

## Smaller additions

- **A yellow pulse when a session finishes.** The moment an agent stops and wants
  you, its workspace pulses yellow. Upstream showed a steady ring, which is easy
  to miss on a board of a dozen cards; a pulse is not. It respects Reduce Motion.
- **Claude and Codex are one click away.** Each pane's tab bar carries Claude and
  Codex buttons that start the agent in that pane's own working directory — no
  `cd`, no typing the command. An idle prompt takes the command directly; a busy
  one gets a new pane beside it, so a click can never interrupt a running session.
  New terminal, new browser, and the two split directions sit in the same row, and
  the whole row is configurable in `cmux.json`.
- **One accent color.** The theme accent (green) replaces scattered
  `Color.accentColor` use throughout the app, including the tab-bar chrome, which
  previously followed the macOS system accent rather than the app's own theme.
- **Only one blinking cursor.** Ghostty surfaces now adopt the focus intent they
  were created with, so panes that never held first responder no longer sit there
  blinking a solid cursor at you.

## Its own identity

Fleet's Release build is `com.tankxu.fleet`, so it installs next to cmux rather
than replacing it. State is keyed to that identity —
`~/.config/fleet/fleet.json` and `~/Library/Application Support/fleet/` —
because two apps sharing one session snapshot file overwrite each other's
workspaces. An existing cmux install is left completely alone.

The directory name is derived from the running bundle id rather than compiled
in, so Debug and nightly builds keep reading the `cmux` state they already have.

Per-repo `.cmux/` config directories are deliberately unchanged: they are an
in-repo convention shared with cmux, and renaming them would break configs cmux
still has to read.

## Download

Grab the latest build from [**Releases**](https://github.com/tankxu/fleet/releases/latest),
unzip it, and drag `Fleet.app` into `/Applications`.

The build is ad-hoc signed, not notarised, so macOS quarantines it on first
launch. Clear the quarantine flag once:

```bash
xattr -dr com.apple.quarantine /Applications/Fleet.app
```

Then open it normally. Universal binary, Apple silicon and Intel.

Fleet carries its own version line, independent of upstream: this is Fleet
0.1.1, built from cmux 0.64.22. Each release states the upstream version it was
built from.

To get the `fleet` command in your `PATH` as well, link it after installing:

```bash
ln -sf /Applications/Fleet.app/Contents/Resources/bin/fleet ~/bin/fleet
```

## Building from source

```bash
./scripts/setup.sh          # submodules + GhosttyKit
./scripts/install-fleet.sh  # builds Release, installs /Applications/Fleet.app
```

This also installs a `fleet` command into `~/bin`. Inside a Fleet or cmux
terminal it drives the app that owns that terminal; elsewhere it drives Fleet.
An existing `cmux` command is left untouched.

The build is signed locally, like the Debug builds this project has always used.
Set `FLEET_DEVELOPMENT_TEAM=<team-id>` to sign with a real certificate instead —
be aware that path registers `com.tankxu.fleet` as an App ID in that team.

## Known limitations

- **Sign-in does not work yet.** Fleet registers `fleet://` as its callback
  scheme, because two installed apps claiming `cmux://` means macOS can hand the
  callback to the wrong one. The server's scheme allowlist needs `fleet`
  deployed before sign-in completes; `CMUX_AUTH_CALLBACK_SCHEME=cmux` is a
  workaround. Local terminal use — terminals, workspaces, splits, the canvas —
  needs no account at all. Sign-in only gates phone pairing, cloud workspaces,
  and sync.
- **Released builds are not notarised.** There is no Developer ID certificate
  behind this fork, hence the `xattr` step above. There is also no auto-update.
- **The iOS app is still cmux.** Renaming it needs an Apple Developer App ID, an
  APNs key, and a backend push-routing change.
- **Internal identifiers still say `com.cmuxterm`** in logger subsystems,
  dispatch queue labels, and notification names. They are not user-facing, and
  rewriting 225 of them is churn with a real chance of typos.

## Everything else

Everything listed above is inherited unchanged, and upstream is the accurate
reference for all of it:

- [cmux README](https://github.com/manaflow-ai/cmux/blob/main/README.md) — features and keyboard shortcuts
- [cmux docs](https://cmux.com/docs/getting-started) — configuration

Where this fork and those docs disagree about names or colors, this fork is the
one that changed.

Fleet is a personal fork, not affiliated with or endorsed by Manaflow, Inc. If
you want the maintained, signed, notarised build with an official download,
get [cmux](https://github.com/manaflow-ai/cmux).

## License

GPL-3.0-or-later, the same as upstream. Copyright (c) 2024-present Manaflow, Inc.;
other contributors and third parties retain copyright in their material. Fork
changes are offered under the same license. See [LICENSE](LICENSE) and
[THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md).
