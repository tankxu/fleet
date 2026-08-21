<h1 align="center">Fleet</h1>
<p align="center">A native macOS terminal where every workspace is a live card on one board</p>

<p align="center">
  English | <a href="README.zh-CN.md">简体中文</a>
</p>

<p align="center">
  <a href="#license"><img src="https://img.shields.io/badge/license-GPL--3.0--or--later-555" alt="GPL-3.0-or-later" /></a>
  <img src="https://img.shields.io/badge/platform-macOS-555" alt="macOS" />
</p>

> **Fleet is a personal fork of [cmux](https://github.com/manaflow-ai/cmux)** by Manaflow, Inc.
> Nearly everything here — the Ghostty-backed terminal, vertical tabs, the agent
> notification system, the scriptable browser, the CLI — is upstream work. Fleet
> renames the app, adds the fleet canvas, and gives the build its own identity so it
> can be installed alongside cmux. It is not affiliated with or endorsed by Manaflow.
>
> If you want the real thing, maintained, signed, and with a download link, get
> [cmux](https://github.com/manaflow-ai/cmux).

## What Fleet adds

### Fleet canvas

A board view where every workspace in a window is a live card — real terminals,
not previews. Built for running several coding agents at once and seeing all of
them at a glance.

- **Cards group, they don't just split.** The layout is an n-ary tree: a container
  holds any number of members, so three workspaces sit at equal width instead of
  collapsing into nested halves. Dragging one card next to another does not force
  a 1/2 split.
- **Drop targets read intent from position.** Dragging into a card's interior
  groups with it; dropping in the gap between cards, or at either end of a row,
  inserts as a sibling. Shift-click selects several cards, and the context menu's
  *Group workspace* / *Exit group* do the same thing as dragging for when a drag
  is awkward.
- **Cards hold still.** They resize by proportion, remember it, and never
  reposition themselves because a session got busy.
- **Titles say something useful.** One terminal shows its path; a running agent
  shows the agent and session title with that agent's icon; several terminals
  show the shared path. Rename a card and it stops being overwritten.
- **Quick launch.** Claude and Codex buttons in each card's action row start in
  the workspace's own directory — reusing the current terminal when it's idle,
  splitting a new pane when it's busy.

### Elsewhere

- **One accent color.** The theme accent (green) replaces scattered
  `Color.accentColor` use, including the tab-bar chrome, which previously followed
  the macOS system accent rather than the app's own theme.
- **A pulsing yellow attention ring** on workspaces waiting for you, instead of a
  steady ring that was easy to miss. Respects Reduce Motion.
- **Only one blinking cursor.** Ghostty surfaces adopt the focus intent they were
  created with, so panes that never held first responder used to keep blinking a
  solid cursor. They no longer do.

### Its own identity

Fleet's Release build is `com.tankxu.fleet`, so it installs next to cmux rather
than replacing it. State is keyed to that identity — `~/.config/fleet/fleet.json`
and `~/Library/Application Support/fleet/` — because two apps sharing one session
snapshot file overwrite each other's workspaces. An existing cmux install is left
completely alone.

The directory name is derived from the running bundle id rather than compiled in,
so Debug and nightly builds keep reading the `cmux` state they already have.

Per-repo `.cmux/` config directories are deliberately unchanged: they are an
in-repo convention shared with cmux, and renaming them would break configs cmux
still has to read.

## Install

There is no DMG, no Homebrew cask, and no auto-update — build it yourself:

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

These are real and unfixed, not roadmap items:

- **Sign-in does not work yet.** Fleet registers `fleet://` as its callback
  scheme, because two installed apps claiming `cmux://` means macOS can hand the
  callback to the wrong one. The server's scheme allowlist needs `fleet` deployed
  before sign-in completes. `CMUX_AUTH_CALLBACK_SCHEME=cmux` is a workaround.
  Local terminal use — terminals, workspaces, splits, the canvas — needs no
  account at all; sign-in only gates phone pairing, cloud workspaces, and sync.
- **The iOS app is still cmux.** Renaming it needs an Apple Developer App ID, an
  APNs key, and a backend push-routing change.
- **Internal identifiers still say `com.cmuxterm`** in logger subsystems, dispatch
  queue labels, and notification names. They aren't user-facing, and rewriting 225
  of them is churn with a real chance of typos.
- **No screenshots in this README.** The upstream ones show cmux's UI, which no
  longer matches.

## Everything else

Fleet inherits the rest of cmux unchanged — vertical tabs, agent notification
rings, session restore, the scriptable in-app browser, the socket API, split
panes, keyboard shortcuts. Upstream is the accurate reference for all of it:

- [cmux README](https://github.com/manaflow-ai/cmux/blob/main/README.md) — features and keyboard shortcuts
- [cmux docs](https://cmux.com/docs/getting-started) — configuration

Where this fork and those docs disagree about names or colors, this fork is the
one that changed.

## License

GPL-3.0-or-later, the same as upstream. Copyright (c) 2024-present Manaflow, Inc.;
other contributors and third parties retain copyright in their material. Fork
changes are offered under the same license. See [LICENSE](LICENSE) and
[THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md).
