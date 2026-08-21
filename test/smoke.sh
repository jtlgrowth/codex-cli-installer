#!/usr/bin/env bash
#
# Smoke tests. Static checks plus dry runs - nothing here installs anything.
#   bash test/smoke.sh
#
set -euo pipefail

cd "$(dirname "$0")/.."
FAILED=0

pass() { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAILED=1; }
head2() { printf '\n\033[1m%s\033[0m\n' "$1"; }

head2 "1. Shell syntax"
if bash -n install.sh; then pass "install.sh parses"; else fail "install.sh has a syntax error"; fi

head2 "2. shellcheck"
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck install.sh test/smoke.sh; then pass "shellcheck clean"; else fail "shellcheck findings"; fi
else
  printf '  \033[33mSKIP\033[0m shellcheck not installed\n'
fi

head2 "3. PowerShell syntax"
if command -v pwsh >/dev/null 2>&1; then
  # shellcheck disable=SC2016  # PowerShell variables must reach pwsh unexpanded
  if pwsh -NoProfile -Command '
      $errors = $null
      [System.Management.Automation.Language.Parser]::ParseFile(
        (Resolve-Path ./install.ps1), [ref]$null, [ref]$errors) | Out-Null
      if ($errors) { $errors | ForEach-Object { Write-Host $_.Message }; exit 1 }
      exit 0'; then
    pass "install.ps1 parses"
  else
    fail "install.ps1 has a parse error"
  fi
else
  printf '  \033[33mSKIP\033[0m pwsh not installed\n'
fi

head2 "4. Codex-only destinations"
# These are literal source-code patterns.
# shellcheck disable=SC2016
if grep -q '\$HOME/.agents/skills' install.sh && ! grep -q '\.claude' install.sh; then
  pass "bash installer targets Codex skill paths only"
else
  fail "bash installer contains a stale or incorrect skill destination"
fi
if grep -q "'.agents'" install.ps1 && ! grep -q '\.claude' install.ps1; then
  pass "PowerShell installer targets Codex skill paths only"
else
  fail "PowerShell installer contains a stale or incorrect skill destination"
fi
if grep -q 'deb.nodesource.com/setup_22.x' install.sh; then
  pass "apt path installs Node 22 with npm"
else
  fail "apt path does not provide a current Node and npm"
fi

head2 "5. --help exits clean"
if bash install.sh --help >/dev/null 2>&1; then pass "--help works"; else fail "--help failed"; fi

head2 "6. Unknown flags are rejected"
if bash install.sh --not-a-real-flag >/dev/null 2>&1; then
  fail "unknown flag was accepted"
else
  pass "unknown flag rejected"
fi

head2 "7. Dry runs install nothing"
for variant in "--dry-run" "--dry-run --minimal"; do
  before="$(md5sum ~/.zshrc 2>/dev/null || shasum ~/.zshrc 2>/dev/null || echo none)"
  # shellcheck disable=SC2086
  if out="$(bash install.sh $variant 2>&1)"; then
    after="$(md5sum ~/.zshrc 2>/dev/null || shasum ~/.zshrc 2>/dev/null || echo none)"
    if [ "$before" != "$after" ]; then
      fail "dry run '$variant' modified the shell rc"
    elif printf '%s' "$out" | grep -q "would run"; then
      pass "dry run '$variant' printed commands and changed nothing"
    else
      fail "dry run '$variant' printed no commands"
    fi
  else
    fail "dry run '$variant' exited non-zero"
  fi
done

head2 "8. --skills"
for variant in "--skills hire" "--skills=hire" "--skills hire,setup"; do
  # shellcheck disable=SC2086
  if out="$(bash install.sh --dry-run --minimal $variant 2>&1)"; then
    if printf '%s' "$out" | grep -qE "would download:.*codeload\.github\.com/jtlgrowth/hire|skill hire already installed"; then
      pass "'$variant' plans the hire download"
    else
      fail "'$variant' did not plan a skill install"
    fi
  else
    fail "'$variant' exited non-zero"
  fi
done

out="$(CXI_SKILLS=hire bash install.sh --dry-run --minimal 2>&1)"
if printf '%s' "$out" | grep -qE "would download:.*jtlgrowth/hire|skill hire already installed"; then
  pass "CXI_SKILLS=hire works via the env var"
else
  fail "CXI_SKILLS was ignored"
fi

# The skill must land where Codex CLI actually looks for it.
# This is a literal source-code pattern.
# shellcheck disable=SC2016
if grep -q 'dest="$HOME/.agents/skills/$name"' install.sh; then
  pass "target is ~/.agents/skills/hire"
else
  fail "skill target path changed"
fi

head2 "9. Unknown or empty --skills fails cleanly"
code=0
bash install.sh --skills nope --dry-run >/dev/null 2>&1 || code=$?
if [ "$code" -eq 2 ]; then pass "unknown skill exits 2"; else fail "unknown skill exited $code - expected 2"; fi
for variant in "--skills" "--skills="; do
  code=0
  bash install.sh "$variant" >/dev/null 2>&1 || code=$?
  if [ "$code" -eq 2 ]; then
    pass "'$variant' exits 2"
  else
    fail "'$variant' exited $code - expected 2"
  fi
done

head2 "10. PowerShell skill install (the real functions, extracted)"
if command -v pwsh >/dev/null 2>&1; then
  ps_scratch="$(mktemp -d)"
  if pwsh -NoProfile -File test/skill-install.ps1 ./install.ps1 "$ps_scratch" >/dev/null 2>&1; then
    if [ -f "$ps_scratch/.agents/skills/hire/SKILL.md" ]; then
      pass "install.ps1 downloads and extracts a skill, and re-running leaves it alone"
    else
      fail "PowerShell skill install produced no SKILL.md"
    fi
  else
    fail "PowerShell skill install failed"
  fi
  printf '  scratch kept for inspection: %s\n' "$ps_scratch"
else
  printf '  \033[33mSKIP\033[0m pwsh not installed\n'
fi

head2 "11. sudo is refused"
out="$(SUDO_USER=someone bash install.sh --dry-run 2>&1 || true)"
if [ "$(id -u)" -eq 0 ]; then
  if printf '%s' "$out" | grep -q "do not run this installer with sudo"; then
    pass "sudo refused"
  else
    fail "sudo not refused"
  fi
else
  printf '  \033[33mSKIP\033[0m not running as root, sudo branch unreachable\n'
fi

printf '\n'
if [ "$FAILED" -eq 0 ]; then
  printf '\033[32mAll smoke tests passed.\033[0m\n'
else
  printf '\033[31mSmoke tests failed.\033[0m\n'
  exit 1
fi
