# Automations

A native macOS utility platform — a Raycast-styled command palette for running
shell commands, plus a **Grimy Grills** finance dashboard for company spending.

Design language comes from the Raycast design system in
[awesome-design-md](https://github.com/nolanselby/awesome-design-md).

## Run

**Terminal 1 — finance API (Wells Fargo via Plaid):**

```bash
cd backend
cp .env.example .env   # add PLAID_CLIENT_ID + PLAID_SECRET from dashboard.plaid.com
npm install
npm start              # listens on http://127.0.0.1:8787
```

In the [Plaid Dashboard](https://dashboard.plaid.com/developers/api), add these **Allowed redirect URIs** (HTTPS required):

- `https://localhost:8787/plaid/oauth`
- `https://localhost:8787/plaid/complete`

Generate the local HTTPS cert first:

```bash
Scripts/setup-local-https.sh
```

**Terminal 2 — macOS app:**

```bash
swift run
```

The app opens on **Grimy Grills → Spending**. Click **Connect bank account** to link Wells Fargo through Plaid (opens your browser). When sign-in finishes, spending totals and categories populate automatically.

Use **Sandbox** keys first (`PLAID_ENV=sandbox`) to test with Plaid's fake bank. Switch to `development` or `production` for real Wells Fargo.

## Build a distributable .app

```bash
Scripts/make-app.sh       # produces ./Automations.app
open Automations.app
```

## Controls

Everything is **mouse-accessible** — click sidebar tabs, buttons, and automation rows.

Keyboard shortcuts still work in Automations:

- Type to search, `↑`/`↓` to move, `↵` to run.
- `esc` returns from a result to the palette.

## Project layout

```
Sources/Automations/
  AutomationsApp.swift          # shell + sidebar navigation
  Models/
    AppSection.swift            # Grimy Grills vs Automations
    FinanceModels.swift         # spending + bank connection types
    Automation.swift            # automation catalog
  Services/
    FinanceAPIClient.swift      # talks to local Plaid proxy
    FinanceStore.swift          # finance UI state
    PlaidLinkFlow.swift         # browser-based bank connect
    CommandRunner.swift
  Views/
    AppSidebar.swift            # clickable section switcher
    Finance/                    # Grimy Grills spending dashboard
    PaletteView.swift           # command palette (also clickable)
    OutputView.swift
    Components.swift
  Theme/Theme.swift
backend/
  server.js                     # local Plaid proxy (secrets stay off the Mac app)
Scripts/make-app.sh
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

## What's next

Phase 1 delivers **spending**: total outflows, Plaid's default categories, and recent transactions. Custom Grimy Grills categories (COGS, labor, ad channels, etc.) come next once bank data is flowing.
