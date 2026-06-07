#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# HTB AI CTF Bootstrap
#
# Purpose:
#   Quickly prepare a Parrot / HTB Pwnbox / Kali-like VM for
#   AI-assisted Hack The Box CTF work using:
#     - OpenAI Codex
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
#   - Challenge creation helper
#   - Codex autonomous PoC prompt helper
#   - Status checker
#   - Mandatory high-level writeup template/instructions
#
# Usage:
#   ./setup-htb-ai-ctf.sh
#   ./setup-htb-ai-ctf.sh --with-apt
#
# Notes:
#   - Do not put API keys or passwords in this script.
#   - Prefer browser/OAuth login for Codex, Claude, and Gemini tools.
#   - Use only for authorised CTF/lab targets.
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
  mkdir -p "$CTF_ROOT"/{challenges,notes,wordlists,scripts,loot,tmp,writeups}
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

You are helping with authorised security training and Capture the Flag work only.

Default behaviour:
- Be concise, evidence-based, and practical.
- Work only on the user-provided CTF/lab target scope.
- Ask before running active network commands unless the user has explicitly authorised autonomous mode for a specific target.
- Ask before installing packages.
- Ask before executing unknown binaries.
- Do not attack unrelated systems.
- Do not attempt persistence, evasion, credential theft, denial-of-service, destructive actions, or activity outside the CTF/lab.
- Do not submit flags automatically unless explicitly asked by the user.
- Maintain clear notes and explain evidence.

Required completion behaviour:
- When a flag is found, save it to loot/flag.txt.
- Create or update writeup.md with a high-level explanation of:
  - challenge summary
  - initial observations
  - attack path
  - key commands/scripts
  - why the vulnerability worked
  - flag location
  - remediation idea, where applicable
- Keep the writeup suitable for learning and review, not just a command log.

Preferred workflow:
1. Read local challenge files first.
2. Create or update notes.md.
3. Propose or execute a short plan depending on the authorised mode.
4. Run safe local inspection commands first.
5. Use small auditable Python or Bash scripts.
6. Keep scripts under scripts/.
7. Keep outputs or artefacts under loot/ or scans/.
8. Explain what changed and why.
CODEXGLOBAL

echo "[+] Creating global Claude guidance"

cat > "$HOME/.claude/CLAUDE.md" <<'CLAUDEGLOBAL'
# Global Claude Code Working Agreements

You are helping with authorised security training and Capture the Flag work only.

Default behaviour:
- Be concise, evidence-based, and practical.
- Work only on the user-provided CTF/lab target scope.
- Ask before running active network commands unless the user has explicitly authorised autonomous mode for a specific target.
- Ask before installing packages.
- Ask before executing unknown binaries.
- Do not attack unrelated systems.
- Do not attempt persistence, evasion, credential theft, denial-of-service, destructive actions, or activity outside the CTF/lab.
- Do not submit flags automatically unless explicitly asked by the user.
- Maintain clear notes and explain evidence.

Required completion behaviour:
- When a flag is found, save it to loot/flag.txt.
- Create or update writeup.md with a high-level explanation of:
  - challenge summary
  - initial observations
  - attack path
  - key commands/scripts
  - why the vulnerability worked
  - flag location
  - remediation idea, where applicable
- Keep the writeup suitable for learning and review, not just a command log.

Preferred workflow:
1. Read local challenge files first.
2. Create or update notes.md.
3. Propose or execute a short plan depending on the authorised mode.
4. Run safe local inspection commands first.
5. Use small auditable Python or Bash scripts.
6. Keep scripts under scripts/.
7. Keep outputs or artefacts under loot/ or scans/.
8. Explain what changed and why.

Important:
- Do not use unsafe auto-approval behaviour unless the user explicitly starts a scoped CTF PoC.
- Do not use dangerous permission bypass modes outside isolated CTF/lab environments.
CLAUDEGLOBAL

echo "[+] Creating project guidance files"

cat > "$CTF_ROOT/AGENTS.md" <<'CODEXPROJECT'
# CTF Project Guidance for Codex

This repository is for authorised Capture the Flag and lab work.

Scope rules:
- Only operate inside this CTF workspace unless explicitly told otherwise.
- Only target challenge hosts, ports, files, and URLs explicitly provided by the user.
- Ask before active scanning, brute force, exploit execution, or unknown binary execution unless the user has explicitly authorised autonomous mode for a specific target.
- Never attack other participants, corporate infrastructure, public systems, or unrelated networks.
- Do not perform denial-of-service.
- Do not submit flags automatically unless explicitly instructed.

Working conventions:
- Each challenge should have:
  - notes.md
  - AGENTS.md
  - scripts/
  - files/
  - loot/
  - scans/
  - writeup.md
- Keep commands and observations in notes.md.
- Prefer Python 3 scripts using requests, pwntools, pycryptodome, z3, or standard library.
- Prefer repeatable solve scripts over one-off manual changes.
- Keep output readable and explain what evidence supports each conclusion.

Required completion behaviour:
- When a flag is found:
  1. save it to loot/flag.txt
  2. save the final script or exact command where practical
  3. create/update writeup.md
  4. include a concise summary of how the agent solved the challenge
  5. include the vulnerability class or solving concept
  6. include remediation guidance where relevant

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
The successful route to the flag, with only necessary commands or scripts.

## Flag Location
Where and how the flag was found.

## Agent Notes
What the agent tried, what worked, and what was avoided.

## Remediation / Learning Point
What would prevent this issue in a real system, where applicable.

When asked to solve:
1. Start with triage.
2. Identify category and likely route.
3. Execute only within the authorised scope.
4. Update notes.md throughout.
5. Create scripts under scripts/.
6. Save artefacts under loot/ or scans/.
7. Save flag to loot/flag.txt.
8. Create writeup.md before ending.
CODEXPROJECT

cat > "$CTF_ROOT/CLAUDE.md" <<'CLAUDEPROJECT'
# CTF Project Guidance for Claude Code

This repository is for authorised Capture the Flag and lab work.

Scope rules:
- Only operate inside this CTF workspace unless explicitly told otherwise.
- Only target challenge hosts, ports, files, and URLs explicitly provided by the user.
- Ask before active scanning, brute force, exploit execution, or unknown binary execution unless the user has explicitly authorised autonomous mode for a specific target.
- Never attack other participants, corporate infrastructure, public systems, or unrelated networks.
- Do not perform denial-of-service.
- Do not submit flags automatically unless explicitly instructed.

Working conventions:
- Each challenge should have:
  - notes.md
  - CLAUDE.md
  - scripts/
  - files/
  - loot/
  - scans/
  - writeup.md
- Keep commands and observations in notes.md.
- Prefer Python 3 scripts using requests, pwntools, pycryptodome, z3, or standard library.
- Prefer repeatable solve scripts over one-off manual changes.
- Keep output readable and explain what evidence supports each conclusion.

Claude Code behaviour:
- Use the relevant skill when a challenge category is clear.
- Use /ctf-triage first when the path is not clear.
- Ask before running active network commands unless the user has explicitly authorised autonomous mode.
- Ask before executing unknown binaries unless explicitly approved.
- Do not use unsafe auto-approval or dangerous permission bypass modes outside isolated CTF/lab environments.

Required completion behaviour:
- When a flag is found:
  1. save it to loot/flag.txt
  2. save the final script or exact command where practical
  3. create/update writeup.md
  4. include a concise summary of how the agent solved the challenge
  5. include the vulnerability class or solving concept
  6. include remediation guidance where relevant

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
The successful route to the flag, with only necessary commands or scripts.

## Flag Location
Where and how the flag was found.

## Agent Notes
What the agent tried, what worked, and what was avoided.

## Remediation / Learning Point
What would prevent this issue in a real system, where applicable.

When asked to solve:
1. Start with triage.
2. Identify category and likely route.
3. Execute only within the authorised scope.
4. Update notes.md throughout.
5. Create scripts under scripts/.
6. Save artefacts under loot/ or scans/.
7. Save flag to loot/flag.txt.
8. Create writeup.md before ending.
CLAUDEPROJECT

cat > "$CTF_ROOT/GEMINI.md" <<'GEMINIPROJECT'
# Gemini / Antigravity CTF Project Context

This is an authorised Capture the Flag workspace.

Rules:
- Work only on provided CTF challenge files and targets.
- Ask before active network commands unless autonomous mode has been explicitly authorised for a specific target.
- Ask before executing unknown binaries.
- Do not perform denial-of-service, persistence, evasion, credential theft, or destructive actions.
- Do not submit flags automatically unless explicitly instructed.
- Maintain notes.md for every challenge.

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

mkdir -p "$CODEX_SKILLS_ROOT"/{ctf-triage,web-ctf,crypto-ctf,reverse-ctf,forensics-ctf,pwn-ctf,misc-ctf,osint-ctf,ai-jailbreak-ctf}
mkdir -p "$CLAUDE_SKILLS_ROOT"/{ctf-triage,web-ctf,crypto-ctf,reverse-ctf,forensics-ctf,pwn-ctf,misc-ctf,osint-ctf,ai-jailbreak-ctf}
mkdir -p "$HOME/.agents/skills"
mkdir -p "$HOME/.claude/skills"

create_skill_files() {
  local root="$1"

  cat > "$root/ctf-triage/SKILL.md" <<'SKILLTRIAGE'
---
name: ctf-triage
description: Initial triage for authorised HTB/CTF challenges. Use for setting up notes, identifying category, selecting safe methodology, and creating a solve plan.
---

# CTF Triage Skill

Use only for authorised CTF/lab challenges.

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

1. Read notes.md, AGENTS.md, CLAUDE.md, GEMINI.md, README.md, and challenge files if present.
2. Create directories if missing:
   - files/
   - scripts/
   - scans/
   - loot/
   - tmp/
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
5. Start with safe local inspection:
   - ls -la
   - file
   - sha256sum
   - strings
   - exiftool
   - binwalk
   - xxd
   - head
   - tail
6. For network targets, use only targeted checks against the provided host/port.
7. Avoid broad scanning unless explicitly authorised and relevant.

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
5. Include the vulnerability class or solving concept.
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

Use only for authorised CTF/lab web challenges.

## Goals

1. Identify the web technology and attack surface.
2. Inspect routes, forms, cookies, JavaScript, APIs, and parameters.
3. Test plausible CTF-safe vulnerability classes.
4. Build repeatable scripts where useful.
5. Save the flag and create writeup.md when solved.

## Safe first checks

Use targeted checks only:
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
- JWT issues in CTF-only contexts
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

## Enumeration rules

- Keep enumeration conservative.
- Avoid large wordlists by default.
- Use ffuf/gobuster only after HTTP is confirmed.
- Use low thread counts.
- Do not scan unrelated hosts or ports.
- Do not brute force credentials unless the challenge clearly expects it and the rate is conservative.

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
   - successful payload or request
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

Use only for authorised CTF/lab crypto challenges.

## Goals

1. Identify whether the challenge is encoding, classical crypto, modern crypto misuse, hash/signature issue, or custom crypto.
2. Test hypotheses with small repeatable scripts.
3. Avoid guessing without evidence.
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
- remote oracle behaviour

## Common checks

Consider:
- hex/base64/base32/base85/binary/URL encoding
- magic bytes
- XOR
- repeating-key XOR
- known plaintext
- Caesar/Vigenere/affine only where plausible
- frequency analysis
- weak PRNG
- predictable seed
- RSA small exponent
- RSA shared modulus
- RSA common factor
- leaked p/q/d
- incorrect padding
- AES ECB
- CBC bit flipping in CTF-only contexts
- nonce/IV reuse
- hash length extension
- JWT weak HMAC secret or alg confusion in CTF-only contexts
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
- avoid destructive or unrelated activity
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
description: Authorised HTB/CTF reverse-engineering workflow. Use for binaries, packed files, strings, ELF/PE metadata, static analysis, simple dynamic analysis, XOR routines, and flag check logic.
---

# Reverse Engineering CTF Skill

Use only for authorised CTF/lab reversing challenges.

## Goals

1. Identify binary type, architecture, protections, and likely flag path.
2. Prefer static analysis first.
3. Ask before executing unknown binaries unless autonomous mode explicitly permits it.
4. Build helper scripts for decoding/emulation.
5. Save writeup when solved.

## Safe static analysis

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

## Dynamic analysis rules

- Do not run unknown binaries as root.
- Prefer isolated challenge directory.
- Use timeout where appropriate.
- Use strace/ltrace/gdb only when useful.
- Avoid destructive behaviour.

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
description: Authorised HTB/CTF pwn challenge workflow. Use for local binaries, remote services, pwntools scripts, protections, crashes, format strings, ret2win, ROP, ret2libc, and controlled exploit development.
---

# Pwn CTF Skill

Use only for authorised CTF/lab pwn challenges.

## Goals

1. Identify binary protections and target behaviour.
2. Reproduce locally where possible.
3. Build conservative, repeatable pwntools scripts.
4. Avoid flooding or destructive behaviour.
5. Save final exploit script, flag, and writeup.

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

## Safety rules

- Do not run unknown binaries as root.
- Do not brute force at high rate.
- Do not flood remote services.
- Do not scan unrelated hosts/ports.
- Keep remote interaction targeted and controlled.
- Prefer local testing before remote interaction.

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
- simple heap misuse
- shellcode only where challenge design clearly permits it

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

Use only for authorised CTF/lab forensics challenges.

## Goals

1. Preserve original files.
2. Identify file types and hidden content.
3. Extract evidence into loot/.
4. Build small scripts for parsing where useful.
5. Save final flag and writeup.

## Safe inspection

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
- credentials/tokens only inside the CTF artefact scope
- log timelines
- browser/history artefacts
- SQLite databases
- memory dump strings and processes

## File handling rules

- Preserve originals in files/.
- Extract into loot/ or tmp/.
- Avoid destructive writes to evidence files.
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

Use only for authorised CTF/lab misc challenges.

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
- python socket
- websocat if available
- file/strings for provided artefacts
- conservative manual interaction

## Interaction rules

- Do not flood services.
- Do not brute force unless clearly intended and rate controlled.
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

Use only for authorised CTF/lab OSINT challenges.

## Goals

1. Work only from challenge-provided clues and public information.
2. Preserve evidence.
3. Avoid doxxing, harassment, or contacting real people.
4. Save flag and writeup.

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

## Rules

- Do not contact individuals.
- Do not attempt account access.
- Do not harass or deanonymise real people.
- Do not collect unnecessary personal data.
- Keep evidence relevant to the challenge.

## Required completion behaviour

When a flag is found:
1. Save it to loot/flag.txt.
2. Save evidence links or notes in notes.md.
3. Create/update writeup.md with:
   - clue chain
   - evidence
   - conclusion
   - flag location
   - ethical boundaries observed

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

Use only for authorised CTF/lab AI or prompt-jailbreak challenges.

## Goals

1. Understand the model/app behaviour.
2. Identify constraints and allowed actions.
3. Use challenge-contained prompt strategies to solve the puzzle.
4. Avoid real-world abuse or unrelated systems.
5. Save flag and writeup.

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

## Rules

- Work only against the challenge service.
- Do not use strategies against real services or accounts.
- Do not attempt credential theft or real-world data extraction.
- Do not flood or automate high-volume prompts.

## Methodology

1. Record the prompt/interface behaviour.
2. Try harmless capability questions.
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

rm -rf "$HOME/.agents/skills/ctf-triage" \
       "$HOME/.agents/skills/web-ctf" \
       "$HOME/.agents/skills/crypto-ctf" \
       "$HOME/.agents/skills/reverse-ctf" \
       "$HOME/.agents/skills/pwn-ctf" \
       "$HOME/.agents/skills/forensics-ctf" \
       "$HOME/.agents/skills/misc-ctf" \
       "$HOME/.agents/skills/osint-ctf" \
       "$HOME/.agents/skills/ai-jailbreak-ctf"

rm -rf "$HOME/.claude/skills/ctf-triage" \
       "$HOME/.claude/skills/web-ctf" \
       "$HOME/.claude/skills/crypto-ctf" \
       "$HOME/.claude/skills/reverse-ctf" \
       "$HOME/.claude/skills/pwn-ctf" \
       "$HOME/.claude/skills/forensics-ctf" \
       "$HOME/.claude/skills/misc-ctf" \
       "$HOME/.claude/skills/osint-ctf" \
       "$HOME/.claude/skills/ai-jailbreak-ctf"

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

echo "[+] Creating helper: new-ctf-challenge"

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
ROOT="${CTF_ROOT:-$HOME/ctf-event}"
DIR="$ROOT/challenges/$CATEGORY/$NAME"

mkdir -p "$DIR"/{files,scripts,loot,scans,tmp}

cat > "$DIR/notes.md" <<NOTES
# $NAME

## Category

$CATEGORY

## Description

Paste challenge description here.

## Scope / Targets

$TARGET

## Hints

Paste hints here.

## Rules

- This is an authorised CTF/lab challenge.
- Only target the explicitly provided scope.
- Do not attack unrelated hosts, participants, infrastructure, or public systems.
- Do not run denial-of-service, flooding, persistence, evasion, destructive actions, or credential theft.
- Save scripts under scripts/.
- Save artefacts under loot/ or scans/.
- Save flag to loot/flag.txt if found.
- Create/update writeup.md when solved.

## Commands Run

None yet.

## Observations

- 

## Hypotheses

- 

## Scripts

- 

## Flag / Final Answer

Not found yet.
NOTES

cat > "$DIR/AGENTS.md" <<AGENTSLOCAL
# Challenge Instructions for Codex

This folder is for one authorised CTF/lab challenge.

Challenge:
- Name: $NAME
- Category: $CATEGORY
- Target: $TARGET

Scope:
- Only operate inside this challenge directory.
- Only target explicitly provided challenge hosts, ports, files, and URLs.
- Do not scan unrelated hosts or broad port ranges.
- Do not run denial-of-service, flooding, destructive commands, persistence, evasion, or credential theft.
- Keep enumeration conservative and low rate.
- Prefer repeatable scripts over manual one-off actions.

Required workflow:
1. Read notes.md and AGENTS.md.
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
AGENTSLOCAL

cat > "$DIR/CLAUDE.md" <<CLAUDELOCAL
# Challenge Instructions for Claude Code

This folder is for one authorised CTF/lab challenge.

Challenge:
- Name: $NAME
- Category: $CATEGORY
- Target: $TARGET

Scope:
- Only operate inside this challenge directory.
- Only target explicitly provided challenge hosts, ports, files, and URLs.
- Do not scan unrelated hosts or broad port ranges.
- Do not run denial-of-service, flooding, destructive commands, persistence, evasion, or credential theft.
- Keep enumeration conservative and low rate.
- Prefer repeatable scripts over manual one-off actions.

Required workflow:
1. Read notes.md and CLAUDE.md.
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
CLAUDELOCAL

cat > "$DIR/GEMINI.md" <<GEMINILOCAL
# Challenge Instructions for Gemini / Antigravity

This folder is for one authorised CTF/lab challenge.

Challenge:
- Name: $NAME
- Category: $CATEGORY
- Target: $TARGET

Scope:
- Work only in this directory.
- Only target explicitly provided challenge scope.
- Keep actions conservative and evidence-based.
- Save flag to loot/flag.txt if found.
- Create/update writeup.md when solved.
GEMINILOCAL

cat > "$DIR/writeup.md" <<WRITEUP
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
WRITEUP

cat > "$DIR/run_codex_auto_prompt.txt" <<PROMPT
Use the ctf-triage skill and any relevant specialist CTF skill.

This is an authorised Hack The Box / CTF challenge PoC.

I want you to carry out the full analysis and attempt to locate the flag automatically.

Challenge:
- Name: $NAME
- Category: $CATEGORY
- Target: $TARGET
- Work only in this directory.
- Save notes to notes.md.
- Save scripts under scripts/.
- Save artefacts under loot/ or scans/.
- Save the flag to loot/flag.txt if found.
- Create or update writeup.md when the flag is found or when analysis is complete.

You may run targeted commands against the explicitly provided challenge target without asking again.

Constraints:
- Do not scan unrelated hosts.
- Do not scan broad port ranges.
- Do not attack anything outside the provided scope.
- Do not run denial-of-service, flooding, destructive commands, persistence, evasion, or credential theft.
- Keep enumeration conservative and low rate.
- Prefer repeatable scripts over manual one-off actions.
- Do not submit the flag automatically.

Start now:
1. Read notes.md and AGENTS.md.
2. Identify the service/challenge type.
3. Analyse the challenge.
4. Attempt to locate the flag.
5. Update notes.md throughout.
6. Save scripts and artefacts.
7. If the flag is found, save it to loot/flag.txt.
8. Create or update writeup.md with:
   - Summary
   - Initial Observations
   - Methodology
   - Key Findings
   - Exploitation / Solve Path
   - Flag Location
   - Agent Notes
   - Remediation / Learning Point
9. Stop when the flag is found or reasonable low-risk approaches are exhausted.
PROMPT

echo "[+] Created: $DIR"
echo
echo "Next:"
echo "    cd \"$DIR\""
echo "    codex"
echo "    # press \$ to select a skill, or paste run_codex_auto_prompt.txt"
echo
echo "Autonomous Codex PoC:"
echo "    ctf-codex-auto"
echo
echo "Claude:"
echo "    claude"
NEWCHALLENGE

chmod +x "$LOCAL_BIN/new-ctf-challenge"

echo "[+] Creating helper: ctf-codex-auto"

cat > "$LOCAL_BIN/ctf-codex-auto" <<'CODEXAUTO'
#!/usr/bin/env bash
set -Eeuo pipefail

if [ ! -f "run_codex_auto_prompt.txt" ]; then
  echo "[!] run_codex_auto_prompt.txt not found in current directory."
  echo "[!] Run this from a challenge directory created with new-ctf-challenge."
  exit 1
fi

echo "[+] Starting Codex autonomous CTF PoC mode."
echo "[+] Current directory: $(pwd)"
echo
echo "[!] This uses danger-full-access and ask-for-approval=never."
echo "[!] Only use inside an isolated VM and only for authorised CTF/lab scope."
echo "[!] The prompt still restricts Codex to the challenge target and forbids DoS/destructive actions."
echo

codex --sandbox danger-full-access --ask-for-approval never "$(cat run_codex_auto_prompt.txt)"
CODEXAUTO

chmod +x "$LOCAL_BIN/ctf-codex-auto"

echo "[+] Creating helper: ctf-codex-auto-exec"

cat > "$LOCAL_BIN/ctf-codex-auto-exec" <<'CODEXAUTOEXEC'
#!/usr/bin/env bash
set -Eeuo pipefail

if [ ! -f "run_codex_auto_prompt.txt" ]; then
  echo "[!] run_codex_auto_prompt.txt not found in current directory."
  echo "[!] Run this from a challenge directory created with new-ctf-challenge."
  exit 1
fi

echo "[+] Starting Codex non-interactive autonomous CTF PoC mode."
echo "[+] Current directory: $(pwd)"
echo

codex exec \
  --sandbox danger-full-access \
  --ask-for-approval never \
  "$(cat run_codex_auto_prompt.txt)"
CODEXAUTOEXEC

chmod +x "$LOCAL_BIN/ctf-codex-auto-exec"

echo "[+] Creating helper: ctf-writeup-check"

cat > "$LOCAL_BIN/ctf-writeup-check" <<'WRITEUPCHECK'
#!/usr/bin/env bash
set -Eeuo pipefail

echo "[+] Checking challenge completion files in: $(pwd)"
echo

if [ -f "loot/flag.txt" ]; then
  echo "[+] Flag file exists:"
  cat loot/flag.txt
else
  echo "[!] Missing loot/flag.txt"
fi

echo

if [ -f "writeup.md" ]; then
  echo "[+] writeup.md exists"
  echo
  grep -E '^## ' writeup.md || true
else
  echo "[!] Missing writeup.md"
fi

echo

echo "[+] Files:"
find . -maxdepth 3 -type f | sort
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
for cmd in python3 pipx node npm jq tmux git curl; do
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
CTFSTATUS

chmod +x "$LOCAL_BIN/ctf-status"

echo "[+] Creating quickstart notes"

cat > "$CTF_ROOT/AI_CTF_QUICKSTART.md" <<'QUICKSTART'
# AI CTF Quickstart

## Initial setup

Run:

    source ~/.bashrc
    ctf-status

## Create a challenge

Example:

    new-ctf-challenge web jailbreak 154.57.164.79:31790
    cd ~/ctf-event/challenges/web/jailbreak

Edit notes.md and paste the challenge description, hints, and target scope.

## Codex interactive mode

Run:

    codex

Press `$` to select a skill, such as:

    ctf-triage
    web-ctf
    crypto-ctf
    reverse-ctf
    pwn-ctf
    forensics-ctf
    misc-ctf
    ai-jailbreak-ctf

Prompt:

    Use the selected CTF skill.
    This is an authorised CTF challenge.
    Read notes.md and AGENTS.md.
    Analyse the challenge and attempt to locate the flag within the provided scope.
    Save scripts under scripts/.
    Save artefacts under loot/ or scans/.
    Save the flag to loot/flag.txt if found.
    Create or update writeup.md when solved.

## Codex autonomous PoC mode

From a challenge directory:

    ctf-codex-auto

This launches Codex with:

    --sandbox danger-full-access
    --ask-for-approval never

Only use this in an isolated VM and only for authorised CTF/lab targets.

## Codex non-interactive autonomous mode

From a challenge directory:

    ctf-codex-auto-exec

## Claude Code

Run:

    claude

Use slash skills:

    /ctf-triage
    /web-ctf
    /crypto-ctf
    /reverse-ctf
    /pwn-ctf
    /forensics-ctf
    /misc-ctf
    /ai-jailbreak-ctf

## Gemini / Antigravity

Run:

    gemini

or:

    agy

Use GEMINI.md as context.

## Completion check

After the agent finishes:

    ctf-writeup-check

Expected final files:

    notes.md
    writeup.md
    loot/flag.txt
    scripts/solve.py or equivalent, where practical

## Recommended workflow

1. Create the challenge folder.
2. Paste the challenge description and scope into notes.md.
3. Start with Codex or Claude.
4. Use a specialist skill.
5. Let the agent create scripts under scripts/.
6. Ensure the flag is saved to loot/flag.txt.
7. Ensure writeup.md explains how the agent solved it.
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
echo "  4. Create a challenge:"
echo "       new-ctf-challenge web jailbreak 154.57.164.79:31790"
echo "       cd ~/ctf-event/challenges/web/jailbreak"
echo "  5. For autonomous Codex PoC:"
echo "       ctf-codex-auto"
echo "  6. After solve:"
echo "       ctf-writeup-check"
echo
