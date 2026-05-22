#!/bin/zsh
cd "$(dirname "$0")"

if pgrep -x CodexBarQuotaMenuBar >/dev/null 2>&1; then
  exit 0
fi

if [[ -x "./bin/CodexBarQuotaMenuBar" ]]; then
  "$PWD/bin/CodexBarQuotaMenuBar" >/dev/null 2>&1 &!
else
  swift run CodexBarQuotaMenuBar >/dev/null 2>&1 &!
fi

exit 0
