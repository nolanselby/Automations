# Automations

A native macOS utility platform — a Raycast-styled command palette for running
shell commands and seeing their output. This is the **shell**: a searchable
catalog of automations where selecting one runs it end-to-end.

The look is derived from the Raycast design system in
[awesome-design-md](https://github.com/nolanselby/awesome-design-md).

## Run

```bash
swift run                 # launches the app for development
```

## Build a distributable .app

```bash
Scripts/make-app.sh       # produces ./Automations.app
open Automations.app
```

## Project layout

```
Sources/Automations/
  AutomationsApp.swift     # @main App + root view + app activation
  Theme/Theme.swift        # Raycast design tokens (colors, type, radii, spacing)
  Models/Automation.swift  # the Automation model + the catalog array
  Services/CommandRunner.swift  # runs commands via /bin/zsh -lc
  Views/
    PaletteView.swift      # command palette: search + keyboard nav
    OutputView.swift       # runs one automation, shows output + exit status
    Components.swift       # icon tile, hero stripe, keycap
Scripts/make-app.sh        # bundles the executable into Automations.app
docs/superpowers/specs/    # design doc
```

## Adding an automation

Append one entry to `Automation.catalog` in
[`Models/Automation.swift`](Sources/Automations/Models/Automation.swift):

```swift
Automation(
    title: "Open Projects",
    subtitle: "Open the coding-projects folder in Finder",
    symbol: "folder",
    accent: Theme.accentBlue,
    command: "open ~/Desktop/coding-projects"
)
```

## Controls

- Type to search, `↑`/`↓` to move, `↵` to run.
- `esc` returns from a result to the palette.
