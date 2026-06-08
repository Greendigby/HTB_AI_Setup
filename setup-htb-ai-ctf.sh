#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# HTB AI CTF Bootstrap
#
# Purpose:
#   Prepare a Parrot / HTB Pwnbox / Kali-like VM for
#   AI-assisted Hack The Box / CTF work using:
#     - OpenAI Codex CLI
#     - Claude Code
#     - Google Antigravity CLI
#     - Gemini CLI
#
# Provides:
#   - CTF workspace structure
#   - Python venv and common CTF libraries
#   - Codex AGENTS.md guidance
#   - Claude CLAUDE.md guidance
#   - Gemini GEMINI.md guidance
#   - Codex skills under ~/.agents/skills and ~/ctf-event/.agents/skills
#   - Claude skills under ~/.claude/skills and ~/ctf-event/.claude/skills
#   - Challenge intake helper: ctf-intake
#   - Agent launcher: ctf-start
#   - Challenge board: ctf-board
#   - Completion checker: ctf-finish / ctf-writeup-check
#
# Usage:
#   ./setup-htb-ai-ctf.sh
#   ./setup-htb-ai-ctf.sh --with-apt
#
# Notes:
#   - Do not put API keys or passwords in this script.
#   - Prefer browser/OAuth login for Codex, Claude, Gemini, and Antigravity.
#   - Use only for authorised HTB/CTF/lab targets.
#   - Do not run --with-apt on a live ISO overlay session.
# ============================================================

CTF_ROOT="${CTF_ROOT:-$HOME/ctf-event}"
PYENV_DIR="$CTF_ROOT/.venv"
LOCAL_BIN="$HOME/.local/bin"
WITH_APT="false"

for arg in "$@"; do
  case "$arg" in
    --with-apt)
      WITH_APT="true"
      ;;
    -h|--help)
      echo "Usage: $0 [--with-apt]"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg"
      echo "Usage: $0 [--with-apt]"
      exit 1
      ;;
  esac
done

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

print_status() {
  local name="$1"
  local cmd="$2"

  if command_exists "$cmd"; then
    echo "    ok: $name -> $(command -v "$cmd")"
  else
    echo "    missing: $name"
  fi
}

install_apt_package() {
  local pkg="$1"

  if sudo apt-get install -y --no-install-recommends "$pkg"; then
    echo "    installed: $pkg"
  else
    echo "    skipped or unavailable: $pkg"
  fi
}

safe_mkdirs() {
  mkdir -p "$CTF_ROOT"/{_index,challenges,notes,wordlists,scripts,loot,tmp,writeups}
  mkdir -p "$LOCAL_BIN"
  mkdir -p "$HOME/.codex"
  mkdir -p "$HOME/.claude"
  mkdir -p "$HOME/.agents/skills"
  mkdir -p "$HOME/.claude/skills"
}

ensure_path() {
  if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
  fi

  if ! grep -q 'export PATH="$HOME/.claude/local:$PATH"' "$HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.claude/local:$PATH"' >> "$HOME/.bashrc"
  fi

  export PATH="$HOME/.local/bin:$HOME/.claude/local:$PATH"
}

echo "[+] Starting HTB AI CTF bootstrap"
echo "[+] User: $(whoami)"
echo "[+] Host: $(hostname)"
echo "[+] Workspace: $CTF_ROOT"
echo

ROOT_FSTYPE="$(findmnt -n -o FSTYPE / 2>/dev/null || echo unknown)"
ROOT_SOURCE="$(findmnt -n -o SOURCE / 2>/dev/null || echo unknown)"

echo "[+] Root filesystem:"
echo "    source: $ROOT_SOURCE"
echo "    fstype: $ROOT_FSTYPE"
echo

if [ "$WITH_APT" = "true" ] && [ "$ROOT_FSTYPE" = "overlay" ]; then
  echo "[!] Refusing to run apt on an overlay/live ISO filesystem."
  echo "[!] Install the VM to disk first, then rerun this script."
  echo "[!] Run without --with-apt only if you deliberately want a lightweight live-session setup."
  exit 1
fi

echo "[+] Disk space:"
df -h / "$HOME" /tmp || true
echo

safe_mkdirs
ensure_path

echo "[+] Baseline command check"
print_status "bash" bash
print_status "curl" curl
print_status "git" git
print_status "python3" python3
print_status "pipx" pipx
print_status "node" node
print_status "npm" npm
print_status "jq" jq
print_status "tmux" tmux
echo

if [ "$WITH_APT" = "true" ]; then
  echo "[+] Installing apt dependencies"
  sudo apt-get update

  APT_PACKAGES=(
    ca-certificates
    curl
    git
    jq
    tmux
    python3
    python3-pip
    python3-venv
    python3-dev
    pipx
    nodejs
    npm
    tar
    gzip
    xz-utils
    unzip
    bzip2
    coreutils
    build-essential
    libc6
    libstdc++6
    ripgrep
    fd-find
    bat
    p7zip-full
    xxd
    netcat-openbsd
    socat
    sqlite3
    nmap
    gobuster
    ffuf
    feroxbuster
    seclists
    wordlists
    sqlmap
    exiftool
    binwalk
    foremost
    steghide
    zbar-tools
    gdb
    gdbserver
    ltrace
    strace
    checksec
    radare2
    xclip
    wl-clipboard
    tree
    dos2unix
  )

  for pkg in "${APT_PACKAGES[@]}"; do
    install_apt_package "$pkg"
  done

  echo "[+] Cleaning apt cache"
  sudo apt-get clean || true
  sudo rm -rf /var/cache/apt/archives/* || true
else
  echo "[+] Skipping apt installs"
  echo "    Re-run with --with-apt on an installed VM if packages are missing."
fi

echo
echo "[+] Rechecking baseline commands"
print_status "curl" curl
print_status "git" git
print_status "python3" python3
print_status "pipx" pipx
print_status "node" node
print_status "npm" npm
print_status "jq" jq
print_status "tmux" tmux
echo

echo "[+] Creating Python virtual environment"

if ! command_exists python3; then
  echo "[!] python3 is missing. Install python3 first or rerun with --with-apt."
  exit 1
fi

if [ ! -d "$PYENV_DIR" ]; then
  python3 -m venv "$PYENV_DIR"
fi

# shellcheck disable=SC1091
source "$PYENV_DIR/bin/activate"

python -m pip install --upgrade pip wheel setuptools

python -m pip install \
  requests \
  beautifulsoup4 \
  lxml \
  pycryptodome \
  pwntools \
  z3-solver \
  sympy \
  python-dotenv \
  rich \
  ipython \
  flask \
  pyjwt

deactivate

echo "[+] Creating ctf-venv helper"

cat > "$LOCAL_BIN/ctf-venv" <<VENVEOS
#!/usr/bin/env bash
source "$PYENV_DIR/bin/activate"
echo "Activated CTF venv: $PYENV_DIR"
VENVEOS

chmod +x "$LOCAL_BIN/ctf-venv"

echo
echo "[+] Installing OpenAI Codex CLI"

if command_exists codex; then
  echo "    Codex already installed: $(command -v codex)"
  codex --version || true
else
  CODEX_INSTALLER="$(mktemp)"
  if curl -fsSL https://chatgpt.com/codex/install.sh -o "$CODEX_INSTALLER"; then
    printf "n\n" | sh "$CODEX_INSTALLER" || true
  else
    echo "    Failed to download Codex installer"
  fi
  rm -f "$CODEX_INSTALLER"

  ensure_path

  if command_exists codex; then
    echo "    Codex installed: $(command -v codex)"
    codex --version || true
  elif command_exists npm; then
    echo "    Codex installer did not complete. Trying npm fallback."
    sudo npm install -g @openai/codex || true

    if command_exists codex; then
      echo "    Codex installed via npm: $(command -v codex)"
      codex --version || true
    else
      echo "    Codex still not found"
    fi
  else
    echo "    Codex not installed and npm fallback unavailable"
  fi
fi

echo
echo "[+] Installing Claude Code"

if command_exists claude; then
  echo "    Claude Code already installed: $(command -v claude)"
  claude --version || true
else
  CLAUDE_INSTALLER="$(mktemp)"
  if curl -fsSL https://claude.ai/install.sh -o "$CLAUDE_INSTALLER"; then
    bash "$CLAUDE_INSTALLER" || true
  else
    echo "    Failed to download Claude Code installer"
  fi
  rm -f "$CLAUDE_INSTALLER"

  ensure_path

  if command_exists claude; then
    echo "    Claude Code installed: $(command -v claude)"
    claude --version || true
  else
    echo "    Claude Code still not found"
    echo "    Try opening a new terminal or run: source ~/.bashrc"
  fi
fi

echo
echo "[+] Installing Google Antigravity CLI"

if command_exists agy; then
  echo "    Antigravity already installed: $(command -v agy)"
  agy --version || true
else
  AGY_INSTALLER="$(mktemp)"
  if curl -fsSL https://antigravity.google/cli/install.sh -o "$AGY_INSTALLER"; then
    bash "$AGY_INSTALLER" || true
  else
    echo "    Failed to download Antigravity installer"
  fi
  rm -f "$AGY_INSTALLER"

  ensure_path

  if command_exists agy; then
    echo "    Antigravity installed: $(command -v agy)"
    agy --version || true
  else
    echo "    Antigravity still not found"
    echo "    This is non-critical. Codex and Claude are the priority tools."
  fi
fi

echo
echo "[+] Installing Gemini CLI"

if command_exists gemini; then
  echo "    Gemini CLI already installed: $(command -v gemini)"
  gemini --version || true
else
  if command_exists npm; then
    sudo npm install -g @google/gemini-cli || true

    if command_exists gemini; then
      echo "    Gemini CLI installed: $(command -v gemini)"
      gemini --version || true
    else
      echo "    Gemini CLI still not found after npm install"
    fi
  else
    echo "    npm unavailable; skipping Gemini CLI"
  fi
fi

echo
echo "[+] Creating global Codex guidance"

cat > "$HOME/.codex/AGENTS.md" <<'CODEXGLOBAL'
# Global Codex Working Agreements

You are helping with authorised Hack The Box / Capture the Flag work.

Scope:
- Work only on the explicitly provided HTB/CTF challenge scope.
- Keep all notes, scripts, artefacts, flags, and writeups inside the current challenge workspace unless the user explicitly instructs otherwise.
- Follow the challenge and event rules.
- Ask before installing packages.
- Ask before executing unknown local binaries unless the user has explicitly authorised that mode for the challenge.
- Do not submit flags automatically unless explicitly asked by the user.

Required completion behaviour:
- When a flag is found, save it to loot/flag.txt.
- Create or update writeup.md with a high-level explanation of:
  - challenge summary
  - initial observations
  - methodology
  - key findings
  - solve path
  - flag location
  - agent notes
  - remediation or learning point, where applicable
- Keep the writeup suitable for learning and review, not just a raw command log.

Preferred workflow:
1. Read challenge.yaml, original_prompt.md if present, notes.md, and local AGENTS.md.
2. Inspect local challenge files.
3. Create or update notes.md.
4. Use small auditable Python or Bash scripts where useful.
5. Keep scripts under scripts/.
6. Keep outputs or artefacts under loot/ or scans/.
7. Explain what changed and why.
CODEXGLOBAL

echo "[+] Creating global Claude guidance"

cat > "$HOME/.claude/CLAUDE.md" <<'CLAUDEGLOBAL'
# Global Claude Code Working Agreements

You are helping with authorised Hack The Box / Capture the Flag work.

Scope:
- Work only on the explicitly provided HTB/CTF challenge scope.
- Keep all notes, scripts, artefacts, flags, and writeups inside the current challenge workspace unless the user explicitly instructs otherwise.
- Follow the challenge and event rules.
- Ask before installing packages.
- Ask before executing unknown local binaries unless the user has explicitly authorised that mode for the challenge.
- Do not submit flags automatically unless explicitly asked by the user.

Required completion behaviour:
- When a flag is found, save it to loot/flag.txt.
- Create or update writeup.md with a high-level explanation of:
  - challenge summary
  - initial observations
  - methodology
  - key findings
  - solve path
  - flag location
  - agent notes
  - remediation or learning point, where applicable
- Keep the writeup suitable for learning and review, not just a raw command log.

Preferred workflow:
1. Read challenge.yaml, original_prompt.md if present, notes.md, and local CLAUDE.md.
2. Inspect local challenge files.
3. Create or update notes.md.
4. Use the relevant CTF skill.
5. Use small auditable Python or Bash scripts where useful.
6. Keep scripts under scripts/.
7. Keep outputs or artefacts under loot/ or scans/.
8. Explain what changed and why.
CLAUDEGLOBAL

echo "[+] Creating project guidance files"

cat > "$CTF_ROOT/AGENTS.md" <<'CODEXPROJECT'
# CTF Project Guidance for Codex

This repository is for authorised Hack The Box / Capture the Flag work.

Scope:
- Work only inside this CTF workspace unless explicitly told otherwise.
- Only operate against the explicitly provided challenge scope, including supplied targets, files, URLs, ports, and challenge artefacts.
- Follow the challenge and event rules.
- Do not submit flags automatically unless explicitly instructed.

Working conventions:
- Each challenge should have:
  - challenge.yaml
  - original_prompt.md
  - notes.md
  - AGENTS.md
  - scripts/
  - files/
  - loot/
  - scans/
  - prompts/
  - agent_runs/
  - writeup.md
- Keep commands and observations in notes.md.
- Prefer repeatable solve scripts over one-off manual changes.
- Keep output readable and explain what evidence supports each conclusion.

Required completion behaviour:
- When a flag is found:
  1. save it to loot/flag.txt
  2. save the final script or exact command where practical
  3. create/update writeup.md
  4. include a concise summary of how the agent solved the challenge
  5. include the vulnerability class or solving concept, where applicable
  6. include remediation guidance or learning point where relevant

High-level writeup format:
# Challenge Writeup: <name>

## Summary
Brief description of the challenge and target.

## Initial Observations
What was visible at the start.

## Methodology
High-level steps taken.

## Key Findings
Important routes, files, functions, endpoints, artefacts, or behaviours.

## Exploitation / Solve Path
The successful route to the flag, with necessary commands or scripts.

## Flag Location
Where and how the flag was found.

## Agent Notes
What the agent tried, what worked, and what was avoided.

## Remediation / Learning Point
What would prevent this issue in a real system, where applicable.

When asked to solve:
1. Start with triage.
2. Identify category and likely route.
3. Execute only within the authorised challenge scope.
4. Update notes.md throughout.
5. Create scripts under scripts/.
6. Save artefacts under loot/ or scans/.
7. Save flag to loot/flag.txt.
8. Create writeup.md before ending.
CODEXPROJECT

cat > "$CTF_ROOT/CLAUDE.md" <<'CLAUDEPROJECT'
# CTF Project Guidance for Claude Code

This repository is for authorised Hack The Box / Capture the Flag work.

Scope:
- Work only inside this CTF workspace unless explicitly told otherwise.
- Only operate against the explicitly provided challenge scope, including supplied targets, files, URLs, ports, and challenge artefacts.
- Follow the challenge and event rules.
- Do not submit flags automatically unless explicitly instructed.

Working conventions:
- Each challenge should have:
  - challenge.yaml
  - original_prompt.md
  - notes.md
  - CLAUDE.md
  - scripts/
  - files/
  - loot/
  - scans/
  - prompts/
  - agent_runs/
  - writeup.md
- Keep commands and observations in notes.md.
- Prefer repeatable solve scripts over one-off manual changes.
- Keep output readable and explain what evidence supports each conclusion.

Claude Code behaviour:
- Use the relevant skill when a challenge category is clear.
- Use /ctf-triage first when the path is not clear.
- Ask before installing packages.
- Ask before executing unknown local binaries unless the user has explicitly authorised that mode for the challenge.

Required completion behaviour:
- When a flag is found:
  1. save it to loot/flag.txt
  2. save the final script or exact command where practical
  3. create/update writeup.md
  4. include a concise summary of how the agent solved the challenge
  5. include the vulnerability class or solving concept, where applicable
  6. include remediation guidance or learning point where relevant

High-level writeup format:
# Challenge Writeup: <name>

## Summary
Brief description of the challenge and target.

## Initial Observations
What was visible at the start.

## Methodology
High-level steps taken.

## Key Findings
Important routes, files, functions, endpoints, artefacts, or behaviours.

## Exploitation / Solve Path
The successful route to the flag, with necessary commands or scripts.

## Flag Location
Where and how the flag was found.

## Agent Notes
What the agent tried, what worked, and what was avoided.

## Remediation / Learning Point
What would prevent this issue in a real system, where applicable.

When asked to solve:
1. Start with triage.
2. Identify category and likely route.
3. Execute only within the authorised challenge scope.
4. Update notes.md throughout.
5. Create scripts under scripts/.
6. Save artefacts under loot/ or scans/.
7. Save flag to loot/flag.txt.
8. Create writeup.md before ending.
CLAUDEPROJECT

cat > "$CTF_ROOT/GEMINI.md" <<'GEMINIPROJECT'
# Gemini / Antigravity CTF Project Context

This is an authorised Hack The Box / Capture the Flag workspace.

Scope:
- Work only on provided CTF challenge files and targets.
- Only operate against the explicitly provided challenge scope, including supplied targets, files, URLs, ports, and challenge artefacts.
- Follow the challenge and event rules.
- Do not submit flags automatically unless explicitly instructed.

Required completion behaviour:
- When a flag is found, save it to loot/flag.txt.
- Create or update writeup.md with:
  - challenge summary
  - methodology
  - key findings
  - solve path
  - flag location
  - agent notes
  - remediation or learning point

Preferred workflow:
- Triage first.
- Create a hypothesis.
- Test with small scripts.
- Record failed and successful attempts.
- Keep answers concise and evidence-based.
GEMINIPROJECT

echo "[+] Creating Codex and Claude skills"

CODEX_SKILLS_ROOT="$CTF_ROOT/.agents/skills"
CLAUDE_SKILLS_ROOT="$CTF_ROOT/.claude/skills"

SKILL_NAMES=(
  ctf-triage
  web-ctf
  crypto-ctf
  reverse-ctf
  forensics-ctf
  pwn-ctf
  misc-ctf
  osint-ctf
  ai-jailbreak-ctf
)

for skill in "${SKILL_NAMES[@]}"; do
  mkdir -p "$CODEX_SKILLS_ROOT/$skill" "$CLAUDE_SKILLS_ROOT/$skill"
done

create_skill_files() {
  local root="$1"

  cat > "$root/ctf-triage/SKILL.md" <<'SKILLTRIAGE'
---
name: ctf-triage
description: Initial triage for authorised HTB/CTF challenges. Use for setting up notes, identifying category, selecting methodology, and creating a solve plan.
---

# CTF Triage Skill

Use only for authorised HTB/CTF/lab challenges.

## Goals

1. Understand the challenge description, target, files, and hints.
2. Classify the challenge type.
3. Create or update notes.md.
4. Decide which specialist skill to use next.
5. Keep activity inside the provided challenge scope.
6. Ensure a high-level writeup is created when the flag is found.

## Category classification

Consider:
- web
- crypto
- reverse
- pwn
- forensics
- misc
- OSINT
- AI/prompt jailbreak
- cloud/container
- scripting/automation

## Initial workflow

1. Read challenge.yaml, original_prompt.md if present, notes.md, AGENTS.md, CLAUDE.md, GEMINI.md, README.md, and challenge files if present.
2. Create directories if missing:
   - files/
   - scripts/
   - scans/
   - loot/
   - tmp/
   - prompts/
   - agent_runs/
3. Record the target scope exactly.
4. Identify available input:
   - URL
   - host and port
   - downloadable files
   - source code
   - binary
   - archive
   - PCAP
   - image/audio/video
   - ciphertext
   - prompt/chat interface
5. Start with local inspection and challenge-scope service identification.
6. For network targets, use only the provided host/port/URL scope.
7. Follow the challenge and event rules.

## Required notes.md updates

Maintain:
- challenge name
- category guess
- scope
- commands run
- observations
- hypotheses
- eliminated paths
- successful path
- flag status

## Required completion behaviour

When a flag is found:
1. Save it to loot/flag.txt.
2. Save the final solve script or command where practical.
3. Create/update writeup.md.
4. Explain the route at a high level.
5. Include the vulnerability class or solving concept where relevant.
6. Include remediation or learning point where relevant.

## Output

Return:
- category guess
- evidence
- current findings
- recommended next steps
- whether a specialist skill should be used
- commands run or proposed
SKILLTRIAGE

  cat > "$root/web-ctf/SKILL.md" <<'SKILLWEB'
---
name: web-ctf
description: Authorised HTB/CTF web challenge workflow. Use for HTTP services, source review, APIs, auth flaws, file read, injection, upload flaws, template injection, XXE, SSRF, deserialization, and browser/app analysis.
---

# Web CTF Skill

Use only for authorised HTB/CTF/lab web challenges.

## Goals

1. Identify the web technology and attack surface.
2. Inspect routes, forms, cookies, JavaScript, APIs, and parameters.
3. Test plausible CTF-relevant vulnerability classes.
4. Build repeatable scripts where useful.
5. Save the flag and create writeup.md when solved.

## First checks

Use challenge-scoped checks:
- curl -i
- curl -s
- whatweb
- browser inspection
- robots.txt
- sitemap.xml
- source HTML
- static JavaScript
- cookies
- response headers
- forms
- linked routes

## Common HTB web paths

Consider:
- hidden routes
- debug endpoints
- API endpoints
- IDOR
- broken authentication
- weak session logic
- JWT issues in CTF contexts
- SQL injection
- NoSQL injection
- SSTI
- command injection
- path traversal
- local file inclusion
- arbitrary file read
- file upload issues
- XML external entity expansion
- SSRF
- insecure deserialization
- prototype pollution
- client-side logic flaws
- exposed source/config/secrets in challenge files
- Werkzeug/Flask debug artefacts where relevant
- template engines such as Jinja2, Twig, EJS, Handlebars

## Enumeration

- Keep enumeration relevant to the supplied challenge scope.
- Use ffuf/gobuster after HTTP is confirmed and where useful.
- Choose wordlists and rate settings appropriate to the event and target.

## Script preferences

When useful, create:
- scripts/check_http.py
- scripts/enumerate_routes.py
- scripts/solve.py

Use:
- requests
- BeautifulSoup
- urllib.parse
- json
- re

## Required completion behaviour

When a flag is found:
1. Save it to loot/flag.txt.
2. Save the HTTP response or evidence under loot/ if useful.
3. Save a repeatable solve script under scripts/solve.py where practical.
4. Create/update writeup.md with:
   - challenge summary
   - discovered routes/endpoints
   - vulnerable parameter or endpoint
   - successful request or payload
   - why the vulnerability worked
   - flag location
   - remediation idea

## Output

Return:
- technology identified
- endpoints/routes tested
- vulnerability hypotheses
- successful path if found
- created files
- flag status
SKILLWEB

  cat > "$root/crypto-ctf/SKILL.md" <<'SKILLCRYPTO'
---
name: crypto-ctf
description: Authorised HTB/CTF crypto workflow. Use for encodings, XOR, classical ciphers, RSA issues, AES mode misuse, weak randomness, hashes, signatures, JWT crypto, and custom crypto.
---

# Crypto CTF Skill

Use only for authorised HTB/CTF/lab crypto challenges.

## Goals

1. Identify whether the challenge is encoding, classical crypto, modern crypto misuse, hash/signature issue, or custom crypto.
2. Test hypotheses with small repeatable scripts.
3. Prefer evidence over guessing.
4. Save final solve script and writeup.

## Initial inspection

Record:
- ciphertext
- plaintext examples
- source code
- parameters
- public keys
- modulus/exponent
- IV/nonce
- mode
- hashes
- signatures
- remote oracle behaviour, if present in challenge scope

## Common checks

Consider:
- hex/base64/base32/base85/binary/URL encoding
- magic bytes
- XOR
- repeating-key XOR
- known plaintext
- Caesar/Vigenere/affine where plausible
- frequency analysis
- weak PRNG
- predictable seed
- RSA small exponent
- RSA shared modulus
- RSA common factor
- leaked p/q/d
- incorrect padding
- AES ECB
- CBC bit flipping in CTF contexts
- nonce/IV reuse
- hash length extension
- JWT weak HMAC secret or alg confusion in CTF contexts
- custom implementation logic errors

## Tools and libraries

Use:
- Python standard library
- base64
- binascii
- codecs
- collections
- itertools
- math
- sympy
- z3
- Crypto from pycryptodome

## Script preferences

Create:
- scripts/analyse.py
- scripts/solve.py

Scripts should:
- print intermediate values
- document assumptions
- be repeatable

## Required completion behaviour

When a flag is found:
1. Save it to loot/flag.txt.
2. Save scripts/solve.py.
3. Create/update writeup.md with:
   - crypto class
   - observed weakness
   - important parameters
   - solving method
   - final script
   - remediation/learning point

## Output

Return:
- likely crypto class
- evidence
- tests performed
- scripts created
- result
- flag status
SKILLCRYPTO

  cat > "$root/reverse-ctf/SKILL.md" <<'SKILLREVERSE'
---
name: reverse-ctf
description: Authorised HTB/CTF reverse-engineering workflow. Use for binaries, packed files, strings, ELF/PE metadata, static analysis, dynamic analysis, XOR routines, and flag check logic.
---

# Reverse Engineering CTF Skill

Use only for authorised HTB/CTF/lab reversing challenges.

## Goals

1. Identify binary type, architecture, protections, and likely flag path.
2. Prefer static analysis first.
3. Build helper scripts for decoding/emulation.
4. Save writeup when solved.

## Static analysis

Use:
- file
- sha256sum
- strings
- readelf
- objdump
- checksec
- r2
- ldd where appropriate
- xxd/hexdump

## Dynamic analysis

- Use the isolated challenge directory.
- Use timeout where appropriate.
- Use strace/ltrace/gdb when useful.
- Document behaviour clearly in notes.md.

## Common reverse paths

Consider:
- hardcoded flag fragments
- string obfuscation
- XOR loops
- simple encryption
- input comparison
- checksum validation
- packed binary indicators
- UPX
- anti-debugging
- Python/Java/.NET packaging
- bytecode/decompilation
- config/resources embedded in binary

## Script preferences

Create:
- scripts/decode.py
- scripts/emulate_check.py
- scripts/solve.py

## Required completion behaviour

When a flag is found:
1. Save it to loot/flag.txt.
2. Save helper scripts.
3. Create/update writeup.md with:
   - binary summary
   - important strings/functions
   - reverse method
   - decode/deobfuscation logic
   - final flag path
   - remediation/learning point, if relevant

## Output

Return:
- binary summary
- protections
- interesting strings/functions
- solve path
- scripts created
- flag status
SKILLREVERSE

  cat > "$root/pwn-ctf/SKILL.md" <<'SKILLPWN'
---
name: pwn-ctf
description: Authorised HTB/CTF pwn challenge workflow. Use for local binaries, remote services, pwntools scripts, protections, crashes, format strings, ret2win, ROP, ret2libc, and exploit development.
---

# Pwn CTF Skill

Use only for authorised HTB/CTF/lab pwn challenges.

## Goals

1. Identify binary protections and target behaviour.
2. Reproduce locally where possible.
3. Build repeatable pwntools scripts.
4. Save final exploit script, flag, and writeup.

## Initial checks

Use:
- file
- sha256sum
- checksec
- strings
- readelf
- objdump
- ldd
- gdb
- cyclic patterns where appropriate

## Challenge-scope interaction

- Keep remote interaction targeted to the supplied challenge host/port.
- Prefer local testing before remote interaction where possible.
- Use event-appropriate pacing and record remote interactions.

## Common pwn paths

Consider:
- ret2win
- buffer overflow
- format string
- integer overflow
- off-by-one
- stack canary
- NX
- PIE
- RELRO
- GOT/PLT
- ROP
- ret2libc
- heap misuse
- shellcode where challenge design supports it

## Script preferences

Create:
- scripts/exploit.py
- scripts/local_test.py

Use:
- pwntools
- struct
- subprocess
- pwn cyclic utilities

## Required completion behaviour

When a flag is found:
1. Save it to loot/flag.txt.
2. Save scripts/exploit.py.
3. Create/update writeup.md with:
   - binary protections
   - vulnerability
   - exploit concept
   - final script
   - flag retrieval method
   - remediation/learning point

## Output

Return:
- protection summary
- vulnerability hypothesis
- local/remote behaviour
- exploit route
- scripts created
- flag status
SKILLPWN

  cat > "$root/forensics-ctf/SKILL.md" <<'SKILLFORENSICS'
---
name: forensics-ctf
description: Authorised HTB/CTF forensics workflow. Use for images, archives, logs, PCAPs, metadata, stego, file carving, memory artefacts, and suspicious blobs.
---

# Forensics CTF Skill

Use only for authorised HTB/CTF/lab forensics challenges.

## Goals

1. Preserve original files.
2. Identify file types and hidden content.
3. Extract evidence into loot/.
4. Build small scripts for parsing where useful.
5. Save final flag and writeup.

## Inspection

Use:
- file
- sha256sum
- exiftool
- strings
- xxd
- binwalk
- 7z l
- unzip -l
- foremost
- zbarimg
- tshark where available
- sqlite3 where relevant

## Common checks

Consider:
- metadata
- hidden archive
- appended data
- embedded files
- alternate encodings
- QR/barcode
- steganography indicators
- corrupted magic bytes
- PCAP conversations
- DNS/HTTP extraction
- challenge-contained credentials/tokens
- log timelines
- browser/history artefacts
- SQLite databases
- memory dump strings and processes

## File handling

- Preserve originals in files/.
- Extract into loot/ or tmp/.
- Document extraction commands.

## Required completion behaviour

When a flag is found:
1. Save it to loot/flag.txt.
2. Save extracted evidence under loot/.
3. Create/update writeup.md with:
   - artefact summary
   - tools used
   - extraction path
   - flag evidence
   - remediation/learning point, if relevant

## Output

Return:
- artefact summary
- evidence found
- extraction steps
- files created
- flag status
SKILLFORENSICS

  cat > "$root/misc-ctf/SKILL.md" <<'SKILLMISC'
---
name: misc-ctf
description: Authorised HTB/CTF misc workflow. Use for scripting, encoding puzzles, containers, restricted shells, interactive services, protocol puzzles, and challenges that do not cleanly fit another category.
---

# Misc CTF Skill

Use only for authorised HTB/CTF/lab misc challenges.

## Goals

1. Identify the actual challenge mechanism.
2. Keep interaction controlled and scoped.
3. Build repeatable scripts for interactive services.
4. Save flag and writeup.

## Common misc types

Consider:
- raw TCP menu service
- restricted shell
- custom protocol
- encoding puzzle
- game/puzzle logic
- container escape simulation inside CTF scope
- sandboxed command interface
- file read objective
- automation challenge
- rate-limited guessing puzzle
- browser-only interaction
- WebSocket service

## Initial checks

Use:
- nc
- curl
- Python socket
- websocat if available
- file/strings for provided artefacts
- conservative manual interaction where useful

## Interaction

- Keep service interaction inside the supplied target scope.
- Save transcripts to loot/transcript.txt where useful.
- Build scripts under scripts/.

## Script preferences

Create:
- scripts/interact.py
- scripts/solve.py

## Required completion behaviour

When a flag is found:
1. Save it to loot/flag.txt.
2. Save final transcript or script.
3. Create/update writeup.md with:
   - protocol/interface summary
   - key observations
   - solve path
   - final interaction/script
   - remediation/learning point, if relevant

## Output

Return:
- likely challenge type
- service behaviour
- tested inputs
- scripts created
- flag status
SKILLMISC

  cat > "$root/osint-ctf/SKILL.md" <<'SKILLOSINT'
---
name: osint-ctf
description: Authorised HTB/CTF OSINT workflow. Use for public clues, images, metadata, usernames, geolocation hints, timestamps, and challenge-contained research.
---

# OSINT CTF Skill

Use only for authorised HTB/CTF/lab OSINT challenges.

## Goals

1. Work only from challenge-provided clues and public information.
2. Preserve evidence.
3. Save flag and writeup.

## Checks

Consider:
- image metadata
- visible landmarks
- usernames/handles in challenge context
- timestamps
- file names
- public pages explicitly part of the challenge
- archived pages when clearly relevant
- map clues
- social media clues only when challenge-provided and public

## Scope

- Keep evidence relevant to the challenge.
- Do not interact with individuals.
- Keep all notes and findings inside the challenge workspace.

## Required completion behaviour

When a flag is found:
1. Save it to loot/flag.txt.
2. Save evidence links or notes in notes.md.
3. Create/update writeup.md with:
   - clue chain
   - evidence
   - conclusion
   - flag location
   - boundaries observed

## Output

Return:
- clue summary
- evidence chain
- conclusion
- flag status
SKILLOSINT

  cat > "$root/ai-jailbreak-ctf/SKILL.md" <<'SKILLAIJAILBREAK'
---
name: ai-jailbreak-ctf
description: Authorised HTB/CTF AI or prompt-jailbreak workflow. Use for challenge-contained chatbots, prompt injection, guardrail puzzles, simulated devices, or LLM-based CTF services.
---

# AI Jailbreak CTF Skill

Use only for authorised HTB/CTF/lab AI or prompt-jailbreak challenges.

## Goals

1. Understand the model/app behaviour.
2. Identify constraints and allowed actions inside the challenge.
3. Use challenge-contained prompt strategies to solve the puzzle.
4. Save flag and writeup.

## Common challenge patterns

Consider:
- simulated assistant refuses to reveal flag
- hidden system prompt
- indirect prompt injection
- tool-use confusion
- role/context reset
- debug/diagnostic mode
- fictional device admin mode
- output transformation
- policy contradiction inside challenge
- multi-step state changes
- asking for verification, checksum, or encoded output
- reading a file only inside the CTF sandbox

## Methodology

1. Record the prompt/interface behaviour.
2. Try capability questions.
3. Identify refusal patterns.
4. Try indirect, diagnostic, or transformation-based requests relevant to the fiction of the challenge.
5. Keep a transcript in loot/transcript.txt where useful.
6. If a flag is revealed, save to loot/flag.txt.

## Required completion behaviour

When a flag is found:
1. Save it to loot/flag.txt.
2. Save the final prompt/transcript.
3. Create/update writeup.md with:
   - interface summary
   - constraints observed
   - prompt strategy
   - successful final prompt
   - flag location
   - learning point

## Output

Return:
- behaviour summary
- constraints
- prompt strategy
- transcript location
- flag status
SKILLAIJAILBREAK
}

create_skill_files "$CODEX_SKILLS_ROOT"
create_skill_files "$CLAUDE_SKILLS_ROOT"

echo "[+] Syncing skills to user-level agent locations"

for skill in "${SKILL_NAMES[@]}"; do
  rm -rf "$HOME/.agents/skills/$skill" "$HOME/.claude/skills/$skill"
done

cp -r "$CODEX_SKILLS_ROOT"/* "$HOME/.agents/skills/"
cp -r "$CLAUDE_SKILLS_ROOT"/* "$HOME/.claude/skills/"

echo "[+] Creating helper: sync-ctf-skills"

cat > "$LOCAL_BIN/sync-ctf-skills" <<'SYNCSKILLS'
#!/usr/bin/env bash
set -Eeuo pipefail

CTF_ROOT="${CTF_ROOT:-$HOME/ctf-event}"

mkdir -p "$HOME/.agents/skills"
mkdir -p "$HOME/.claude/skills"

if [ -d "$CTF_ROOT/.agents/skills" ]; then
  cp -r "$CTF_ROOT/.agents/skills/"* "$HOME/.agents/skills/"
fi

if [ -d "$CTF_ROOT/.claude/skills" ]; then
  cp -r "$CTF_ROOT/.claude/skills/"* "$HOME/.claude/skills/"
fi

echo "[+] Synced skills from $CTF_ROOT to user-level agent skill directories."
echo "[+] Codex skills:"
find "$HOME/.agents/skills" -maxdepth 2 -name SKILL.md -print | sort
echo "[+] Claude skills:"
find "$HOME/.claude/skills" -maxdepth 2 -name SKILL.md -print | sort
SYNCSKILLS

chmod +x "$LOCAL_BIN/sync-ctf-skills"

echo "[+] Creating helper: ctf-intake"

cat > "$LOCAL_BIN/ctf-intake" <<'CTFINTAKE'
#!/usr/bin/env bash
set -Eeuo pipefail

CTF_ROOT="${CTF_ROOT:-$HOME/ctf-event}"

CATEGORY=""
DIFFICULTY=""
NAME=""
TARGET=""
HINTS=""
DESCRIPTION=""
AUTO_OPEN="false"
URLS=()

usage() {
  cat <<'EOF'
Usage:
  ctf-intake --category <category> --name <name> [options] <<'EOF'
  challenge description
  EOF

Options:
  -c, --category       Challenge category, e.g. web, misc, crypto, pwn
  -n, --name           Challenge name
  --difficulty         Difficulty, e.g. easy, medium, hard, insane
  -t, --target         Target URL, IP:port, host:port, or blank for file-only challenges
  -u, --url            Scenario/download file URL. Can be used multiple times.
  -d, --description    Challenge description as a single argument
  --hints              Challenge hints
  --auto-open          Open a shell in the created challenge directory
  -h, --help           Show this help

Examples:
  ctf-intake --category web --difficulty easy --name Jailbreak --target 1.2.3.4:12345 <<'EOF'
  Paste challenge description here.
  EOF

  ctf-intake --category misc --name TunnelMadness --target 1.2.3.4:31337 --url 'https://example/download' <<'EOF'
  Paste challenge description here.
  EOF
EOF
}

slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

yaml_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

safe_filename_from_url() {
  local url="$1"
  local fallback="$2"
  local base

  base="$(printf '%s' "$url" | sed 's/[?#].*$//' | awk -F/ '{print $NF}')"

  if [ -z "$base" ] || [ "$base" = "download" ]; then
    base="$fallback"
  fi

  printf '%s' "$base" | sed -E 's/[^A-Za-z0-9._-]+/_/g'
}

identify_and_extract() {
  local file_path="$1"
  local mime=""
  local extract_dir

  extract_dir="files/extracted/$(basename "$file_path" | sed -E 's/[^A-Za-z0-9._-]+/_/g')"
  mkdir -p "$extract_dir"

  echo "[+] Identifying: $file_path"

  if command -v file >/dev/null 2>&1; then
    file "$file_path" | tee -a files/file-types.txt
    mime="$(file -b --mime-type "$file_path" || true)"
  fi

  case "$mime:$file_path" in
    application/zip:*|*:*.zip)
      echo "[+] Extracting zip to $extract_dir"
      unzip -o "$file_path" -d "$extract_dir" >/dev/null 2>&1 || 7z x -y "$file_path" -o"$extract_dir" >/dev/null 2>&1 || true
      ;;
    application/x-7z-compressed:*|*:*.7z)
      echo "[+] Extracting 7z to $extract_dir"
      7z x -y "$file_path" -o"$extract_dir" >/dev/null 2>&1 || true
      ;;
    application/gzip:*|application/x-gzip:*|application/x-xz:*|application/x-tar:*|*:*.tar|*:*.tar.gz|*:*.tgz|*:*.tar.xz)
      echo "[+] Attempting tar extraction to $extract_dir"
      tar -xf "$file_path" -C "$extract_dir" >/dev/null 2>&1 || true
      ;;
    *)
      echo "[+] No archive extraction rule matched."
      ;;
  esac
}

download_file() {
  local url="$1"
  local index="$2"
  local fallback="scenario_${index}"
  local filename
  local output

  filename="$(safe_filename_from_url "$url" "$fallback")"
  output="files/$filename"

  echo "[+] Downloading file $index"
  echo "    URL: $url"
  echo "    Out: $output"

  if command -v curl >/dev/null 2>&1; then
    curl -L --fail --retry 2 --connect-timeout 10 -o "$output" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$output" "$url"
  else
    echo "[!] Neither curl nor wget is available. Cannot download: $url"
    return 1
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$output" >> files/SHA256SUMS
  fi

  identify_and_extract "$output"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -c|--category)
      CATEGORY="${2:-}"
      shift 2
      ;;
    -n|--name)
      NAME="${2:-}"
      shift 2
      ;;
    --difficulty)
      DIFFICULTY="${2:-}"
      shift 2
      ;;
    -t|--target)
      TARGET="${2:-}"
      shift 2
      ;;
    -u|--url|--file-url)
      URLS+=("${2:-}")
      shift 2
      ;;
    -d|--description)
      DESCRIPTION="${2:-}"
      shift 2
      ;;
    --hints)
      HINTS="${2:-}"
      shift 2
      ;;
    --auto-open)
      AUTO_OPEN="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[!] Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [ -z "$DESCRIPTION" ] && [ ! -t 0 ]; then
  DESCRIPTION="$(cat)"
fi

if [ -z "$CATEGORY" ]; then
  read -r -p "Category: " CATEGORY
fi

if [ -z "$NAME" ]; then
  read -r -p "Challenge name: " NAME
fi

if [ -z "$DIFFICULTY" ]; then
  read -r -p "Difficulty, or blank: " DIFFICULTY || true
fi

if [ -z "$TARGET" ]; then
  read -r -p "Target, URL, IP:port, or blank: " TARGET || true
fi

if [ -z "$DESCRIPTION" ]; then
  echo "[+] Paste challenge description. Finish with Ctrl+D:"
  DESCRIPTION="$(cat || true)"
fi

CATEGORY_SLUG="$(slugify "$CATEGORY")"
NAME_SLUG="$(slugify "$NAME")"

if [ -z "$CATEGORY_SLUG" ] || [ -z "$NAME_SLUG" ]; then
  echo "[!] Category and name must not be empty."
  exit 1
fi

CHAL_DIR="$CTF_ROOT/challenges/$CATEGORY_SLUG/$NAME_SLUG"
CREATED_AT="$(date -Iseconds 2>/dev/null || date)"

echo "[+] Creating challenge workspace"
echo "    $CHAL_DIR"

mkdir -p "$CHAL_DIR"/{files,files/extracted,scripts,loot,scans,tmp,prompts,agent_runs/{codex,claude,gemini,agy}}
cd "$CHAL_DIR"

cat > challenge.yaml <<EOF
name: "$(yaml_escape "$NAME")"
slug: "$(yaml_escape "$NAME_SLUG")"
category: "$(yaml_escape "$CATEGORY")"
category_slug: "$(yaml_escape "$CATEGORY_SLUG")"
difficulty: "$(yaml_escape "$DIFFICULTY")"
target: "$(yaml_escape "$TARGET")"
created_at: "$(yaml_escape "$CREATED_AT")"
status: "created"
assigned_agent: ""
flag_file: "loot/flag.txt"
writeup_file: "writeup.md"
file_urls:
EOF

if [ "${#URLS[@]}" -gt 0 ]; then
  for url in "${URLS[@]}"; do
    printf '  - "%s"\n' "$(yaml_escape "$url")" >> challenge.yaml
  done
else
  echo "  []" >> challenge.yaml
fi

cat > original_prompt.md <<EOF
# Original HTB Challenge Information

## Name

$NAME

## Category

$CATEGORY

## Difficulty

${DIFFICULTY:-Not supplied}

## Target

${TARGET:-Not supplied}

## File URLs

EOF

if [ "${#URLS[@]}" -gt 0 ]; then
  for url in "${URLS[@]}"; do
    printf -- "- %s\n" "$url" >> original_prompt.md
  done
else
  echo "No file URLs supplied." >> original_prompt.md
fi

cat >> original_prompt.md <<EOF

## Hints

${HINTS:-No hints supplied.}

## Description

$DESCRIPTION
EOF

cat > notes.md <<EOF
# $NAME

## Category

$CATEGORY

## Difficulty

${DIFFICULTY:-Not supplied}

## Description

$DESCRIPTION

## Scope / Targets

${TARGET:-Not supplied}

## Files

EOF

if [ "${#URLS[@]}" -gt 0 ]; then
  for url in "${URLS[@]}"; do
    printf -- "- %s\n" "$url" >> notes.md
  done
else
  echo "No file URLs recorded." >> notes.md
fi

cat >> notes.md <<EOF

## Hints

${HINTS:-No hints recorded.}

## Scope Rules

- This is authorised Hack The Box / CTF work.
- Work only inside the current challenge workspace.
- Only operate against the explicitly provided challenge scope, including the supplied target, files, URLs, ports, and challenge artefacts.
- Use challenge-relevant techniques where appropriate to the provided HTB/CTF scenario and consistent with the event rules.
- Keep notes, scripts, artefacts, flags, and writeups inside this challenge folder.
- Do not submit the flag automatically unless explicitly asked.

## Commands Run

None yet.

## Observations

- Challenge workspace created by ctf-intake.
- Target: ${TARGET:-Not supplied}
- Category: $CATEGORY
- Difficulty: ${DIFFICULTY:-Not supplied}

## Hypotheses

- Pending agent triage.

## Scripts

- Pending.

## Flag / Final Answer

Not found yet.
EOF

cat > writeup.md <<EOF
# Challenge Writeup: $NAME

## Summary

Pending.

## Initial Observations

Pending.

## Methodology

Pending.

## Key Findings

Pending.

## Exploitation / Solve Path

Pending.

## Flag Location

Pending.

## Agent Notes

Pending.

## Remediation / Learning Point

Pending.
EOF

cat > AGENTS.md <<EOF
# Challenge Instructions for Codex

This folder is for one authorised HTB/CTF/lab challenge.

Challenge:
- Name: $NAME
- Category: $CATEGORY
- Difficulty: ${DIFFICULTY:-Not supplied}
- Target: ${TARGET:-Not supplied}

Scope:
- Work only inside this challenge directory.
- Only operate against the explicitly provided challenge scope, including supplied targets, files, URLs, ports, and challenge artefacts.
- Follow the challenge and event rules.
- Keep enumeration and interaction relevant to the challenge objective.
- Prefer repeatable scripts over manual one-off actions.
- Do not submit the flag automatically unless explicitly asked.

Required workflow:
1. Read challenge.yaml, original_prompt.md if present, notes.md, and AGENTS.md.
2. Identify the challenge type.
3. Use the relevant CTF skill.
4. Update notes.md throughout.
5. Save scripts under scripts/.
6. Save artefacts under loot/ or scans/.
7. If the flag is found, save it to loot/flag.txt.
8. At completion, create/update writeup.md with a high-level explanation of how the agent solved the challenge.

Required writeup sections:
- Summary
- Initial Observations
- Methodology
- Key Findings
- Exploitation / Solve Path
- Flag Location
- Agent Notes
- Remediation / Learning Point
EOF

cat > CLAUDE.md <<EOF
# Challenge Instructions for Claude Code

This folder is for one authorised HTB/CTF/lab challenge.

Challenge:
- Name: $NAME
- Category: $CATEGORY
- Difficulty: ${DIFFICULTY:-Not supplied}
- Target: ${TARGET:-Not supplied}

Scope:
- Work only inside this challenge directory.
- Only operate against the explicitly provided challenge scope, including supplied targets, files, URLs, ports, and challenge artefacts.
- Follow the challenge and event rules.
- Keep enumeration and interaction relevant to the challenge objective.
- Prefer repeatable scripts over manual one-off actions.
- Do not submit the flag automatically unless explicitly asked.

Required workflow:
1. Read challenge.yaml, original_prompt.md if present, notes.md, and CLAUDE.md.
2. Identify the challenge type.
3. Use the relevant CTF skill.
4. Update notes.md throughout.
5. Save scripts under scripts/.
6. Save artefacts under loot/ or scans/.
7. If the flag is found, save it to loot/flag.txt.
8. At completion, create/update writeup.md with a high-level explanation of how the agent solved the challenge.
EOF

cat > GEMINI.md <<EOF
# Challenge Instructions for Gemini / Antigravity

This folder is for one authorised HTB/CTF/lab challenge.

Challenge:
- Name: $NAME
- Category: $CATEGORY
- Difficulty: ${DIFFICULTY:-Not supplied}
- Target: ${TARGET:-Not supplied}

Scope:
- Work only inside this challenge directory.
- Only operate against the explicitly provided challenge scope, including supplied targets, files, URLs, ports, and challenge artefacts.
- Follow the challenge and event rules.
- Keep actions evidence-based and relevant to the challenge objective.
- Save flag to loot/flag.txt if found.
- Create/update writeup.md when solved.
- Do not submit the flag automatically unless explicitly asked.
EOF

cat > prompts/codex_auto.txt <<EOF
Use the ctf-triage skill and any relevant specialist CTF skill.

This is authorised Hack The Box / CTF work.

Challenge:
- Name: $NAME
- Category: $CATEGORY
- Difficulty: ${DIFFICULTY:-Not supplied}
- Target: ${TARGET:-Not supplied}
- Files: ./files/

Work only inside the current challenge workspace.

Only operate against the explicitly provided challenge scope, including the supplied target, files, URLs, ports, and challenge artefacts.

Use any challenge-relevant technique where it is appropriate to the provided HTB/CTF scenario and consistent with the event rules.

Read challenge.yaml, original_prompt.md if present, notes.md, and AGENTS.md.

Inspect files under ./files/.

Carry out the analysis and attempt to locate the flag.

Update notes.md throughout.

Save scripts under scripts/.

Save artefacts under loot/ or scans/.

If the flag is found, save it to loot/flag.txt.

Create or update writeup.md with:
- Summary
- Initial Observations
- Methodology
- Key Findings
- Exploitation / Solve Path
- Flag Location
- Agent Notes
- Remediation / Learning Point

Do not submit the flag automatically unless I explicitly ask.
EOF

cat > prompts/codex_interactive.txt <<EOF
Use the ctf-triage skill and any relevant specialist CTF skill.

This is authorised Hack The Box / CTF work.

Read challenge.yaml, original_prompt.md if present, notes.md, and AGENTS.md.

Inspect files under ./files/.

Work only inside the current challenge workspace and only against the explicitly provided challenge scope.

Analyse the challenge, update notes.md throughout, save scripts under scripts/, save artefacts under loot/ or scans/, save the flag to loot/flag.txt if found, and create or update writeup.md.

Do not submit the flag automatically unless I explicitly ask.
EOF

cat > prompts/claude_solve.txt <<EOF
/ctf-triage

This is authorised Hack The Box / CTF work.

Challenge:
- Name: $NAME
- Category: $CATEGORY
- Difficulty: ${DIFFICULTY:-Not supplied}
- Target: ${TARGET:-Not supplied}
- Files: ./files/

Work only inside the current challenge workspace.

Only operate against the explicitly provided challenge scope, including the supplied target, files, URLs, ports, and challenge artefacts.

Use any challenge-relevant technique where it is appropriate to the provided HTB/CTF scenario and consistent with the event rules.

Read challenge.yaml, original_prompt.md if present, notes.md, and CLAUDE.md.

Inspect files under ./files/.

Use the relevant specialist CTF skill after triage.

Attempt to solve the challenge.

Update notes.md throughout.

Save scripts under scripts/.

Save artefacts under loot/ or scans/.

If the flag is found, save it to loot/flag.txt.

Create or update writeup.md with:
- Summary
- Initial Observations
- Methodology
- Key Findings
- Exploitation / Solve Path
- Flag Location
- Agent Notes
- Remediation / Learning Point

Do not submit the flag automatically unless I explicitly ask.
EOF

cat > prompts/gemini_solve.txt <<EOF
Use GEMINI.md as project context.

This is authorised Hack The Box / CTF work.

Challenge:
- Name: $NAME
- Category: $CATEGORY
- Difficulty: ${DIFFICULTY:-Not supplied}
- Target: ${TARGET:-Not supplied}
- Files: ./files/

Work only inside the current challenge workspace.

Only operate against the explicitly provided challenge scope, including the supplied target, files, URLs, ports, and challenge artefacts.

Use any challenge-relevant technique where it is appropriate to the provided HTB/CTF scenario and consistent with the event rules.

Read challenge.yaml, original_prompt.md if present, and notes.md.

Inspect files under ./files/.

Analyse the challenge and attempt to locate the flag.

Update notes.md throughout.

Save scripts under scripts/.

Save artefacts under loot/ or scans/.

If the flag is found, save it to loot/flag.txt.

Create or update writeup.md with:
- Summary
- Initial Observations
- Methodology
- Key Findings
- Exploitation / Solve Path
- Flag Location
- Agent Notes
- Remediation / Learning Point

Do not submit the flag automatically unless I explicitly ask.
EOF

cat > prompts/gemini_review.txt <<EOF
Use GEMINI.md as project context.

This is authorised Hack The Box / CTF work.

Review the current state of this challenge.

Read:
- challenge.yaml
- original_prompt.md if present
- notes.md
- writeup.md
- scripts/
- loot/
- scans/
- agent_runs/

Summarise:
1. what has been tried
2. what evidence exists
3. what assumptions may be wrong
4. what useful scripts or artefacts already exist
5. the best next path

Work only inside the current challenge workspace.

Only operate against the explicitly provided HTB/CTF challenge scope and follow the challenge/event rules.

If the flag is found, save it to loot/flag.txt and create or update writeup.md.

Do not submit the flag automatically unless I explicitly ask.
EOF

cat > prompts/retry_fresh.txt <<EOF
This is a fresh retry by a different agent.

This is authorised Hack The Box / CTF work.

Treat previous agent conclusions as untrusted unless directly supported by evidence.

Start from:
- challenge.yaml
- original_prompt.md if present
- notes.md
- files/
- provided target and URLs

Identify the challenge type independently.

You may review prior notes, but verify important claims yourself.

Work only inside the current challenge workspace.

Only operate against the explicitly provided HTB/CTF challenge scope and follow the challenge/event rules.

Save your own run summary under agent_runs/<agent>/<timestamp>/summary.md.

If the flag is found, save it to loot/flag.txt and create or update writeup.md.

Do not submit the flag automatically unless I explicitly ask.
EOF

cat > prompts/retry_handoff.txt <<EOF
This is a handoff retry by a different agent.

This is authorised Hack The Box / CTF work.

Review:
- challenge.yaml
- original_prompt.md if present
- notes.md
- writeup.md
- scripts/
- loot/
- scans/
- agent_runs/

Summarise:
1. what has been tried
2. what evidence exists
3. what assumptions may be wrong
4. what useful scripts or artefacts already exist
5. the best next path

Then continue solving the challenge.

Work only inside the current challenge workspace.

Only operate against the explicitly provided HTB/CTF challenge scope and follow the challenge/event rules.

Save your own run summary under agent_runs/<agent>/<timestamp>/summary.md.

If the flag is found, save it to loot/flag.txt and create or update writeup.md.

Do not submit the flag automatically unless I explicitly ask.
EOF

cp prompts/codex_auto.txt run_codex_auto_prompt.txt

if [ "${#URLS[@]}" -gt 0 ]; then
  : > files/SHA256SUMS
  : > files/file-types.txt

  index=1
  for url in "${URLS[@]}"; do
    download_file "$url" "$index" || true
    index=$((index + 1))
  done
fi

echo "[+] Final file inventory"
find . -maxdepth 3 -type f | sort > loot/initial_file_inventory.txt

echo "[+] Created challenge workspace:"
echo "    $CHAL_DIR"
echo
echo "[+] Next commands:"
echo "    cd \"$CHAL_DIR\""
echo "    ctf-start codex"
echo "    ctf-start codex-auto"
echo "    ctf-start claude"
echo "    ctf-start gemini"
echo "    ctf-start gemini-review"
echo
echo "[+] Completion check:"
echo "    ctf-finish"

if [ "$AUTO_OPEN" = "true" ]; then
  cd "$CHAL_DIR"
  exec "$SHELL"
fi
CTFINTAKE

chmod +x "$LOCAL_BIN/ctf-intake"

echo "[+] Creating compatibility helper: new-ctf-challenge"

cat > "$LOCAL_BIN/new-ctf-challenge" <<'NEWCHALLENGE'
#!/usr/bin/env bash
set -Eeuo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: new-ctf-challenge <category> <challenge-name> [target]"
  echo "Example: new-ctf-challenge web jailbreak 154.57.164.79:31790"
  exit 1
fi

CATEGORY="$1"
NAME="$2"
TARGET="${3:-}"

exec "$HOME/.local/bin/ctf-intake" --category "$CATEGORY" --name "$NAME" ${TARGET:+--target "$TARGET"} <<'EOF'
Paste challenge description here.
EOF
NEWCHALLENGE

chmod +x "$LOCAL_BIN/new-ctf-challenge"

echo "[+] Creating helper: ctf-start"

cat > "$LOCAL_BIN/ctf-start" <<'CTFSTART'
#!/usr/bin/env bash
set -Eeuo pipefail

CTF_ROOT="${CTF_ROOT:-$HOME/ctf-event}"

usage() {
  cat <<'EOF'
Usage:
  ctf-start <mode> [challenge-ref]

Modes:
  codex
  codex-auto
  codex-exec
  claude
  gemini
  gemini-review
  agy
  agy-review
  codex-retry-fresh
  codex-retry-handoff
  claude-retry-fresh
  claude-retry-handoff
  gemini-retry-fresh
  gemini-retry-handoff
  agy-retry-fresh
  agy-retry-handoff

Examples:
  ctf-start codex
  ctf-start codex-auto web/jailbreak
  ctf-start claude pwn/hard-binary
  ctf-start gemini-review misc/tunnelmadness
EOF
}

resolve_challenge_dir() {
  local ref="${1:-}"

  if [ -z "$ref" ]; then
    if [ -f "challenge.yaml" ]; then
      pwd
      return 0
    fi
    echo "[!] No challenge-ref supplied and current directory has no challenge.yaml." >&2
    return 1
  fi

  if [ -d "$ref" ]; then
    (cd "$ref" && pwd)
    return 0
  fi

  if [ -d "$CTF_ROOT/challenges/$ref" ]; then
    (cd "$CTF_ROOT/challenges/$ref" && pwd)
    return 0
  fi

  echo "[!] Could not resolve challenge directory: $ref" >&2
  return 1
}

mode="${1:-}"
ref="${2:-}"

if [ -z "$mode" ] || [ "$mode" = "-h" ] || [ "$mode" = "--help" ]; then
  usage
  exit 0
fi

CHAL_DIR="$(resolve_challenge_dir "$ref")"
cd "$CHAL_DIR"

if [ ! -f "challenge.yaml" ]; then
  echo "[!] challenge.yaml missing in $CHAL_DIR"
  exit 1
fi

timestamp="$(date +%Y%m%d-%H%M%S)"

agent=""
prompt_file=""
launch_mode="interactive"

case "$mode" in
  codex)
    agent="codex"
    prompt_file="prompts/codex_interactive.txt"
    ;;
  codex-auto)
    agent="codex"
    prompt_file="prompts/codex_auto.txt"
    launch_mode="codex-auto"
    ;;
  codex-exec)
    agent="codex"
    prompt_file="prompts/codex_auto.txt"
    launch_mode="codex-exec"
    ;;
  claude)
    agent="claude"
    prompt_file="prompts/claude_solve.txt"
    ;;
  gemini)
    agent="gemini"
    prompt_file="prompts/gemini_solve.txt"
    ;;
  gemini-review)
    agent="gemini"
    prompt_file="prompts/gemini_review.txt"
    ;;
  agy)
    agent="agy"
    prompt_file="prompts/gemini_solve.txt"
    ;;
  agy-review)
    agent="agy"
    prompt_file="prompts/gemini_review.txt"
    ;;
  codex-retry-fresh)
    agent="codex"
    prompt_file="prompts/retry_fresh.txt"
    ;;
  codex-retry-handoff)
    agent="codex"
    prompt_file="prompts/retry_handoff.txt"
    ;;
  claude-retry-fresh)
    agent="claude"
    prompt_file="prompts/retry_fresh.txt"
    ;;
  claude-retry-handoff)
    agent="claude"
    prompt_file="prompts/retry_handoff.txt"
    ;;
  gemini-retry-fresh)
    agent="gemini"
    prompt_file="prompts/retry_fresh.txt"
    ;;
  gemini-retry-handoff)
    agent="gemini"
    prompt_file="prompts/retry_handoff.txt"
    ;;
  agy-retry-fresh)
    agent="agy"
    prompt_file="prompts/retry_fresh.txt"
    ;;
  agy-retry-handoff)
    agent="agy"
    prompt_file="prompts/retry_handoff.txt"
    ;;
  *)
    echo "[!] Unknown mode: $mode"
    usage
    exit 1
    ;;
esac

if [ ! -f "$prompt_file" ]; then
  echo "[!] Prompt file missing: $prompt_file"
  exit 1
fi

run_dir="agent_runs/$agent/$timestamp"
mkdir -p "$run_dir"
cp "$prompt_file" "$run_dir/prompt.txt"
echo "started" > "$run_dir/status.txt"

echo "[+] Challenge: $CHAL_DIR"
echo "[+] Agent: $agent"
echo "[+] Mode: $mode"
echo "[+] Run dir: $run_dir"
echo "[+] Prompt: $prompt_file"
echo

case "$agent" in
  codex)
    if [ "$launch_mode" = "codex-auto" ]; then
      echo "[+] Starting Codex autonomous mode."
      echo "[+] This uses danger-full-access and ask-for-approval=never inside this challenge workspace."
      codex --sandbox danger-full-access --ask-for-approval never "$(cat "$prompt_file")"
    elif [ "$launch_mode" = "codex-exec" ]; then
      echo "[+] Starting Codex non-interactive exec mode."
      codex exec --sandbox danger-full-access --ask-for-approval never "$(cat "$prompt_file")"
    else
      echo "[+] Starting Codex interactive mode."
      echo "[+] Paste this prompt into Codex if it is not loaded automatically:"
      echo
      cat "$prompt_file"
      echo
      codex
    fi
    ;;
  claude)
    echo "[+] Starting Claude Code."
    echo "[+] Paste this prompt into Claude:"
    echo
    cat "$prompt_file"
    echo
    claude
    ;;
  gemini)
    echo "[+] Starting Gemini."
    echo "[+] Paste this prompt into Gemini:"
    echo
    cat "$prompt_file"
    echo
    gemini
    ;;
  agy)
    echo "[+] Starting Antigravity."
    echo "[+] Paste this prompt into Antigravity:"
    echo
    cat "$prompt_file"
    echo
    agy
    ;;
esac
CTFSTART

chmod +x "$LOCAL_BIN/ctf-start"

echo "[+] Creating helper: ctf-codex-auto"

cat > "$LOCAL_BIN/ctf-codex-auto" <<'CODEXAUTO'
#!/usr/bin/env bash
set -Eeuo pipefail

if [ -f "prompts/codex_auto.txt" ]; then
  prompt_file="prompts/codex_auto.txt"
elif [ -f "run_codex_auto_prompt.txt" ]; then
  prompt_file="run_codex_auto_prompt.txt"
else
  echo "[!] No Codex auto prompt found."
  echo "[!] Run this from a challenge directory created with ctf-intake."
  exit 1
fi

echo "[+] Starting Codex autonomous CTF mode."
echo "[+] Current directory: $(pwd)"
echo "[+] Prompt: $prompt_file"
echo
echo "[+] This uses danger-full-access and ask-for-approval=never inside this challenge workspace."
echo

codex --sandbox danger-full-access --ask-for-approval never "$(cat "$prompt_file")"
CODEXAUTO

chmod +x "$LOCAL_BIN/ctf-codex-auto"

echo "[+] Creating helper: ctf-codex-auto-exec"

cat > "$LOCAL_BIN/ctf-codex-auto-exec" <<'CODEXAUTOEXEC'
#!/usr/bin/env bash
set -Eeuo pipefail

if [ -f "prompts/codex_auto.txt" ]; then
  prompt_file="prompts/codex_auto.txt"
elif [ -f "run_codex_auto_prompt.txt" ]; then
  prompt_file="run_codex_auto_prompt.txt"
else
  echo "[!] No Codex auto prompt found."
  echo "[!] Run this from a challenge directory created with ctf-intake."
  exit 1
fi

echo "[+] Starting Codex non-interactive autonomous CTF mode."
echo "[+] Current directory: $(pwd)"
echo "[+] Prompt: $prompt_file"
echo

codex exec \
  --sandbox danger-full-access \
  --ask-for-approval never \
  "$(cat "$prompt_file")"
CODEXAUTOEXEC

chmod +x "$LOCAL_BIN/ctf-codex-auto-exec"

echo "[+] Creating helper: ctf-board"

cat > "$LOCAL_BIN/ctf-board" <<'CTFBOARD'
#!/usr/bin/env bash
set -Eeuo pipefail

CTF_ROOT="${CTF_ROOT:-$HOME/ctf-event}"

yaml_val() {
  local key="$1"
  local file="$2"
  awk -v k="$key" '
    $0 ~ "^" k ":" {
      sub("^" k ":[[:space:]]*", "", $0)
      gsub(/^"/, "", $0)
      gsub(/"$/, "", $0)
      print $0
      exit
    }
  ' "$file"
}

printf "%-28s %-12s %-10s %-24s %-10s %-6s %-8s %s\n" "Challenge" "Category" "Difficulty" "Target" "Status" "Flag" "Writeup" "Path"
printf "%-28s %-12s %-10s %-24s %-10s %-6s %-8s %s\n" "---------" "--------" "----------" "------" "------" "----" "-------" "----"

find "$CTF_ROOT/challenges" -name challenge.yaml -type f 2>/dev/null | sort | while read -r yaml; do
  dir="$(dirname "$yaml")"
  name="$(yaml_val name "$yaml")"
  category="$(yaml_val category "$yaml")"
  difficulty="$(yaml_val difficulty "$yaml")"
  target="$(yaml_val target "$yaml")"
  status="$(yaml_val status "$yaml")"

  [ -n "$name" ] || name="$(basename "$dir")"
  [ -n "$category" ] || category="-"
  [ -n "$difficulty" ] || difficulty="-"
  [ -n "$target" ] || target="-"
  [ -n "$status" ] || status="-"

  if [ -s "$dir/loot/flag.txt" ]; then
    flag="yes"
  else
    flag="no"
  fi

  if [ -s "$dir/writeup.md" ] && ! grep -q "Pending" "$dir/writeup.md"; then
    writeup="done"
  elif [ -s "$dir/writeup.md" ]; then
    writeup="draft"
  else
    writeup="no"
  fi

  rel="${dir#$CTF_ROOT/challenges/}"
  printf "%-28.28s %-12.12s %-10.10s %-24.24s %-10.10s %-6s %-8s %s\n" "$name" "$category" "$difficulty" "$target" "$status" "$flag" "$writeup" "$rel"
done
CTFBOARD

chmod +x "$LOCAL_BIN/ctf-board"

echo "[+] Creating helper: ctf-finish"

cat > "$LOCAL_BIN/ctf-finish" <<'CTFFINISH'
#!/usr/bin/env bash
set -Eeuo pipefail

echo "[+] Checking challenge completion files in: $(pwd)"
echo

if [ ! -f "challenge.yaml" ]; then
  echo "[!] challenge.yaml missing. Run from a challenge directory."
  exit 1
fi

flag_ok="no"
writeup_ok="no"

if [ -s "loot/flag.txt" ]; then
  echo "[+] Flag file exists:"
  cat loot/flag.txt
  flag_ok="yes"
else
  echo "[!] Missing or empty loot/flag.txt"
fi

echo

if [ -s "writeup.md" ]; then
  if grep -q "Pending" writeup.md; then
    echo "[!] writeup.md exists but still contains Pending sections"
  else
    echo "[+] writeup.md exists and has no Pending markers"
    writeup_ok="yes"
  fi
  echo
  grep -E '^## ' writeup.md || true
else
  echo "[!] Missing writeup.md"
fi

echo

echo "[+] Scripts:"
find scripts -maxdepth 2 -type f -print 2>/dev/null | sort || true

echo

echo "[+] Files:"
find . -maxdepth 3 -type f | sort

echo

if [ "$flag_ok" = "yes" ] && [ "$writeup_ok" = "yes" ]; then
  echo "[+] Marking challenge.yaml status as solved"
  if grep -q '^status:' challenge.yaml; then
    sed -i 's/^status:.*/status: "solved"/' challenge.yaml
  else
    echo 'status: "solved"' >> challenge.yaml
  fi
else
  echo "[+] Not marking solved yet."
fi
CTFFINISH

chmod +x "$LOCAL_BIN/ctf-finish"

echo "[+] Creating compatibility helper: ctf-writeup-check"

cat > "$LOCAL_BIN/ctf-writeup-check" <<'WRITEUPCHECK'
#!/usr/bin/env bash
exec "$HOME/.local/bin/ctf-finish" "$@"
WRITEUPCHECK

chmod +x "$LOCAL_BIN/ctf-writeup-check"

echo "[+] Creating helper: ctf-status"

cat > "$LOCAL_BIN/ctf-status" <<'CTFSTATUS'
#!/usr/bin/env bash

echo "[+] User and host"
whoami
hostname
echo

echo "[+] Filesystem"
findmnt /
df -h / "$HOME" /tmp
echo

echo "[+] AI tools"
echo "codex:  $(command -v codex || echo not found)"
if command -v codex >/dev/null 2>&1; then codex --version || true; fi
echo

echo "claude: $(command -v claude || echo not found)"
if command -v claude >/dev/null 2>&1; then claude --version || true; fi
echo

echo "agy:    $(command -v agy || echo not found)"
if command -v agy >/dev/null 2>&1; then agy --version || true; fi
echo

echo "gemini: $(command -v gemini || echo not found)"
if command -v gemini >/dev/null 2>&1; then gemini --version || true; fi
echo

echo "[+] Core commands"
for cmd in python3 pipx node npm jq tmux git curl tree dos2unix xclip wl-copy; do
  echo "$cmd: $(command -v "$cmd" || echo not found)"
done
echo

echo "[+] Helpers"
for cmd in ctf-intake ctf-start ctf-board ctf-finish ctf-writeup-check ctf-codex-auto ctf-codex-auto-exec ctf-venv sync-ctf-skills; do
  echo "$cmd: $(command -v "$cmd" || echo not found)"
done
echo

echo "[+] Skills"
echo "Codex user skills:"
find "$HOME/.agents/skills" -maxdepth 2 -name SKILL.md -print 2>/dev/null | sort || true
echo
echo "Claude user skills:"
find "$HOME/.claude/skills" -maxdepth 2 -name SKILL.md -print 2>/dev/null | sort || true
echo

echo "[+] Workspace"
ls -la "$HOME/ctf-event" 2>/dev/null || echo "No ctf-event folder found"
echo

echo "[+] Challenge board"
if command -v ctf-board >/dev/null 2>&1; then
  ctf-board || true
fi
CTFSTATUS

chmod +x "$LOCAL_BIN/ctf-status"

echo "[+] Creating quickstart notes"

cat > "$CTF_ROOT/AI_CTF_QUICKSTART.md" <<'QUICKSTART'
# AI CTF Quickstart

## Initial setup

Run:

    source ~/.bashrc
    ctf-status

## Intake a challenge

Use ChatGPT Project to generate a prompt pack and ctf-intake command, then paste the generated command into Pwnbox.

Manual example:

    ctf-intake \
      --category web \
      --difficulty easy \
      --name Jailbreak \
      --target 154.57.164.79:31790 <<'EOF'
    Paste HTB challenge description here.
    EOF

Then:

    cd ~/ctf-event/challenges/web/jailbreak

## Challenge folder structure

Each challenge contains:

    challenge.yaml
    original_prompt.md
    notes.md
    AGENTS.md
    CLAUDE.md
    GEMINI.md
    writeup.md
    prompts/
    agent_runs/
    files/
    scripts/
    loot/
    scans/
    tmp/

## Start agents

Interactive Codex:

    ctf-start codex

Autonomous Codex:

    ctf-start codex-auto

Non-interactive Codex:

    ctf-start codex-exec

Claude Code:

    ctf-start claude

Gemini:

    ctf-start gemini

Gemini review:

    ctf-start gemini-review

Antigravity:

    ctf-start agy

## Retry with another agent

Fresh retry:

    ctf-start claude-retry-fresh
    ctf-start gemini-retry-fresh

Handoff retry:

    ctf-start claude-retry-handoff
    ctf-start gemini-retry-handoff

## Board

Show all challenge status:

    ctf-board

## Completion check

After the agent finishes:

    ctf-finish

Expected final files:

    notes.md
    writeup.md
    loot/flag.txt
    scripts/solve.py or equivalent, where practical

## Recommended workflow

1. Create the challenge folder with ctf-intake.
2. Use Codex for easy/medium or scripting-heavy challenges.
3. Use Claude for hard/very hard, reversing, pwn, and complex reasoning.
4. Use Gemini for review, alternative hypotheses, or fallback.
5. Use ctf-board to track multiple challenge folders.
6. Use ctf-finish before submitting or archiving the solve.
QUICKSTART

if [ ! -d "$CTF_ROOT/.git" ]; then
  echo "[+] Initialising git repository in $CTF_ROOT"
  git -C "$CTF_ROOT" init >/dev/null 2>&1 || true
fi

echo
echo "[+] Final status"
echo "    codex:  $(command -v codex || echo 'not found')"
echo "    claude: $(command -v claude || echo 'not found')"
echo "    agy:    $(command -v agy || echo 'not found')"
echo "    gemini: $(command -v gemini || echo 'not found')"
echo "    jq:     $(command -v jq || echo 'not found')"
echo "    npm:    $(command -v npm || echo 'not found')"
echo "    pipx:   $(command -v pipx || echo 'not found')"
echo "    python: $(command -v python3 || echo 'not found')"
echo "    venv:   $PYENV_DIR"
echo

echo "[+] Bootstrap complete."
echo
echo "Next steps:"
echo "  1. Run: source ~/.bashrc"
echo "  2. Run: ctf-status"
echo "  3. Sign into agents if needed:"
echo "       codex"
echo "       claude"
echo "       agy"
echo "       gemini"
echo "  4. Intake a challenge:"
echo "       ctf-intake --category web --difficulty easy --name Jailbreak --target 154.57.164.79:31790 <<'EOF'"
echo "       Paste challenge description here."
echo "       EOF"
echo "  5. Start an agent:"
echo "       cd ~/ctf-event/challenges/web/jailbreak"
echo "       ctf-start codex-auto"
echo "  6. Track active challenges:"
echo "       ctf-board"
echo "  7. After solve:"
echo "       ctf-finish"
echo
