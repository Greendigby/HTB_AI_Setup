HTB AI CTF Bootstrap

A bootstrap script for preparing a Parrot OS, Kali-like, or Hack The Box Pwnbox environment for AI-assisted Capture the Flag work using:

- OpenAI Codex CLI
- Claude Code
- Gemini CLI
- Google Antigravity CLI

The setup creates a repeatable CTF workspace, installs common tooling, prepares reusable CTF skills, and provides helper commands for challenge intake, agent launch, autonomous solving, retries, traking, and completion checks.

This is intended for authorised CTFs, training labs, and Hack The Box-style challenge environments.

---

What this provides

The script creates the main workspace:

~/ctf-event/
  _index/
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

It also creates user-level skill directories:

~/.agents/skills/
~/.claude/skills/

And helper commands:

ctf-status
ctf-venv
ctf-intake
ctf-start
ctf-board
ctf-finish
ctf-writeup-check
new-ctf-challenge
sync-ctf-skills
ctf-codex-auto
ctf-codex-auto-exec

The old "new-ctf-challenge" helper is still available for compatibility, but the preferred workflow is now "ctf-intake".

---

Supported AI tools

Codex CLI

Recommended for fast autonomous or semi-autonomous challenge solving.

Use Codex when you want the agent to:

- inspect a challenge directory
- analyse provided files
- interact with an explicitly scoped CTF target
- create helper scripts
- save artefacts
- save the flag to "loot/flag.txt"
- generate or update "writeup.md"

Codex uses:

AGENTS.md
~/.agents/skills/
~/ctf-event/.agents/skills/

In Codex, skills are selected using:

$

not "/".

---

Claude Code

Recommended for deeper reasoning, harder challenges, and skills-first workflows.

Use Claude Code when you want:

- slash-command style skills
- stronger long-form challenge reasoning
- structured project-context use
- careful multi-step analysis
- good retry behaviour after another agent stalls

Claude Code uses:

CLAUDE.md
~/.claude/skills/
~/ctf-event/.claude/skills/

In Claude Code, skills are selected using slash commands, for example:

/ctf-triage
/web-ctf
/crypto-ctf
/reverse-ctf
/pwn-ctf

---

Gemini CLI / Antigravity

Useful as second-opinion agents or fallback solvers.

Use Gemini or Antigravity when:

- Codex or Claude gets stuck
- you want another model to review "notes.md"
- you want alternative hypotheses
- you want scripts or writeups reviewed
- you want to retry a challenge without trusting the previous agent’s assumptions

Gemini and Antigravity use:

GEMINI.md

as project context.

---

Included CTF skills

The script pre-populates these skills for Codex and Claude:

ctf-triage
web-ctf
crypto-ctf
reverse-ctf
pwn-ctf
forensics-ctf
misc-ctf
osint-ctf
ai-jailbreak-ctf

Skill coverage

Skill| Use for
"ctf-triage"| Initial classification, notes setup, methodology selection
"web-ctf"| HTTP services, APIs, auth flaws, injection, XXE, file read, SSTI, uploads
"crypto-ctf"| Encodings, XOR, RSA, AES misuse, weak randomness, signatures, custom crypto
"reverse-ctf"| Binaries, static analysis, strings, check logic, packed files
"pwn-ctf"| Binary exploitation, pwntools, ret2win, ROP, format strings
"forensics-ctf"| PCAPs, images, archives, metadata, stego, file carving
"misc-ctf"| Raw TCP services, puzzles, restricted shells, custom protocols
"osint-ctf"| Public clues, metadata, geolocation, usernames, timestamps
"ai-jailbreak-ctf"| Prompt-injection / AI-jailbreak style CTF challenges

Each skill instructs the agent to:

- stay inside the explicitly provided challenge scope
- keep notes in "notes.md"
- create scripts under "scripts/"
- save artefacts under "loot/" or "scans/"
- save the flag to "loot/flag.txt"
- create or update "writeup.md" when complete

---

Prerequisites

Recommended environment:

Parrot OS, Kali, or HTB Pwnbox
8 GB RAM preferred
20 GB+ free disk preferred
Internet access for agent login and package installation

For a local VMware test VM, use:

Disk: 60 GB
RAM: 8 GB
CPU: 4 cores
Network: NAT

Before running with apt installation enabled, check:

df -h /
findmnt /

Do not run "--with-apt" if "/" is mounted as "overlay", because that usually means you are in a live ISO environment with limited temporary storage.

---

Installation

Clone your repository:

git clone <your-repo-url>
cd <your-repo-name>
chmod +x setup-htb-ai-ctf.sh

Full install on an installed VM

Use this on an installed Parrot/Kali VM with enough disk space:

./setup-htb-ai-ctf.sh --with-apt
source ~/.bashrc
ctf-status

Lightweight install on HTB Pwnbox

Use this if Pwnbox already has most tools installed or disk space is limited:

./setup-htb-ai-ctf.sh
source ~/.bashrc
ctf-status

Verify installation

Run:

ctf-status

Expected output should show at least:

codex:  found
claude: found
python3: found
jq: found
npm: found
tmux: found

Gemini and Antigravity are useful but optional.

---

First-time agent login

Run each tool once and sign in when prompted.

Codex

codex

Sign in with your ChatGPT account, then exit.

Claude Code

claude

Sign in with your Claude account, then exit.

Gemini CLI

gemini

Sign in with your Google/Gemini account, then exit.

Antigravity

agy

Sign in with your Google/Gemini account, then exit.

---

Recommended workflow

The intended live workflow is:

1. Open the challenge in Hack The Box.
2. Copy the challenge name, category, difficulty, description, target, and file links.
3. Use your ChatGPT Project to generate the ctf-intake command and agent prompts.
4. Paste the generated ctf-intake command into Pwnbox.
5. Start the chosen agent with ctf-start.
6. If one agent fails, retry with another agent using the same challenge workspace.
7. Track challenges with ctf-board.
8. Finish with ctf-finish.

The ChatGPT Project is used only as a prompt-pack generator. The actual challenge solving is done locally by Codex, Claude, Gemini, or Antigravity inside the Pwnbox/VM workspace.

---

Challenge workspace structure

Each challenge created by "ctf-intake" has this structure:

~/ctf-event/challenges/<category>/<challenge-slug>/
  challenge.yaml
  original_prompt.md
  notes.md
  AGENTS.md
  CLAUDE.md
  GEMINI.md
  writeup.md
  run_codex_auto_prompt.txt

  files/
    extracted/

  scripts/
  loot/
  scans/
  tmp/

  prompts/
    codex_auto.txt
    codex_interactive.txt
    claude_solve.txt
    gemini_solve.txt
    gemini_review.txt
    retry_fresh.txt
    retry_handoff.txt

  agent_runs/
    codex/
    claude/
    gemini/
    agy/

Key files

File| Purpose
"challenge.yaml"| Central metadata: name, category, difficulty, target, file URLs, status
"original_prompt.md"| Original HTB challenge details exactly as supplied
"notes.md"| Shared working notes used by all agents
"AGENTS.md"| Local Codex instructions
"CLAUDE.md"| Local Claude Code instructions
"GEMINI.md"| Local Gemini / Antigravity instructions
"writeup.md"| Final high-level learning writeup
"prompts/"| Agent-specific prompt files
"agent_runs/"| Per-agent run folders for retries and tracking
"loot/flag.txt"| Final flag location

---

Creating a challenge with "ctf-intake"

The preferred way to create a challenge is "ctf-intake".

Basic example

ctf-intake \
  --category web \
  --difficulty easy \
  --name "Jailbreak" \
  --target "154.57.164.79:31790" <<'EOF'
Paste the Hack The Box challenge description here.
EOF

Example with scenario file

ctf-intake \
  --category misc \
  --difficulty medium \
  --name "TunnelMadness" \
  --target "154.57.164.74:31353" \
  --url 'https://ctf.hackthebox.com/challenges/example/download?...' <<'EOF'
Paste the Hack The Box challenge description here.
EOF

"ctf-intake" will:

- create the challenge folder
- save the original challenge details
- create "challenge.yaml"
- create shared agent context files
- create prompt files for Codex, Claude, Gemini, and retries
- download scenario files if URLs are provided
- extract common archive formats where possible
- generate an initial file inventory

After intake:

cd ~/ctf-event/challenges/<category>/<challenge-slug>

---

Starting agents with "ctf-start"

The preferred way to launch agents is "ctf-start".

From inside a challenge folder:

ctf-start codex
ctf-start codex-auto
ctf-start codex-exec
ctf-start claude
ctf-start gemini
ctf-start gemini-review
ctf-start agy
ctf-start agy-review

You can also start an agent from anywhere by passing the challenge reference:

ctf-start codex-auto web/jailbreak
ctf-start claude pwn/hard-binary
ctf-start gemini-review misc/tunnelmadness

"ctf-start" will:

- resolve the challenge folder
- create a timestamped run directory under "agent_runs/<agent>/"
- copy the relevant prompt into that run directory
- show the prompt where needed
- start the requested agent

---

Codex workflows

Codex interactive mode

From a challenge directory:

ctf-start codex

This starts Codex interactively and prints the prepared prompt from:

prompts/codex_interactive.txt

Inside Codex, press:

$

to select a skill such as:

ctf-triage
web-ctf
crypto-ctf
reverse-ctf
pwn-ctf
forensics-ctf
misc-ctf
ai-jailbreak-ctf

Codex autonomous mode

From a challenge directory:

ctf-start codex-auto

or:

ctf-codex-auto

This launches Codex using the prepared autonomous prompt from:

prompts/codex_auto.txt

It uses:

--sandbox danger-full-access
--ask-for-approval never

Use this mode only inside the isolated CTF VM/Pwnbox and only for the explicitly provided challenge scope.

Codex non-interactive exec mode

From a challenge directory:

ctf-start codex-exec

or:

ctf-codex-auto-exec

This runs Codex as a one-shot non-interactive job.

Use this when you want a cleaner PoC run and do not need to interact with the agent while it works.

---

Claude Code workflow

From a challenge directory:

ctf-start claude

This starts Claude Code and prints the prepared prompt from:

prompts/claude_solve.txt

Claude can use slash skills such as:

/ctf-triage
/web-ctf
/crypto-ctf
/reverse-ctf
/pwn-ctf
/forensics-ctf
/misc-ctf
/ai-jailbreak-ctf

Claude is recommended for:

hard or very hard challenges
reverse engineering
pwn
complex crypto
multi-step reasoning
fallback after Codex stalls

---

Gemini workflow

From a challenge directory:

ctf-start gemini

This starts Gemini and prints the prompt from:

prompts/gemini_solve.txt

Gemini is useful for:

second opinion
reviewing failed Codex or Claude attempts
checking assumptions
alternative hypotheses
script review
writeup review

For review mode:

ctf-start gemini-review

This uses:

prompts/gemini_review.txt

---

Antigravity workflow

From a challenge directory:

ctf-start agy

For review mode:

ctf-start agy-review

Antigravity uses the Gemini-style prompts and "GEMINI.md" context.

---

Retry workflows

If one agent fails, use the same challenge workspace and retry with another agent.

Fresh retry

Use this when you want the new agent to start from the original challenge information and verify everything independently.

ctf-start claude-retry-fresh
ctf-start gemini-retry-fresh
ctf-start codex-retry-fresh

The fresh retry prompt is stored at:

prompts/retry_fresh.txt

Handoff retry

Use this when the previous agent made useful progress and the next agent should continue from existing evidence.

ctf-start claude-retry-handoff
ctf-start gemini-retry-handoff
ctf-start codex-retry-handoff

The handoff prompt is stored at:

prompts/retry_handoff.txt

The retry prompts instruct agents to read:

challenge.yaml
original_prompt.md
notes.md
writeup.md
scripts/
loot/
scans/
agent_runs/

---

Tracking active challenges

Use:

ctf-board

This scans challenge folders and shows a central board with:

Challenge
Category
Difficulty
Target
Status
Flag
Writeup
Path

Example:

Challenge                    Category     Difficulty Target                   Status     Flag   Writeup  Path
---------                    --------     ---------- ------                   ------     ----   -------  ----
Jailbreak                    web          easy       154.57.164.79:31790     solved     yes    done     web/jailbreak
TunnelMadness                misc         medium     154.57.164.74:31353     created    no     draft    misc/tunnelmadness

This is useful when running multiple terminal sessions for different challenges.

---

Completion requirements

Every solved challenge should end with:

loot/flag.txt
writeup.md
notes.md
scripts/solve.py or equivalent, where practical

Check completion with:

ctf-finish

or the compatibility wrapper:

ctf-writeup-check

If "loot/flag.txt" exists and "writeup.md" has no "Pending" markers, "ctf-finish" updates "challenge.yaml" to:

status: "solved"

---

Writeup format

Each challenge writeup uses this structure:

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

The goal is a high-level learning writeup, not just a raw terminal transcript.

---

Example: Codex autonomous challenge

Create the challenge:

ctf-intake \
  --category web \
  --difficulty easy \
  --name "Jailbreak" \
  --target "154.57.164.79:31790" <<'EOF'
Paste Hack The Box challenge description here.
EOF

Start Codex:

cd ~/ctf-event/challenges/web/jailbreak
ctf-start codex-auto

After completion:

ctf-finish
cat loot/flag.txt
sed -n '1,220p' writeup.md

---

Example: Claude-led challenge

Create the challenge:

ctf-intake \
  --category pwn \
  --difficulty hard \
  --name "Hard Binary" \
  --target "154.57.164.80:31000" \
  --url 'https://ctf.hackthebox.com/challenges/example/download?...' <<'EOF'
Paste Hack The Box challenge description here.
EOF

Start Claude:

cd ~/ctf-event/challenges/pwn/hard-binary
ctf-start claude

If Claude gets stuck and you want Gemini to review:

ctf-start gemini-review

---

Example: Gemini fallback after Codex

If Codex has attempted the challenge but did not solve it:

cd ~/ctf-event/challenges/misc/tunnelmadness
ctf-start gemini-retry-handoff

If you want Gemini to restart independently:

ctf-start gemini-retry-fresh

---

Recommended agent usage

Codex

Use Codex first for:

easy/medium challenges
web challenges
misc challenges
scripting-heavy challenges
API or HTTP interaction
file parsing
automation
quick PoC solving

Claude Code

Use Claude first for:

hard/very hard challenges
reverse engineering
pwn
complex crypto
multi-step logic
source code reasoning
where careful planning matters

Gemini

Use Gemini for:

second opinion
reviewing failed Codex or Claude attempts
finding bad assumptions
summarising notes
alternative hypotheses
checking scripts and writeups
fallback when another agent stalls

Antigravity

Use Antigravity for:

alternative Google-side agent workflow
broader project-context review
another fallback path

---

ChatGPT Project integration

The recommended event workflow uses a separate ChatGPT Project as a prompt-pack generator.

That project should not solve the challenge itself. It should only generate:

ctf-intake command
Codex prompt
Claude Code prompt
Gemini / Antigravity prompt
fresh retry prompt
handoff retry prompt
quick commands

Then paste the generated "ctf-intake" command into Pwnbox.

The local agents then perform the challenge work inside the generated challenge folder.

---

Scope and authorisation

This setup is for authorised CTF, lab, and training environments.

Generated prompts and agent guidance use this scope model:

This is authorised Hack The Box / CTF work.

Work only inside the current challenge workspace.

Only operate against the explicitly provided challenge scope, including the supplied target, files, URLs, ports, and challenge artefacts.

Use any challenge-relevant technique where it is appropriate to the provided HTB/CTF scenario and consistent with the event rules.

Keep notes, scripts, artefacts, flags, and writeups inside the challenge folder.

Autonomous mode is intentionally powerful. Use it only inside an isolated VM/Pwnbox and only for explicit challenge targets.

---

Pwnbox notes

HTB Pwnbox may be temporary. Do not assume files or login sessions will persist.

Recommended Pwnbox flow:

git clone <your-repo-url>
cd <your-repo-name>
chmod +x setup-htb-ai-ctf.sh
./setup-htb-ai-ctf.sh
source ~/.bashrc
ctf-status

Then sign in:

codex
claude
gemini
agy

At the end of a session, export or copy:

challenge.yaml
original_prompt.md
notes.md
writeup.md
loot/flag.txt
scripts/
agent_runs/

---

VMware rehearsal notes

For a local Parrot VMware rehearsal VM:

Disk: 60 GB
RAM: 8 GB
CPU: 4 cores
Network: NAT

After install, verify:

whoami
findmnt /
df -h /

You want "/" mounted from "/dev/sda...", not "overlay".

Then run:

./setup-htb-ai-ctf.sh --with-apt
source ~/.bashrc
ctf-status

Take a snapshot after the setup is complete and before starting any event work.

---

Troubleshooting

"No space left on device"

Check:

df -h /
findmnt /

If "/" is "overlay", you are likely in a live ISO session. Install the VM to disk before running "--with-apt".

---

Codex does not show local skills

Run:

sync-ctf-skills

Restart Codex and press:

$

You should see skills such as:

ctf-triage
web-ctf
crypto-ctf

---

"/skills" does not work in Codex

Use:

$

Codex uses "$" for skill selection in this setup.

---

Claude does not show skills

Run:

sync-ctf-skills

Restart Claude:

claude

Then try:

/ctf-triage

---

Gemini or Antigravity is missing

They are secondary tools. Check:

ctf-status

If Codex and Claude are installed, the setup is usable.

---

Agent solved the challenge but did not write the writeup

Run the relevant agent again from the challenge directory and prompt it to update the writeup:

Read challenge.yaml, original_prompt.md, notes.md, scripts/, and loot/flag.txt.
Create or update writeup.md using the required writeup structure.
Make it high-level and suitable for learning.

---

Agent found a flag but did not save it

Run:

mkdir -p loot
nano loot/flag.txt

Paste the flag manually, then ask the agent to update "writeup.md".

---

"ctf-start" cannot find a challenge

Check your challenge path:

find ~/ctf-event/challenges -name challenge.yaml -type f

Then start with a relative challenge reference:

ctf-start codex-auto web/jailbreak

Or move into the challenge folder and start without a reference:

cd ~/ctf-event/challenges/web/jailbreak
ctf-start codex-auto

---

Useful commands

Status:

ctf-status

Create challenge:

ctf-intake --category web --difficulty easy --name "Name" --target "1.2.3.4:1234"

Legacy create command:

new-ctf-challenge web name target

Start Codex interactive:

ctf-start codex

Start Codex autonomous:

ctf-start codex-auto

Start Codex non-interactive:

ctf-start codex-exec

Start Claude:

ctf-start claude

Start Gemini:

ctf-start gemini

Start Gemini review:

ctf-start gemini-review

Start Antigravity:

ctf-start agy

Fresh retry:

ctf-start claude-retry-fresh
ctf-start gemini-retry-fresh
ctf-start codex-retry-fresh

Handoff retry:

ctf-start claude-retry-handoff
ctf-start gemini-retry-handoff
ctf-start codex-retry-handoff

Challenge board:

ctf-board

Activate Python venv:

ctf-venv

Check completion:

ctf-finish

Sync skills:

sync-ctf-skills

---

Suggested repository structure

htb-ai-ctf-bootstrap/
  setup-htb-ai-ctf.sh
  README.md

Keep the repository small. The script generates the workspace, agent instructions, skills, challenge templates, prompt files, and helper commands.

---

Disclaimer

This project is for authorised CTF, lab, and training environments only. Autonomous mode is designed for isolated challenge targets and should not be used against systems without explicit permission.
