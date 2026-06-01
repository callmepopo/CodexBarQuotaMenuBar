# Changelog

## v2.0.0 - 2026-06-01

- Added adaptive Codex quota loading for CodexBar's segmented and stacked multi-account layouts.
- In segmented layout, read current workspace quota pools from CodexBar history so DIY does not display stale account snapshots.
- In stacked layout, keep using CodexBar account snapshots and preserve per-login re-authentication errors.
- Matched Codex account quota rows using CodexBar's visible account id logic instead of the shared provider/workspace key.
- Stopped using Codex history or provider-key cache data to fill a different Codex login that shares the same workspace quota pool.
- Show CodexBar snapshot errors such as re-authentication requirements on the affected login account instead of borrowing another account's quota.
- Fixed reset-time formatting when CodexBar only returns a display label, avoiding `Resets in --` next to an absolute reset label.

## v1.0.5 - 2026-05-22

- Changed the local launch command to start the menu bar app as a normal background process instead of a `launchctl submit` job.
- Ensured choosing Quit exits the DIY menu bar app without being relaunched by the helper startup script.

## v1.0.4 - 2026-05-22

- Added a cross-path single-instance lock so launching the downloaded `.app` and local helper binary at the same time does not create duplicate menu bar icons.
- Added a generated macOS app icon and packaged it as `AppIcon.icns`.
- Updated the app bundle metadata so Finder and the Downloads folder show the custom icon.

## v1.0.3 - 2026-05-22

- Fixed the relative reset countdown so `Resets in ...` is recalculated from an explicit app clock instead of relying on implicit SwiftUI view refreshes.
- Keep the absolute reset time sourced from CodexBar local `resetsAt` data while refreshing the relative countdown every 30 seconds.
- Ensure expired reset windows display `0h0m` instead of a stale remaining duration.

## v1.0.2 - 2026-05-22

- Added a DIY last-good Codex snapshot cache so offline refresh failures keep showing the most recent successful per-account quota data.
- Store only one latest successful snapshot per Codex account; cache entries are overwritten instead of appended.
- Prefer the DIY cache before falling back to older CodexBar history when `codex-account-snapshots.json` contains network errors.
- Avoid storing full email addresses, tokens, cookies, API keys, or auth file contents in the DIY cache.
- Select the latest history entry by `capturedAt` instead of relying on JSON array order.

## v1.0.1 - 2026-05-21

- Refined Codex `Not started yet` detection so the 5-hour and 1-week quota windows are evaluated independently.
- Treat a Codex 5-hour window as not started only when `usedPercent <= 1` and `resetsAt` is approximately `capturedAt + 5 hours`.
- Treat a Codex 1-week window as not started only when `usedPercent == 0` and `resetsAt` is approximately `capturedAt + 7 days`.
- Clarified that quota percentages, reset times, and quota status come from CodexBar local quota data, not from `auth.json`.
- Clarified that Codex/CodexBar auth configuration is used only for account identity metadata and account switching.
