# AI Agent Skills

Personal, project-independent AI agent skills live in this repository. The repo is meant to be the editable source of truth; the installer scripts symlink skills into each agent's local skill directory so changes here are reflected immediately.

## Supported Agents

The link scripts currently support:

| Agent | Default skill directory |
| --- | --- |
| Codex | `${CODEX_HOME:-$HOME/.codex}/skills` |
| Claude Code | `${CLAUDE_HOME:-$HOME/.claude}/skills` |
| Cursor | `${CURSOR_HOME:-$HOME/.cursor}/skills-cursor` |

The scripts only add or remove skill directory symlinks. They do not edit Cursor manifests, Claude settings, Codex config, or any other agent-managed files.

## Install Skills

Preview the default Codex install:

```bash
bash scripts/link-skills.sh --dry-run
```

Preview links for every supported agent:

```bash
bash scripts/link-skills.sh --agent all --dry-run
```

Link every direct child directory that contains `SKILL.md` into all supported agents:

```bash
bash scripts/link-skills.sh --agent all
```

Link into a specific agent:

```bash
bash scripts/link-skills.sh --agent codex
bash scripts/link-skills.sh --agent claude
bash scripts/link-skills.sh --agent cursor
```

Use a different home directory when needed:

```bash
bash scripts/link-skills.sh --agent all \
  --codex-home /path/to/.codex \
  --claude-home /path/to/.claude \
  --cursor-home /path/to/.cursor
```

If an existing symlink points somewhere else, replace only that symlink:

```bash
bash scripts/link-skills.sh --agent all --force
```

The script never overwrites real files or directories. If `<agent-skill-dir>/<skill-name>` already exists as a real directory, move or back it up manually before linking.

## Uninstall Skills

Preview removal from every supported agent:

```bash
bash scripts/unlink-skills.sh --agent all --dry-run
```

Remove symlinks created from this repository:

```bash
bash scripts/unlink-skills.sh --agent all
```

Remove from one agent only:

```bash
bash scripts/unlink-skills.sh --agent codex
bash scripts/unlink-skills.sh --agent claude
bash scripts/unlink-skills.sh --agent cursor
```

`unlink-skills.sh` only removes symlinks that point back to this repository. It skips real directories and symlinks owned by another location.

## Calling Skills

After linking, restart or refresh the target agent if the skill list does not update immediately.

Codex supports explicit `$skill-name` invocation:

```text
Use $mac-diagnostics to check this Mac's storage, CPU, memory, and network health.
```

For Claude Code, Cursor, and general cross-agent prompts, refer to the skill by name:

```text
Use the mac-diagnostics skill to diagnose this Mac's storage, CPU, memory, and network.
```

Japanese prompt samples:

```text
$mac-diagnostics を使って、このMacのストレージ、CPU、メモリ、ネットワーク状態を診断して。
```

```text
mac-diagnostics skill を使って、このMacのストレージ、CPU、メモリ、ネットワーク状態を診断して。
```

```text
mac-diagnostics skill でネットワーク診断して。DNS、ルーティング、HTTP到達性を確認して。
```

```text
mac-diagnostics skill で localhost:3000 が開かない原因を調べて。
```

You can also ask naturally when the skill description matches the task:

```text
Macのストレージ、CPU、メモリの状態を診断して。
ネットが遅い原因をDNS、ルーティング、HTTP到達性から切り分けて。
localhost:3000 が開かない原因を見て。
```

## Available Skills

- `mac-diagnostics`: Diagnose Mac storage, CPU, memory, battery, thermal hints, listening ports, DNS, routing, connectivity, slow internet, and localhost issues with read-only snapshots.
