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

head2 "4. Codex-only, and no public skill source"
if ! grep -q '\.claude' install.sh && ! grep -q '\.claude' install.ps1; then
  pass "installers never touch Claude Code paths"
else
  fail "an installer references a Claude Code path"
fi
# The workshop skills are private. Neither installer may download them from a
# public repo again.
if ! grep -qE 'jtlgrowth/jtl|codeload\.github\.com' install.sh install.ps1; then
  pass "no public skill download in either installer"
else
  fail "an installer still downloads skills from a public repo"
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

head2 "8. Old --skills commands still run and point to the skills page"
for variant in "--skills hire" "--skills=hire" "--skills hire,setup" "--skills" "--skills="; do
  # shellcheck disable=SC2086
  if out="$(bash install.sh --dry-run --minimal $variant 2>&1)"; then
    if printf '%s' "$out" | grep -q 'jtlgrowth.com/skills'; then
      pass "'$variant' points to the skills page"
    else
      fail "'$variant' did not point to the skills page"
    fi
  else
    fail "'$variant' exited non-zero"
  fi
done

out="$(CXI_SKILLS=hire,setup bash install.sh --dry-run --minimal 2>&1)"
if printf '%s' "$out" | grep -q 'jtlgrowth.com/skills'; then
  pass "CXI_SKILLS=hire,setup points to the skills page"
else
  fail "CXI_SKILLS was ignored"
fi

head2 "9. sudo is refused"
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
