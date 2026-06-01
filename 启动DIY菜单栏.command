#!/bin/zsh
cd "$(dirname "$0")"

if pgrep -x CodexBarQuotaMenuBar >/dev/null 2>&1; then
  exit 0
fi

LABEL="local.CodexBarQuotaMenuBar"

if [[ -x "./bin/CodexBarQuotaMenuBar" ]]; then
  launchctl remove "$LABEL" >/dev/null 2>&1 || true
  launchctl submit -l "$LABEL" -- "$PWD/bin/CodexBarQuotaMenuBar" >/dev/null 2>&1
else
  swift run CodexBarQuotaMenuBar >/dev/null 2>&1 &!
fi

exit 0
