<div align="center">

# codex-cli-installer

**One command. A working [Codex CLI](https://developers.openai.com/codex/cli/) setup.**
macOS · Windows · Linux · WSL

[![ci](https://github.com/jtlgrowth/codex-cli-installer/actions/workflows/ci.yml/badge.svg)](https://github.com/jtlgrowth/codex-cli-installer/actions/workflows/ci.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-black.svg)](LICENSE)
[![platform](https://img.shields.io/badge/platform-macOS%20%7C%20Windows%20%7C%20Linux%20%7C%20WSL-black.svg)](#what-it-does)
[![shell](https://img.shields.io/badge/shell-bash%20%7C%20powershell-black.svg)](#how-it-works)

</div>

---

It installs the things you actually need around Codex CLI: a package manager, `git`, Node LTS,
`ripgrep`, installs OpenAI's `@openai/codex` package, wires your `PATH`,
and **verifies the result** instead of assuming it. If `codex --version` does not answer at the
end, the script fails loudly rather than printing a green "done".

## Just want it working?

**[Follow the setup page](https://jtlgrowth.com/setup-codex/)**: one command
for your platform, what to do next, and what to do when it does not work.

## Install

**macOS / Linux / WSL / Git Bash**

```bash
curl -fsSL https://raw.githubusercontent.com/jtlgrowth/codex-cli-installer/main/install.sh | CXI_SKILLS=hire,setup bash
```

**Windows (PowerShell)**

```powershell
$env:CXI_SKILLS='hire,setup'; irm https://raw.githubusercontent.com/jtlgrowth/codex-cli-installer/main/install.ps1 | iex
```

**Windows (Command Prompt / `cmd.exe`)**

```bat
powershell -NoProfile -ExecutionPolicy Bypass -Command "$env:CXI_SKILLS='hire,setup'; irm https://raw.githubusercontent.com/jtlgrowth/codex-cli-installer/main/install.ps1 | iex"
```

Windows Terminal opens whichever profile is set as the default, and on plenty of machines that is
Command Prompt, not PowerShell. The PowerShell line pasted into `cmd` fails with
`'irm' is not recognized`; this one works in either, and `-ExecutionPolicy Bypass` also clears the
"running scripts is disabled on this system" error without changing a machine-wide setting.

Then open a new terminal, run `codex login`, and sign in with your ChatGPT account.

### Read it before you pipe it

Piping a script from the internet into your shell means running code you have not read. That is
true of this script and of every other install one-liner. If you would rather look first:

```bash
curl -fsSL https://raw.githubusercontent.com/jtlgrowth/codex-cli-installer/main/install.sh -o install.sh
less install.sh          # read it
bash install.sh --dry-run  # see every command it would run, without running any
bash install.sh
```

```powershell
irm https://raw.githubusercontent.com/jtlgrowth/codex-cli-installer/main/install.ps1 -OutFile install.ps1
notepad install.ps1
.\install.ps1 -DryRun
.\install.ps1
```

## What it does

| Step | macOS | Windows | Linux / WSL |
| --- | --- | --- | --- |
| Package manager | Homebrew (installed if missing) | winget (Node still installs without it) | apt / dnf / pacman / zypper |
| Build tools | Xcode Command Line Tools | not applicable | not applicable |
| `git` | via Homebrew | `Git.Git` | via system package manager |
| Node LTS (for MCP servers and skills) | via Homebrew | `OpenJS.NodeJS.LTS`, falling back to the nodejs.org `.msi` | NodeSource Node 22 on apt; native package manager elsewhere |
| `ripgrep` (fast search) | via Homebrew | `BurntSushi.ripgrep.MSVC` | via system package manager |
| Codex CLI | `npm install --global --prefix ~/.local @openai/codex@latest` | `npm install --global @openai/codex@latest` | same as macOS |
| `PATH` | appended to your shell rc, once | refreshed from the registry | appended to your shell rc, once |
| Verify | `codex --version` + `codex doctor` | same | same |

Anything already installed is detected and skipped, so re-running is cheap and safe. Re-running
also never adds a second `PATH` line to your shell config.

Node and npm install Codex CLI. Git and ripgrep are included because Codex uses them the moment
you point it at a repository. Use `--minimal` only when a current Node installation already exists.

## How it works

```
                 ┌─────────────────────────────────────────┐
  one command    │  detect OS, arch, shell, package manager │
       │         └──────────────────┬──────────────────────┘
       ▼                            ▼
  install.sh          ┌──────────────────────────────┐
  install.ps1         │  install what is missing:    │   already there? skipped
                      │  brew/winget, git, node, rg  │
                      └──────────────┬───────────────┘
                                     ▼
                      ┌──────────────────────────────┐
                      │  OpenAI package on npm      │   @openai/codex@latest
                      │  native binary selected     │   for the detected platform
                      └──────────────┬───────────────┘
                                     ▼
                      ┌──────────────────────────────┐
                      │  PATH into your shell rc     │   exactly once, re-run safe
                      └──────────────┬───────────────┘
                                     ▼
                      ┌──────────────────────────────┐
                      │  codex --version + doctor   │   non-zero exit if this fails
                      └──────────────────────────────┘
```

Three properties this buys you, which a hand-typed sequence of commands does not:

1. **Idempotent.** Run it twice and the second run installs nothing and adds no second `PATH`
   line. The CI suite asserts that by counting the marker in the shell rc before and after.
2. **Inspectable.** `--dry-run` prints every command without executing any of them. That is the
   demo above.
3. **Honest.** The exit code reflects whether `codex --version` actually answered.

## Options

Because a piped script has no command-line arguments, every flag has an environment variable twin.

| Flag | Environment variable | Effect |
| --- | --- | --- |
| `--skills hire,setup` | `CXI_SKILLS=hire,setup` | also install agent skills into `~/.agents/skills/` (comma-separated; known: `hire`, `setup`; never overwrites an existing skill) |
| `--minimal` | `CXI_MINIMAL=1` | skip the package manager and `git`/`node`/`ripgrep`; install Codex CLI only |
| `--yes` | `CXI_YES=1` | non-interactive, answer yes to everything |
| `--dry-run` | `CXI_DRY_RUN=1` | print every command, execute none |
| `--help` | not applicable | usage |

Piped, with options:

```bash
curl -fsSL https://raw.githubusercontent.com/jtlgrowth/codex-cli-installer/main/install.sh | bash
```

```powershell
irm https://raw.githubusercontent.com/jtlgrowth/codex-cli-installer/main/install.ps1 | iex
```

## Skills

`--skills hire` installs [`hire`](https://github.com/jtlgrowth/hire) into
`~/.agents/skills/hire`, which is where Codex looks for user skills. Start a new Codex session,
then say `Use $hire to hire my first AI employee.`

```bash
curl -fsSL https://raw.githubusercontent.com/jtlgrowth/codex-cli-installer/main/install.sh | CXI_SKILLS=hire,setup bash
```

```powershell
$env:CXI_SKILLS = 'hire,setup'; irm https://raw.githubusercontent.com/jtlgrowth/codex-cli-installer/main/install.ps1 | iex
```

Known skills: `hire`, `setup`. The list is an allowlist in the script rather than a
`--skills <url>` flag, because a `curl | bash` installer that downloads arbitrary URLs is
a different and much worse thing than one that installs a named, reviewable list.

A skill that is already installed is left alone and reported as such. Re-running the line
is safe. Skills ship scripts, so they need Node, which this installer already sets up
unless you pass `--minimal`.

## Troubleshooting

**`codex: command not found` after install.** Your shell has not reloaded. Open a new terminal, or:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

**Windows: `winget` is not recognised.** Install *App Installer* from the
[Microsoft Store](https://apps.microsoft.com/detail/9nblggh4nns1), then re-run. Codex CLI itself
still installs without it. Only the prerequisites are skipped.

**Windows: a script "is not digitally signed".** For the current window only:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

**macOS: Xcode Command Line Tools dialog.** The script triggers it, but macOS runs that install in a
GUI window it cannot wait on. Let it finish, then re-run the one-liner.

**Homebrew installed but `brew` still not found.** Re-run the script. It evaluates `brew shellenv`
for your architecture (`/opt/homebrew` on Apple Silicon, `/usr/local` on Intel) and writes it to
your shell rc.

**Do not use `sudo`.** The installer uses a user-writable npm prefix on macOS and Linux.
Under `sudo`, files would land in root's home and `codex` would not exist in your own shell.

## Verification status

| Platform | What was actually run |
| --- | --- |
| macOS (Apple Silicon) | shell parse, shellcheck, dry runs, skill tests, and `codex --version` verified locally |
| Ubuntu 24.04 | real-install CI job defined for Codex CLI plus both skills; it runs after this repository is published |
| Windows Server | PowerShell parse, analyzer, Command Prompt quoting, real-install, and skill-test CI jobs defined; they run after publication |
| WSL | covered by the Linux installer path; not separately exercised yet |

Windows is not yet locally verified because PowerShell is unavailable on this Mac. The included
CI exercises the PowerShell and Command Prompt paths on a Windows runner once the repository is
published. A consumer Windows desktop remains a separate workshop-day check.

## Uninstall

Remove the npm package with the same prefix used during installation:

```bash
npm uninstall --global --prefix "$HOME/.local" @openai/codex
```

Remove the workshop skills only if you no longer want them:

```bash
rm -rf ~/.agents/skills/hire ~/.agents/skills/setup
```

Then delete the `# added by codex-cli-installer` block from your shell rc.

Do **not** `rm -rf ~/.codex`. That directory also holds your login, your session history and
any configuration you added yourself, none of which came from this installer. Homebrew, git,
node and ripgrep are left alone too; they are normal tools, not part of Codex CLI.

## License

MIT. This is an unofficial convenience wrapper. Codex CLI is OpenAI's, and the installer uses
OpenAI's published `@openai/codex` package rather than mirroring the CLI.
