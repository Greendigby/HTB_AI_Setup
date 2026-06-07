# HTB AI CTF Bootstrap

A bootstrap script for quickly preparing a Parrot OS, Kali-like, or Hack The Box Pwnbox environment for AI-assisted Capture the Flag work using:

* OpenAI Codex CLI
* Claude Code
* Gemini CLI
* Google Antigravity CLI

The setup creates a repeatable CTF workspace, installs common tooling, prepares reusable CTF skills, and provides helper commands for running agent-assisted or autonomous challenge analysis.

This is intended for authorised CTFs, training labs, and Hack The Box-style challenge environments only.

---

## What this provides

The script creates:

```text
~/ctf-event/
  AGENTS.md
  CLAUDE.md
  GEMINI.md
  AI_CTF_QUICKSTART.md
  .agents/skills/
  .claude/skills/
  challenges/
  loot/
  notes/
  scripts/
  tmp/
  wordlists/
  writeups/
```

It also creates user-level skill directories:

```text
~/.agents/skills/
~/.claude/skills/
```

And helper commands:

```text
ctf-status
ctf-venv
new-ctf-challenge
sync-ctf-skills
ctf-codex-auto
ctf-codex-auto-exec
ctf-writeup-check
```

---

## Supported AI tools

### Codex CLI

Primary recommended tool for autonomous or semi-autonomous CTF analysis.

Use Codex when you want the agent to:

* inspect a challenge directory
* run targeted commands
* create scripts
* interact with a scoped CTF target
* save the flag to `loot/flag.txt`
* generate a high-level `writeup.md`

Codex uses:

```text
AGENTS.md
~/.agents/skills/
~/ctf-event/.agents/skills/
```

In Codex, skills are selected using:

```text
$
```

not `/`.

---

### Claude Code

Recommended for a skills-first workflow similar to the “Claude Code + Skills” CTF approach.

Use Claude Code when you want:

* slash-command style skills
* strong project-context use
* structured challenge analysis
* repeatable methodology through `CLAUDE.md`

Claude Code uses:

```text
CLAUDE.md
~/.claude/skills/
~/ctf-event/.claude/skills/
```

In Claude Code, skills are selected using slash commands, for example:

```text
/ctf-triage
/web-ctf
/crypto-ctf
```

---

### Gemini CLI / Antigravity

Useful as second-opinion agents.

Use Gemini or Antigravity when:

* Codex or Claude gets stuck
* you want alternative hypotheses
* you want a second review of `notes.md`
* you want another model to review scripts or writeups

Gemini and Antigravity use:

```text
GEMINI.md
```

as project context.

---

## Included CTF skills

The script pre-populates these skills for Codex and Claude:

```text
ctf-triage
web-ctf
crypto-ctf
reverse-ctf
pwn-ctf
forensics-ctf
misc-ctf
osint-ctf
ai-jailbreak-ctf
```

### Skill coverage

| Skill              | Use for                                                                     |
| ------------------ | --------------------------------------------------------------------------- |
| `ctf-triage`       | Initial classification, notes setup, methodology selection                  |
| `web-ctf`          | HTTP services, APIs, auth flaws, injection, XXE, file read, SSTI, uploads   |
| `crypto-ctf`       | Encodings, XOR, RSA, AES misuse, weak randomness, signatures, custom crypto |
| `reverse-ctf`      | Binaries, static analysis, strings, check logic, packed files               |
| `pwn-ctf`          | Binary exploitation, pwntools, ret2win, ROP, format strings                 |
| `forensics-ctf`    | PCAPs, images, archives, metadata, stego, file carving                      |
| `misc-ctf`         | Raw TCP services, puzzles, restricted shells, custom protocols              |
| `osint-ctf`        | Public clues, metadata, geolocation, usernames, timestamps                  |
| `ai-jailbreak-ctf` | Prompt-injection / AI-jailbreak style CTF challenges                        |

Each skill instructs the agent to:

* stay inside the authorised challenge scope
* keep notes in `notes.md`
* create scripts under `scripts/`
* save artefacts under `loot/` or `scans/`
* save the flag to `loot/flag.txt`
* create or update `writeup.md` when complete

---

## Prerequisites

Recommended environment:

```text
Parrot OS, Kali, or HTB Pwnbox
8 GB RAM preferred
20 GB+ free disk preferred
Internet access for agent login and package installation
```

For a local VMware test VM, use:

```text
Disk: 60 GB
RAM: 8 GB
CPU: 4 cores
Network: NAT
```

Before running with apt installation enabled, check:

```bash
df -h /
findmnt /
```

Do not run `--with-apt` if `/` is mounted as `overlay`, because that usually means you are in a live ISO environment with limited temporary storage.

---

## Installation

Clone your repository:

```bash
git clone <your-repo-url>
cd <your-repo-name>
chmod +x setup-htb-ai-ctf.sh
```

### Full install on an installed VM

Use this on an installed Parrot/Kali VM with enough disk space:

```bash
./setup-htb-ai-ctf.sh --with-apt
source ~/.bashrc
ctf-status
```

### Lightweight install on HTB Pwnbox

Use this if Pwnbox already has most tools installed or disk space is limited:

```bash
./setup-htb-ai-ctf.sh
source ~/.bashrc
ctf-status
```

### Verify installation

Run:

```bash
ctf-status
```

Expected output should show at least:

```text
codex:  found
claude: found
python3: found
jq: found
npm: found
tmux: found
```

Gemini and Antigravity are useful but optional.

---

## First-time agent login

Run each tool once and sign in when prompted.

### Codex

```bash
codex
```

Sign in with your ChatGPT account.

Exit when complete.

### Claude Code

```bash
claude
```

Sign in with your Claude account.

Exit when complete.

### Gemini CLI

```bash
gemini
```

Sign in with your Google/Gemini account.

Exit when complete.

### Antigravity

```bash
agy
```

Sign in with your Google/Gemini account.

Exit when complete.

---

## Recommended workflow

### 1. Create a challenge folder

Example:

```bash
new-ctf-challenge web jailbreak 154.57.164.79:31790
cd ~/ctf-event/challenges/web/jailbreak
```

This creates:

```text
notes.md
AGENTS.md
CLAUDE.md
GEMINI.md
writeup.md
run_codex_auto_prompt.txt
files/
scripts/
loot/
scans/
tmp/
```

### 2. Add challenge details

Edit:

```bash
nano notes.md
```

Paste in:

```text
Challenge name
Category
Description
Target URL / IP / port
Hints
Flag location, if provided
Any downloaded files
Rules or constraints
```

### 3. Choose an agent

Use:

```text
Codex       for autonomous PoC solving
Claude Code for skills-first interactive solving
Gemini      for second opinions
Antigravity for Google-side agent workflow
```

---

## Using Codex interactively

From a challenge directory:

```bash
codex
```

Press:

```text
$
```

Select a skill such as:

```text
ctf-triage
web-ctf
crypto-ctf
reverse-ctf
pwn-ctf
forensics-ctf
misc-ctf
ai-jailbreak-ctf
```

Then prompt Codex:

```text
Use the selected CTF skill.

This is an authorised CTF challenge.

Read notes.md and AGENTS.md.
Analyse the challenge and attempt to locate the flag within the provided scope.

Save scripts under scripts/.
Save artefacts under loot/ or scans/.
Save the flag to loot/flag.txt if found.
Create or update writeup.md when solved.

Do not attack anything outside the provided scope.
Do not run denial-of-service, flooding, destructive commands, persistence, evasion, or credential theft.
Do not submit the flag automatically.
```

---

## Using Codex autonomous PoC mode

From a challenge directory:

```bash
ctf-codex-auto
```

This launches Codex using the prepared `run_codex_auto_prompt.txt`.

It uses:

```text
--sandbox danger-full-access
--ask-for-approval never
```

Use this only inside an isolated VM and only against authorised CTF/lab targets.

### Non-interactive autonomous mode

From a challenge directory:

```bash
ctf-codex-auto-exec
```

This runs Codex as a one-shot non-interactive job.

Use this when you want a cleaner PoC run and do not need to interact with the agent while it works.

---

## Using Claude Code

From a challenge directory:

```bash
claude
```

Use a skill:

```text
/ctf-triage
```

or:

```text
/web-ctf
```

Example prompt:

```text
/ctf-triage

This is an authorised CTF challenge.

Read notes.md and CLAUDE.md.
Analyse the challenge and create a solve plan.

If the flag is found:
- save it to loot/flag.txt
- create or update writeup.md
- save any useful scripts under scripts/

Do not attack anything outside the provided scope.
Do not run denial-of-service, flooding, destructive commands, persistence, evasion, or credential theft.
Do not submit the flag automatically.
```

For web:

```text
/web-ctf

This is an authorised CTF web challenge.

Read notes.md and CLAUDE.md.
Identify the web attack surface.
Inspect routes, forms, JavaScript, cookies, headers, and likely API endpoints.
Test only within the provided scope.

If the flag is found, save it to loot/flag.txt and create writeup.md.
```

For crypto:

```text
/crypto-ctf

This is an authorised CTF crypto challenge.

Read notes.md and any files in files/.
Identify the likely crypto class.
Create repeatable solve scripts under scripts/.
Save the flag to loot/flag.txt if found.
Create writeup.md when solved.
```

---

## Using Gemini CLI

From a challenge directory:

```bash
gemini
```

Prompt:

```text
Use GEMINI.md as project context.

This is an authorised CTF challenge.

Review notes.md, scripts/, loot/, and writeup.md.
Suggest alternative hypotheses and next steps.
Do not run active network commands unless explicitly authorised.
Do not attack anything outside the provided challenge scope.
```

Gemini is useful when:

```text
- Codex or Claude gets stuck
- you want a second opinion
- you want a challenge writeup reviewed
- you want alternative hypotheses
```

---

## Using Antigravity

From a challenge directory:

```bash
agy
```

Prompt:

```text
Use GEMINI.md as project context.

This is an authorised CTF challenge.

Review the current challenge directory.
Summarise the current state.
Suggest the next likely solve paths.
Do not run destructive or out-of-scope actions.
```

---

## Completion requirements

Every solved challenge should end with:

```text
loot/flag.txt
writeup.md
notes.md
scripts/solve.py or equivalent, where practical
```

Check completion with:

```bash
ctf-writeup-check
```

Expected output:

```text
[+] Flag file exists
[+] writeup.md exists
```

---

## Writeup format

Each challenge writeup should use this structure:

```markdown
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
```

The goal is a high-level learning writeup, not just a transcript.

---

## Example: web challenge

Create the challenge:

```bash
new-ctf-challenge web jailbreak 154.57.164.79:31790
cd ~/ctf-event/challenges/web/jailbreak
nano notes.md
```

Add the challenge description and target.

Run autonomous Codex:

```bash
ctf-codex-auto
```

After completion:

```bash
ctf-writeup-check
cat loot/flag.txt
sed -n '1,220p' writeup.md
```

---

## Example: Claude-led workflow

```bash
new-ctf-challenge web challenge-name 1.2.3.4:12345
cd ~/ctf-event/challenges/web/challenge-name
nano notes.md
claude
```

Prompt:

```text
/web-ctf

This is an authorised CTF web challenge.
Read notes.md and CLAUDE.md.
Carry out a scoped analysis of the target.
Save scripts under scripts/.
Save the flag to loot/flag.txt if found.
Create writeup.md when solved.
```

---

## Example: Codex interactive workflow

```bash
new-ctf-challenge misc challenge-name 1.2.3.4:12345
cd ~/ctf-event/challenges/misc/challenge-name
codex
```

Inside Codex:

1. Press `$`.
2. Select `misc-ctf`.
3. Paste:

```text
This is an authorised CTF challenge.
Read notes.md and AGENTS.md.
Analyse the service and attempt to locate the flag within the provided scope.
Save scripts under scripts/.
Save artefacts under loot/.
Save the flag to loot/flag.txt if found.
Create writeup.md when solved.
Do not submit the flag automatically.
```

---

## Recommended model usage

For Codex:

```text
Default: use the current model.
If available, use a stronger model for harder challenges.
Use smaller/faster models for simple scripting and note cleanup.
```

Suggested approach:

```text
Initial triage: standard model
Complex reverse/pwn/crypto: stronger model
Writeup cleanup: smaller/faster model is usually fine
```

---

## Safety and scope

This setup is for authorised CTFs and lab environments only.

Do not use it against:

```text
- public systems without permission
- corporate systems outside approved scope
- other CTF participants
- unrelated HTB infrastructure
- real user accounts
- real credentials
```

Agents must not perform:

```text
- denial-of-service
- flooding
- destructive commands
- persistence
- evasion
- credential theft
- attacks outside the provided scope
```

Autonomous mode is intentionally powerful. Use it only inside isolated VMs and only for explicit challenge targets.

---

## Pwnbox notes

HTB Pwnbox may be temporary. Do not assume files or login sessions will persist.

Recommended Pwnbox flow:

```bash
git clone <your-repo-url>
cd <your-repo-name>
chmod +x setup-htb-ai-ctf.sh
./setup-htb-ai-ctf.sh
source ~/.bashrc
ctf-status
```

Then sign in:

```bash
codex
claude
gemini
agy
```

At the end of a session, export or copy:

```text
notes.md
writeup.md
loot/flag.txt
scripts/
```

---

## VMware rehearsal notes

For a local Parrot VMware rehearsal VM:

```text
Disk: 60 GB
RAM: 8 GB
CPU: 4 cores
Network: NAT
```

After install, verify:

```bash
whoami
findmnt /
df -h /
```

You want `/` mounted from `/dev/sda...`, not `overlay`.

Then run:

```bash
./setup-htb-ai-ctf.sh --with-apt
source ~/.bashrc
ctf-status
```

Take a snapshot after the setup is complete and before starting any event work.

---

## Troubleshooting

### `No space left on device`

Check:

```bash
df -h /
findmnt /
```

If `/` is `overlay`, you are likely in a live ISO session. Install the VM to disk before running `--with-apt`.

### Codex does not show local skills

Run:

```bash
sync-ctf-skills
```

Restart Codex and press:

```text
$
```

You should see skills such as:

```text
ctf-triage
web-ctf
crypto-ctf
```

### `/skills` does not work in Codex

Use:

```text
$
```

Codex uses `$` for skill selection in this setup.

### Claude does not show skills

Run:

```bash
sync-ctf-skills
```

Restart Claude:

```bash
claude
```

Then try:

```text
/ctf-triage
```

### Gemini or Antigravity is missing

They are secondary tools. Check:

```bash
ctf-status
```

If Codex and Claude are installed, the setup is usable.

### Agent solved the challenge but did not write the writeup

Run the agent again from the challenge directory and prompt:

```text
Read notes.md, scripts/, and loot/flag.txt.
Create or update writeup.md using the required writeup structure.
Make it high-level and suitable for learning.
```

### Agent found a flag but did not save it

Run:

```bash
mkdir -p loot
nano loot/flag.txt
```

Paste the flag manually, then ask the agent to update `writeup.md`.

---

## Useful commands

Status:

```bash
ctf-status
```

Create challenge:

```bash
new-ctf-challenge web name target
```

Start Codex:

```bash
codex
```

Start autonomous Codex PoC:

```bash
ctf-codex-auto
```

Start non-interactive Codex PoC:

```bash
ctf-codex-auto-exec
```

Start Claude:

```bash
claude
```

Start Gemini:

```bash
gemini
```

Start Antigravity:

```bash
agy
```

Activate Python venv:

```bash
ctf-venv
```

Check final files:

```bash
ctf-writeup-check
```

Sync skills:

```bash
sync-ctf-skills
```

---

## Suggested repository structure

```text
htb-ai-ctf-bootstrap/
  setup-htb-ai-ctf.sh
  README.md
```

Keep the repository small. The script generates the workspace, agent instructions, skills, challenge templates, and helper commands.

---

## Disclaimer

This project is for authorised CTF, lab, and training environments only. The autonomous mode is designed for isolated challenge targets and should not be used against systems without explicit permission.
