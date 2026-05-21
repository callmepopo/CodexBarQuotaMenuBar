# Changelog

## v1.0.1 - 2026-05-21

- Refined Codex `Not started yet` detection so the 5-hour and 1-week quota windows are evaluated independently.
- Treat a Codex 5-hour window as not started only when `usedPercent <= 1` and `resetsAt` is approximately `capturedAt + 5 hours`.
- Treat a Codex 1-week window as not started only when `usedPercent == 0` and `resetsAt` is approximately `capturedAt + 7 days`.
- Clarified that quota percentages, reset times, and quota status come from CodexBar local quota data, not from `auth.json`.
- Clarified that Codex/CodexBar auth configuration is used only for account identity metadata and account switching.
