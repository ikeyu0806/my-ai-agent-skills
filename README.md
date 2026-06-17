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
mac-diagnostics skill でGoogle Meetの音声が途切れる原因をWi-Fi、DFS、VPN/DNSプロキシの観点で診断して。
```

```text
mac-diagnostics skill で localhost:3000 が開かない原因を調べて。
```

```text
$docker-cleanup を使って、Dockerの不要なcontainer/image/volume/network/build cacheを掃除する前に候補を確認して。
```

```text
$gcp-hosting-debug を使って、Cloud Run、Load Balancer、Cloud Logging、Cloud SQL PostgreSQL の状態からGCP上のWebサービス障害を切り分けて。
```

```text
$local-web-service-debug を使って、Docker Compose のログ、ブラウザのコンソール/API失敗、PostgreSQL の状態からローカルWebサービスの不具合を切り分けて。
```

```text
$gh-pr-review-ci を使って、現在のブランチのPRレビューコメントとGitHub Actionsの失敗を確認し、必要な修正をpushしてPRに返信して。
```

```text
$gh-coderabbit-command を使って、現在のブランチのPRに CodeRabbit の full review を gh で依頼して。
```

```text
$gh-ci-fix を使って、現在のPRのGitHub Actions失敗ログを gh で確認し、原因を修正してローカル検証後に結果を報告して。
```

```text
$dev-update-radar を使って、Google Ads API、Meta API、Stripe API、Auth0、Codex、Claude Code、Ghostty、Chrome、macOS の最新アップデートと package.json への影響を確認して。
```

```text
$google-ads-api-dev を使って、テストアカウントに検索キャンペーンとad group、キーワードを作成して。実行前に customer.test_account を確認して。
```

```text
$google-ads-api-dev を使って、このNestJSプロジェクトの GoogleAdsService 経由でテストアカウントにキャンペーンをcreate/updateして結果を確認して。
```

You can also ask naturally when the skill description matches the task:

```text
Macのストレージ、CPU、メモリの状態を診断して。
ネットが遅い原因をDNS、ルーティング、HTTP到達性から切り分けて。
Google Meetの音声が途切れる原因をWi-FiとDNS/VPNの観点で見て。
localhost:3000 が開かない原因を見て。
Dockerの容量が増えてきたので、安全に掃除できるcontainer、image、volume、network、build cacheを確認して。
GCP上のCloud Runサービスで500が増えているので、ログとリビジョン、Load Balancer、Cloud SQLの観点で調査して。
Docker Composeで動くローカルWebサービスの500エラーを、appログ、ブラウザログ、PostgreSQLの状態から調べて。
GitHub PRのレビュー指摘と赤いCIを確認して、直せるものは修正してpushし、レビューコメントに返信して。
現在のブランチのPRに CodeRabbit の review/full review/pause/resume/autofix/resolve などのコマンドを gh で送って。
GitHub Actions の失敗内容を gh で調べて、直せるCI failureは修正して。
普段使っているAPI、開発ツール、Chrome、macOS、npm依存関係のアップデートで対応が必要なものを調べて。
Google Adsのテストアカウントにキャンペーンを作って、GAQLで作成結果を確認して。本番アカウントには触らないで。
```

## Available Skills

- `mac-diagnostics`: Diagnose Mac storage, CPU, memory, battery, thermal hints, listening ports, DNS, routing, Wi-Fi band/channel/DFS clues, connectivity, slow internet, Meet/Zoom dropouts, and localhost issues with read-only snapshots.
- `docker-cleanup`: Inspect Docker disk usage and safely plan or run cleanup for unused containers, images, volumes, networks, system prune, builder/buildx cache, and Docker Compose resources.
- `gcp-hosting-debug`: Debug GCP-hosted web services with read-only Cloud Run, HTTP(S) Load Balancer, Cloud Logging, Cloud SQL PostgreSQL, OAuth/OIDC/Auth0, TLS, and custom domain diagnostics.
- `local-web-service-debug`: Debug local Docker Compose web services with read-only Compose logs, browser/Playwright console and network signals, HTTP probes, and bounded PostgreSQL/MySQL diagnostics.
- `gh-pr-review-ci`: Handle GitHub PR review feedback and failing GitHub Actions checks with `gh`: inspect comments and CI logs, fix actionable issues, validate locally, push, and reply on the PR.
- `gh-coderabbit-command`: Send CodeRabbit commands to the current GitHub PR with `gh`, choosing PR comments or PR body placement safely for review, full review, pause/resume, autofix, resolve, configuration, ignore, and summary placeholders.
- `gh-ci-fix`: Diagnose and fix failing GitHub Actions checks with `gh`: inspect PR checks and run logs, identify the root cause, apply scoped code or workflow fixes, validate locally, push when requested, and report updated CI status.
- `dev-update-radar`: Collect current official update information for Google Ads API, Meta APIs, Stripe API, Auth0, Codex, Claude Code, Ghostty, Chrome, macOS, and npm projects, then classify breaking changes, deprecations, security fixes, migration deadlines, and package.json impact.
- `google-ads-api-dev`: Develop and exercise Google Ads API features against a TEST account during local development — OAuth2 token minting, GAQL search, and create/update mutate via REST, or through the target project's own runtime (NestJS/TypeScript, Python, etc.) when it already integrates the API. Enforces a `customer.test_account` guardrail before any mutate.
