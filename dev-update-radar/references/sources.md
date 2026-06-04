# Official Source Map

Use these as starting points for current update checks. Prefer exact vendor pages over search snippets. If a page is blocked or incomplete, search the same vendor domain for the product name plus `changelog`, `release notes`, `deprecation`, `migration`, `sunset`, `security`, or the version number.

## API and Platform Sources

### Google Ads API

- Release notes: https://developers.google.com/google-ads/api/docs/release-notes
- Deprecation and sunset dates: https://developers.google.com/google-ads/api/docs/sunset-dates
- Migration guides: https://developers.google.com/google-ads/api/docs/migration
- Ads Developers Blog: https://ads-developers.googleblog.com/

Check release notes and sunset dates together. Google Ads API changes often require a version migration even when client libraries still install cleanly.

### Meta APIs

- Graph API changelog: https://developers.facebook.com/docs/graph-api/changelog
- Graph API changelog versions: https://developers.facebook.com/docs/graph-api/changelog/versions
- Graph API breaking changes: https://developers.facebook.com/docs/graph-api/changelog/breaking-changes
- Marketing API changelog: https://developers.facebook.com/docs/marketing-api/changelog
- Meta for Developers blog: https://developers.facebook.com/blog/
- Meta platform status: https://metastatus.com/

For Meta, check Graph API and Marketing API separately. Pay attention to versioned Graph API changes, non-versioned breaking changes, permissions, review requirements, metrics deprecations, webhooks, and Marketing API campaign/ad object behavior.

### Stripe

- API changelog: https://docs.stripe.com/changelog
- API upgrades: https://docs.stripe.com/upgrades
- SDK versioning and support policy: https://docs.stripe.com/sdks/versioning
- Stripe status: https://status.stripe.com/
- Stripe npm package: https://www.npmjs.com/package/stripe
- Stripe Node SDK changelog: https://github.com/stripe/stripe-node/blob/master/CHANGELOG.md

Check account API version, explicit `Stripe-Version` headers, webhook versions, SDK major versions, Checkout/Billing/Connect usage, and rollback windows.

### Auth0

- Auth0 changelog: https://auth0.com/changelog
- Deprecations and migrations: https://auth0.com/docs/troubleshoot/product-lifecycle/deprecations-and-migrations
- Product lifecycle: https://auth0.com/docs/troubleshoot/product-lifecycle
- Migration process: https://auth0.com/docs/troubleshoot/product-lifecycle/migration-process
- Auth0 status: https://status.auth0.com/

Prioritize authentication flow changes, SDK major versions, tenant migration toggles, Rules/Hooks/Actions lifecycle, callback URL behavior, OAuth/OIDC security changes, cipher/TLS requirements, and dashboard/API deprecations.

## Developer Tool Sources

### Codex

- Codex docs: https://developers.openai.com/codex
- Codex changelog: https://developers.openai.com/codex/changelog
- Codex models: https://developers.openai.com/codex/models
- OpenAI Help Center release notes: https://help.openai.com/en/articles/6825453-chatgpt-release-notes
- Codex npm package: https://www.npmjs.com/package/@openai/codex

Check CLI, IDE extension, app, model availability, authentication, sandboxing, automation, local environment, and managed configuration changes separately.

### Claude Code

- Claude Code changelog: https://code.claude.com/docs/en/changelog
- Claude Code docs: https://docs.anthropic.com/en/docs/claude-code
- Anthropic release notes: https://docs.anthropic.com/en/release-notes/overview
- Claude Code npm package: https://www.npmjs.com/package/@anthropic-ai/claude-code

Check CLI version, SDK changes, model defaults, permissions, sandboxing, hooks, MCP, settings, enterprise controls, and security fixes.

### Ghostty

- Ghostty release notes: https://ghostty.org/docs/install/release-notes
- Ghostty docs: https://ghostty.org/docs
- Ghostty releases: https://github.com/ghostty-org/ghostty/releases

Check terminal behavior changes, config key changes, macOS-specific issues, shell integration, font/rendering changes, and update channels.

## OS and Browser Sources

### Chrome

- Chrome release notes: https://developer.chrome.com/release-notes
- Chrome Releases blog: https://chromereleases.googleblog.com/
- Chrome Platform Status roadmap: https://chromestatus.com/roadmap
- Chrome for Developers blog: https://developer.chrome.com/blog

Check Stable and Beta notes, web platform deprecations/removals, DevTools changes, extension platform changes, security fixes, automation/headless changes, and features that affect CI browser tests.

### macOS

- Apple Developer releases: https://developer.apple.com/news/releases/
- macOS release notes: https://developer.apple.com/documentation/macos-release-notes
- Apple security releases: https://support.apple.com/100100
- Apple Platform Security: https://support.apple.com/guide/security/welcome/web

Check security updates, Xcode/Command Line Tools compatibility, notarization/signing changes, shell/runtime behavior, browser/WebKit coupling, and hardware support.

## Package Ecosystem Sources

- npm package metadata: `npm view PACKAGE version time dist-tags repository homepage bugs --json`
- npm outdated: `npm outdated --json --long`
- pnpm outdated: `pnpm outdated --format json`
- Yarn npm info: `yarn npm info PACKAGE --json`
- GitHub releases or changelog from package `repository` metadata

Do not treat a package major version as actionable by itself. Confirm breaking changes from the package changelog, release notes, migration guide, or vendor docs.
