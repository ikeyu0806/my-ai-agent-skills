# Codex Skills

Personal, project-independent Codex skills live in this repository. The repo is meant to be the editable source of truth; the installer scripts symlink skills into Codex so changes here are reflected immediately.

## Install Skills

Preview what will be linked:

```bash
bash scripts/link-skills.sh --dry-run
```

Link every direct child directory that contains `SKILL.md` into Codex:

```bash
bash scripts/link-skills.sh
```

By default, skills are linked into:

```text
${CODEX_HOME:-$HOME/.codex}/skills
```

Use a different Codex home when needed:

```bash
bash scripts/link-skills.sh --codex-home /path/to/.codex
```

If an existing symlink points somewhere else, replace only that symlink:

```bash
bash scripts/link-skills.sh --force
```

The script never overwrites real files or directories. If `~/.codex/skills/<skill-name>` already exists as a real directory, move or back it up manually before linking.

## Uninstall Skills

Preview removal:

```bash
bash scripts/unlink-skills.sh --dry-run
```

Remove symlinks created from this repository:

```bash
bash scripts/unlink-skills.sh
```

`unlink-skills.sh` only removes symlinks that point back to this repository. It skips real directories and symlinks owned by another location.

## Calling Skills In Codex

After linking, restart or refresh Codex if the skill list does not update immediately.

Invoke a skill explicitly with `$skill-name`:

```text
Use $mac-diagnostics to check this Mac's storage, CPU, memory, and network health.
```

Japanese prompt samples:

```text
$mac-diagnostics を使って、このMacのストレージ、CPU、メモリ、ネットワーク状態を診断して。
```

```text
$mac-diagnostics でネットワーク診断して。DNS、ルーティング、HTTP到達性を確認して。
```

```text
$mac-diagnostics で localhost:3000 が開かない原因を調べて。
```

You can also ask naturally when the skill description matches the task:

```text
Macのストレージ、CPU、メモリの状態を診断して。
ネットが遅い原因をDNS、ルーティング、HTTP到達性から切り分けて。
localhost:3000 が開かない原因を見て。
```

## Available Skills

- `mac-diagnostics`: Diagnose Mac storage, CPU, memory, battery, thermal hints, listening ports, DNS, routing, connectivity, slow internet, and localhost issues with read-only snapshots.
