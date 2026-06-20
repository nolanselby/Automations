# Automations — Design

**Date:** 2026-06-20
**Status:** v1 (the shell)

## Summary

A native macOS (SwiftUI) utility platform styled after Raycast's command
palette. The app presents a searchable list of "automations" (shell commands);
selecting one runs it and shows the output. v1 ships the shell with one real
command wired up end-to-end (`whoami`). Adding more automations later means
appending entries to a single array.

Design language comes from the Raycast `DESIGN.md` in
[awesome-design-md](https://github.com/nolanselby/awesome-design-md).

## Goals

- Native, good-looking, "neat" utility shell — Raycast aesthetic.
- One command runs end-to-end with visible output + exit status.
- Architecture where adding a new automation is a one-line catalog entry.
- Buildable and runnable from the CLI (so it can be verified without opening Xcode).

## Non-goals (v1)

- Editing/creating commands in the UI
- Persistence / favorites / history
- Global hotkey / menu-bar presence
- Rich result types (only text output for now)

## Architecture

Four small, single-purpose units:

| Unit | Responsibility | Depends on |
|------|----------------|------------|
| `Automation` (model) | Describes one automation: id, title, subtitle, SF Symbol, accent, shell command. Holds the static `catalog`. | nothing |
| `CommandRunner` (service) | Runs a command via `Process` + `/bin/zsh -lc`; captures stdout/stderr + exit code asynchronously. The only code that touches the shell. | Foundation |
| `PaletteView` | Raycast-style palette: search field, filtered rows, keyboard nav (↑/↓/⏎). | model, theme |
| `OutputView` | Shows running/finished result: monospaced output, exit-code status, back action. | runner, theme |

`AutomationsApp` (the `@main` App) owns a small root view that switches between
`PaletteView` and `OutputView`. `Theme` centralizes the Raycast tokens
(colors, radii, spacing, type).

## Data flow

1. `PaletteView` filters `Automation.catalog` by the search text.
2. On ⏎ / click, the root view transitions to `OutputView` for that automation.
3. `OutputView` asks `CommandRunner` to run the command, observes state
   (`running` → `finished(output, exitCode)` / `failed`), and renders it.
4. Back action returns to the palette.

## Theme tokens (from Raycast DESIGN.md)

- Canvas `#07080a`; surface ladder `#0d0d0d` / `#101111` / `#121212`.
- Hairline borders `#242728`; soft white hairlines for elevation.
- Text: ink `#f4f4f6`, body `#cdcdcd`, mute `#9c9c9d`, ash `#6a6b6c`.
- Accents (reserved for automation icons): blue `#57c1ff`, red `#ff6161`,
  green `#59d499`, yellow `#ffc533`.
- Hero stripe gradient `#ff5757 → #a1131a` (three diagonal red stripes at top).
- Radii 6–10px; white CTA pill; Inter typography (ss03), falling back to the
  system font when Inter is not installed.

## Build & run

- SwiftPM executable target. `swift run` launches the GUI for dev.
- `Scripts/make-app.sh` bundles a distributable `Automations.app`.

## Extending later

A new automation is one entry in `Automation.catalog`. The "later misc tasks"
(folder openers, project launchers, scripts) all fit this shape. Larger
features (in-UI editing, persistence, global hotkey) build on the same model.
