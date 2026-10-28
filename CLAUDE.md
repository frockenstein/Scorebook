# Scorebook — Claude Context

## What this app is
A traditional paper baseball scorebook for iPhone. The scorecard grid is the home screen:
a diamond per batter per inning, penciled in as the game goes. Personal use, no backend.
Web prototype of the same idea lives in `~/code/www/scorebook` (reference for behavior).

## Stack
SwiftUI, iOS 17+, Swift 6, portrait iPhone. `@Observable` models. XcodeGen (`project.yml`);
regenerate with `xcodegen generate`. No third-party packages. No secrets.

## Architecture
- `Engine/` — pure value types, no UI. A `Game` is setup + an **event log** (`Event`: plate
  appearance, runner event, substitution, pitching change). `GameState(game:)` replays the log
  into everything shown: cells (diamonds), bases, outs, stats, play log. Undo = drop last event.
  `Planner` decides default runner outcomes and which runners need a question.
- `Persistence/` — `GameLibrary` (one JSON file per game in Documents/Games, current game id in
  UserDefaults); `GameSession` (open game + replayed state; `commit` validates by replaying).
- `Views/` — `GameScreen` (main), `BookView` (pinned names + scrolling grid), `DiamondCell`
  (Canvas), `EntrySheet` + `EntryFlow` (result → fielders → runner questions → commit),
  `FieldPicker`, `OtherSheets` (runner events, subs, stats), `GameSetupViews`.

## Rules baked into the engine (see ScorebookTests)
- Runs don't score if the 3rd out is the batter or a force (FC/DP).
- Outs are numbered runner-first, then batter.
- Run is unearned if the runner reached on E, or the play is an E/PB event, or flagged.
- Walk-offs and extra innings end/extend the game; the book grows columns past the 9th.

## Design
Paper and ink: cream paper, green header, navy ink, red-orange accent for outs/active cell.
Serif for notation. "Dead simple": one tap for common results; only ask when the app can't know.

## Gotchas
- Sheet state must live in the sheet (`EntrySheet` creates its own `EntryFlow`); passing an
  optional @State flow from the parent rendered a blank sheet.
- `AppIcon-1024.png` must be exactly 1024×1024 with no alpha or the asset catalog rejects it.
- Simulator screenshots lag a tap by ~1s; wait before capturing.

## Not yet
Editing old cells (only undo), hit-location lines, landscape layout, iCloud sync.
