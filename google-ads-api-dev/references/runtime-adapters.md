# Running through the target project's runtime

Goal: when the target project already integrates the Google Ads API, exercise the
feature **through the project's own code path and runtime** against the test
account — not via reimplemented REST calls. This validates the real integration
(auth wiring, client config, mappers, error handling) the way it runs in the app.

## 1. Detect existing integration

Search the repo for these signals before deciding the execution path.

Dependencies (package manifests):
- Node/TS: `google-ads-api` (opteo), `google-ads-node`, `@google-ads/*` in `package.json`.
- Python: `google-ads` in `pyproject.toml` / `requirements.txt`.
- Java: `com.google.api-ads:google-ads`. PHP: `googleads/google-ads-php`. Ruby: `google-ads-googleads`.

```bash
grep -RniE "google-ads-api|google-ads-node|@google-ads/|GoogleAdsApi|GoogleAdsClient|googleads" \
  --include=package.json --include=pyproject.toml --include=requirements*.txt . 2>/dev/null
```

Code & config:
```bash
grep -RniE "GoogleAds(Service|Client|Api|Repository|Module)|developer.?token|login.?customer|adwords|googleAds:search|:mutate" \
  --include=*.ts --include=*.js --include=*.py src app 2>/dev/null | head -50
# env/config keys
grep -RniE "GOOGLE_ADS|GADS_|DEVELOPER_TOKEN|LOGIN_CUSTOMER|REFRESH_TOKEN" .env* config 2>/dev/null
```

If a service/module wraps the client, **reuse it**. Reuse the project's auth/config
loading; only override the *customer id* and *credentials* to point at the test set
(e.g., a `.env.test` / `.env.local`, or env overrides on the command).

If no integration exists, use the bundled REST scripts (`references/rest-api.md`).

## 2. Pick the smallest safe runner

In order of preference:
1. **Existing CLI / npm script / management command** the project already exposes.
2. **Existing dev HTTP endpoint** (call it with `curl`) if the feature is reachable that way.
3. **A one-off script** that imports the project's service and invokes it.
4. **A test** (Jest/Vitest/pytest) tagged for manual/integration runs.

Always set the environment so the project resolves the **test** customer and the
test credentials. Confirm with the user which env file / vars map to test.

## 3. NestJS / TypeScript

Prefer a standalone application context so providers (and DI) initialize exactly
as in the app, then resolve the existing service and call it.

```ts
// scripts/gads-dev-runner.ts  (run: npx ts-node scripts/gads-dev-runner.ts  | or tsx)
import { NestFactory } from '@nestjs/core';
import { AppModule } from '../src/app.module';
import { GoogleAdsService } from '../src/google-ads/google-ads.service'; // adjust path

async function main() {
  const app = await NestFactory.createApplicationContext(AppModule, { logger: ['error', 'warn'] });
  const svc = app.get(GoogleAdsService);

  const customerId = process.env.GADS_CUSTOMER_ID!; // test client account
  // call whatever method the project exposes; example shapes:
  const campaigns = await svc.searchCampaigns(customerId);
  console.log(JSON.stringify(campaigns, null, 2));

  // mutate example — only after test-account verification:
  // const res = await svc.createCampaign(customerId, { name: 'dev-search-001', ... });
  // console.log(res);

  await app.close();
}
main().catch((e) => { console.error(e); process.exit(1); });
```

Run it pointing at the test env:

```bash
# load the project's test env, then run
set -a; source .env.test 2>/dev/null || source .env.local; set +a
npx ts-node -r tsconfig-paths/register scripts/gads-dev-runner.ts
# or, if the project uses tsx:  npx tsx scripts/gads-dev-runner.ts
```

Notes:
- If the project uses the `google-ads-api` (opteo) library, the service usually
  builds a `Customer` from `{ customer_id, login_customer_id, refresh_token }`
  plus a `GoogleAdsApi({ client_id, client_secret, developer_token })`. Reuse the
  project's factory; just feed the test ids.
- Match the project's path aliases (`tsconfig-paths`) and module system. If it's
  ESM, use `tsx` or `node --loader`.
- Keep the runner under the repo's existing `scripts/` if one exists; otherwise a
  temporary file is fine — offer to delete it after.

## 4. Plain Node / TypeScript (no Nest)

```ts
import { GoogleAdsApi } from 'google-ads-api';
const client = new GoogleAdsApi({
  client_id: process.env.GADS_CLIENT_ID!,
  client_secret: process.env.GADS_CLIENT_SECRET!,
  developer_token: process.env.GADS_DEVELOPER_TOKEN!,
});
const customer = client.Customer({
  customer_id: process.env.GADS_CUSTOMER_ID!,
  login_customer_id: process.env.GADS_LOGIN_CUSTOMER_ID!,
  refresh_token: process.env.GADS_REFRESH_TOKEN!,
});
const rows = await customer.query(`SELECT campaign.id, campaign.name FROM campaign`);
console.log(rows);
```

## 5. Python

```python
# uses google-ads.yaml or GOOGLE_ADS_* env vars
from google.ads.googleads.client import GoogleAdsClient
client = GoogleAdsClient.load_from_env()  # or load_from_storage("google-ads.yaml")
ga = client.get_service("GoogleAdsService")
resp = ga.search(customer_id=os.environ["GADS_CUSTOMER_ID"],
                 query="SELECT campaign.id, campaign.name FROM campaign")
for row in resp:
    print(row.campaign.id, row.campaign.name)
```

## 6. Guardrail still applies

Whichever runtime you use, the **test-account check comes first**. Either:
- run `scripts/verify_test_account.sh` (REST) before the project runner, or
- have the project runner query `customer.test_account` and assert it is `true`
  before any mutate.

Never run create/update through the project runtime against a customer you have
not confirmed is a test account.
