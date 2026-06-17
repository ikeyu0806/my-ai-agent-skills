---
name: google-ads-api-dev
description: Use when developing, testing, or exercising Google Ads API features against a Google Ads TEST account during local development. Covers OAuth2 access-token minting, REST (googleads.googleapis.com) GAQL search and create/update mutate operations for campaigns, budgets, ad groups, ads, and keywords, plus running those operations through the target project's own runtime (e.g., a NestJS/TypeScript service, a Python client) when the project already integrates the Google Ads API. The skill defaults to executing real create/update calls because the target is a non-billable test account, and enforces a test-account guardrail before any mutate.
---

# Google Ads API Dev

Develop and exercise Google Ads API features locally against a **test account**. Unlike normal cautious development, this skill is allowed to execute real `create`/`update` mutate calls — because a Google Ads test account never serves live ads and never spends money. The non-negotiable precondition is verifying the target customer really is a test account first.

## When to Use

- "Create/update a campaign (budget, ad group, ad, keyword) on my Google Ads test account."
- "Run this Google Ads API feature against the test account and show the result."
- "Use my project's GoogleAdsService to do X against the test account."
- "Exercise the GAQL query / mutate path end to end."

## Execution Strategy: Project Runtime First, REST Fallback

Decide how to execute, in this order:

1. **Project runtime (preferred when the project already integrates Google Ads).**
   Detect existing integration (see `references/runtime-adapters.md`):
   - Dependencies: `google-ads-api`, `google-ads-node`, `@google-ads/*`, `opteo/google-ads-api` (Node/TS); `google-ads` (Python); `google/ads/googleads` (PHP); etc.
   - Source modules/services that already wrap auth and the client (e.g., a NestJS `GoogleAdsService`, a repository, a usecase).
   - Existing env/config for `developer-token`, OAuth client, refresh token, `login-customer-id`.

   If found, run the feature **through the project's own runtime and code path** so you exercise the real integration: write a small one-off runner (e.g., `ts-node`/`tsx` script, a Nest standalone application context, a Jest/Vitest test, an existing CLI command, or an HTTP request to a dev endpoint) that calls the project's existing service against the **test-account** customer ID + credentials. Reuse the project's auth and client config; do not reimplement it.

2. **Bundled REST fallback (when no project integration exists, or the user wants raw REST).**
   Use the bundled scripts to talk to `https://googleads.googleapis.com` directly with `curl`. See `references/rest-api.md`. This is also the fastest way to reproduce a request/response in isolation.

Always confirm with the user which customer ID and which credentials map to the **test** environment before executing.

## Safety Rules (read before any mutate)

- **Verify test account first.** Before any `:mutate` (create/update/remove), confirm the target customer is a test account by querying `customer.test_account`. Use `scripts/verify_test_account.sh`. If it is not a test account, or the field cannot be confirmed, STOP and ask the user — do not mutate.
- **Prefer `validateOnly: true` for the first attempt** of any new mutate, then re-run with `validateOnly: false` once the request validates. (`scripts/gads_mutate.sh --validate-only`.)
- **Never print secrets.** Redact developer token, client secret, refresh/access tokens, and full `Authorization` headers in any output.
- **Scope to the test customer.** Use the explicit test customer ID for `customers/{id}` and the test manager (MCC) ID for `login-customer-id`. Call out any mismatch with the user's stated test IDs before proceeding.
- **Real billable accounts are out of scope.** If the user points this at a production/billable account, decline the mutate and explain why; read-only GAQL may still be fine if they explicitly ask.
- **`remove` is destructive even on test accounts.** Confirm the exact resource name with the user before removing.

## Quick Start

All scripts read configuration from environment variables (or a `google-ads.env` file you `source`). Required:

```bash
export GADS_DEVELOPER_TOKEN=...          # developer token (test MCC's token works for test accounts)
export GADS_CLIENT_ID=...                # OAuth2 client id
export GADS_CLIENT_SECRET=...            # OAuth2 client secret
export GADS_REFRESH_TOKEN=...            # OAuth2 refresh token for the authorized user
export GADS_LOGIN_CUSTOMER_ID=...        # test manager (MCC) id, digits only
export GADS_CUSTOMER_ID=...              # test client account id, digits only
export GADS_API_VERSION=v23              # current major; verify against release notes
```

1. Mint an access token and sanity-check auth:

```bash
bash google-ads-api-dev/scripts/gads_token.sh   # prints a short-lived access token (redact when sharing)
```

2. **Guardrail** — confirm the target is a test account:

```bash
bash google-ads-api-dev/scripts/verify_test_account.sh
# Expect customer.test_account = true; the script exits non-zero otherwise.
```

3. Read with GAQL:

```bash
bash google-ads-api-dev/scripts/gads_search.sh \
  "SELECT campaign.id, campaign.name, campaign.status FROM campaign ORDER BY campaign.id"
```

4. Create / update (validate first, then commit):

```bash
# validate only
bash google-ads-api-dev/scripts/gads_mutate.sh --validate-only campaignBudgets '{
  "operations":[{"create":{"name":"dev-budget","amountMicros":"5000000","deliveryMethod":"STANDARD"}}]
}'

# commit
bash google-ads-api-dev/scripts/gads_mutate.sh campaignBudgets '{
  "operations":[{"create":{"name":"dev-budget","amountMicros":"5000000","deliveryMethod":"STANDARD"}}]
}'
```

## Typical Workflow

1. Establish target: confirm test customer ID, test MCC `login-customer-id`, and that credentials are the test/dev set.
2. Run `verify_test_account.sh`. Do not proceed to mutate until it confirms `test_account = true`.
3. Choose execution path: project runtime (if integrated) or bundled REST. See `references/runtime-adapters.md`.
4. For a new mutate, run with `--validate-only` first, fix any field/enum errors, then commit.
5. Report what was created/updated with resource names and the GAQL you'd use to re-read it.
6. Offer cleanup (pause or remove the test resources) when done.

## References

- `references/rest-api.md` — REST base URLs, headers, OAuth token exchange, GAQL search vs searchStream, and the create/update mutate shape for budgets, campaigns, ad groups, ads (RSA), and keywords (ad group criteria), with `resourceName` / `update_mask` rules.
- `references/runtime-adapters.md` — detecting and reusing an existing project integration; concrete runners for NestJS/TypeScript, plain Node/TS, and Python; choosing the smallest safe runner.
- `references/safety.md` — the test-account model, `customer.test_account`, `validateOnly`, and redaction checklist.

## Output Pattern

- **Target**: test customer ID + login-customer-id + API version + execution path (project runtime vs REST).
- **Guardrail**: result of `verify_test_account.sh`.
- **Action**: the operation(s) performed (validate → commit), with returned resource names.
- **Verify**: a GAQL query to re-read the result.
- **Next**: cleanup options or follow-up operations; note any redacted secrets.
