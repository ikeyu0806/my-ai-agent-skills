# npm Project Checks

Use `scripts/inspect_package.py` first. It is read-only, does not call the network, and stops parent-directory search at the nearest Git repository root.

```bash
python3 dev-update-radar/scripts/inspect_package.py .
```

Then choose package-manager commands based on the project.

## Read-Only Version Checks

Use the declared manager from `package.json#packageManager` when present. These commands may access the network but should not modify files:

```bash
npm outdated --json --long
npm view PACKAGE version time dist-tags repository homepage bugs --json
```

```bash
pnpm outdated --format json
pnpm view PACKAGE version time dist-tags repository homepage bugs --json
```

```bash
yarn npm info PACKAGE --json
yarn npm audit --recursive --json
```

Avoid package-manager commands that update lockfiles or install packages unless the user explicitly asks for upgrades.

## What to Inspect

- `packageManager`, lockfile type, and Node engine range.
- Direct dependencies in `dependencies`, `devDependencies`, `peerDependencies`, and `optionalDependencies`.
- API SDKs and CLIs matching the source map: Stripe, Auth0, Google Ads, Meta, Codex, Claude Code, Playwright/Puppeteer/Chrome tooling, Electron/macOS tooling.
- Explicit API version constants in code after dependency scan points to a target:
  - Stripe: `Stripe-Version`, `apiVersion`, webhook endpoint versions.
  - Google Ads: `v\d+`, `GoogleAdsClient`, service version imports.
  - Meta: `v\d+\.\d+`, Graph API URLs, Marketing API SDK usage.
  - Auth0: tenant domain, SDK major versions, Rules/Hooks/Actions references, callback/logout URL handling.
  - Chrome: Playwright/Puppeteer browser revisions, CI images, extension manifest version.

## Upgrade Assessment

For each matched package:

1. Compare installed or ranged version with latest package metadata.
2. Check release notes/changelog for every major version jump.
3. Confirm whether the project uses the affected surface before recommending code changes.
4. Call out peer dependency and Node engine changes.
5. Separate package upgrade work from external vendor dashboard/API-version work.

## Safe Output

Do not print `.env` values, tokens, private registry credentials, auth cookies, or full lockfile contents. It is safe to print package names, semver ranges, lockfile names, package-manager name, and non-secret source URLs.
