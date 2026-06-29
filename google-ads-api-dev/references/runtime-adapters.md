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
# DB-backed account/token metadata
grep -RniE "GoogleAdsAccount|GoogleOAuthAccount|customerId|isTestAccount|parentMccId|encryptedRefreshToken|defaultGoogleAdsAccountId" \
  --include=*.prisma --include=*.ts --include=*.js --include=*.py prisma src app 2>/dev/null | head -80
```

If a service/module wraps the client, **reuse it**. Reuse the project's auth/config
loading; only override the *customer id* and *credentials* to point at the test set
(e.g., a `.env.test` / `.env.local`, or env overrides on the command).

If no integration exists, use the bundled REST scripts (`references/rest-api.md`).

## 2. Pre-implementation connectivity probe: env + PostgreSQL

When implementing a backend feature and the project already has env + PostgreSQL
data for Google Ads, prove connectivity before production-code edits:

1. Load the project's normal local/dev env the same way its backend does. Confirm
   required keys are present by name only: developer token, OAuth client config or
   service-account auth, DB URL, encryption key if refresh tokens are encrypted,
   and manager/login customer id if the app uses one.
2. Discover the account row through the existing ORM/repository, or a narrow
   read-only query. Select only non-secret fields such as tenant id, app account
   id, Google Ads customer id, parent MCC id, provisioning source, account type,
   status, currency, and `isTestAccount`. Do not select or print encrypted token
   blobs unless the existing service needs them internally.
3. Choose a test account explicitly. Prefer `isTestAccount = true` or a user-
   supplied tenant/account id. If only billable accounts are present, stop before
   any mutate; read-only GAQL is acceptable only if the user asked for it.
4. Run a read-only GAQL call through the existing service/client:

```sql
SELECT customer.id, customer.descriptive_name, customer.test_account, customer.manager
FROM customer
LIMIT 1
```

5. Treat the probe result as the first implementation fact:
   - success means auth, token decryption/refresh, login-customer-id, API version,
     and customer scope are wired well enough to build on;
   - failure means fix or report the concrete config/auth/account blocker before
     implementing behavior that depends on the API.

Keep the runner temporary unless the project already has a dev-script location
where integration probes belong.

### If PostgreSQL is unreachable

Do not stop at "DB host is unreachable" when the env keys are present. First
identify where the preflight is running and whether the DB hostname is valid in
that network namespace.

Common failure:
- `DATABASE_URL` uses host `db`.
- `db` resolves inside the Docker Compose network.
- `db` does not resolve from the Mac host shell.
- Host-shell preflight then fails with errors such as `getaddrinfo ENOTFOUND db`.

For DB connectivity failures, collect only read-only, non-secret diagnostics:

1. Execution target: Mac host shell, backend container, or worker/job container.
2. Exact command that failed.
3. Masked DB env only: `DATABASE_URL` / `DIRECT_URL` / Prisma DB env with
   password replaced by `[REDACTED]`; keep host, port, database, and user visible.
4. `docker compose config --services`
5. `docker compose ps -a`
6. `docker compose port db 5432`
7. `docker compose logs --no-color --tail 100 db`
8. Full error text, because `ENOTFOUND`, `ECONNREFUSED`, and auth failures imply
   different fixes.

Then choose the execution context:
- If running from the host shell and DB host is `db`, either run the preflight
  inside the backend/worker container, or override the DB URL to the host-
  published port from `docker compose port db 5432` (usually `localhost:<port>`).
- If running inside a Compose service, keep the Compose service hostname
  (`db`) and container port (`5432`).
- If DB logs show startup/auth/migration problems, fix those before retrying
  Google Ads GAQL; the Google Ads API path has not been exercised yet.

Never paste raw `.env.local` or unmasked credentials into the response. Show only
masked DB URLs and service names/statuses.

#### CAS Marketing On DB context

For `~/workspace/cas-marketing-on`, expect a NestJS backend with Docker Compose
PostgreSQL. In this project, `db:5432` is the container-network address, while
host-shell commands typically need the Compose-published host port (documented
locally as `localhost:5433` when using the default setup). Prefer one of these:

- run the Nest preflight runner inside the backend container using the existing
  container env and `db:5432`;
- run from the host shell with a host-reachable `DATABASE_URL` that points at
  `localhost:<published-db-port>`.

Only after the Prisma/account lookup works should the runner proceed to the
read-only `googleAds:search` request.

### Example: CAS Marketing On (`~/workspace/cas-marketing-on`)

Observed shape:
- backend is NestJS/TypeScript with Prisma/PostgreSQL;
- env examples include `DATABASE_URL`, `GCP_CLIENT_ID`, `GCP_CLIENT_SECRET`,
  `GOOGLE_ADS_DEVELOPER_TOKEN`, `GOOGLE_ADS_MANAGER_CUSTOMER_ID`,
  `GOOGLE_ADS_SERVICE_ACCOUNT_KEY_FILE`, and `ENCRYPTION_KEY`;
- account data lives in Prisma models like `GoogleAdsAccount` and
  `GoogleOAuthAccount`; `Tenant.defaultGoogleAdsAccountId` can identify the
  default delivery account;
- the existing API path is `GoogleAdsClientService.callGoogleAdsAPI(...)`.

A probe should therefore resolve the real Nest provider and let the app decrypt
tokens / resolve service-account auth internally. Example shape, to adapt to the
current codebase:

```ts
import 'dotenv/config';
import { NestFactory } from '@nestjs/core';
import { AppModule } from '../src/app.module';
import { prisma } from '../src/lib/prisma';
import { GoogleAdsClientService } from '../src/features/google-ads/client';

async function main() {
  const explicitTenantId = process.env.GADS_TENANT_ID;
  const explicitAccountId = process.env.GADS_GOOGLE_ADS_ACCOUNT_ID;

  const account = explicitAccountId
    ? await prisma.googleAdsAccount.findFirst({
        where: { id: explicitAccountId, tenantId: explicitTenantId },
        select: { id: true, tenantId: true, customerId: true, isTestAccount: true },
      })
    : await prisma.googleAdsAccount.findFirst({
        where: { isTestAccount: true },
        select: { id: true, tenantId: true, customerId: true, isTestAccount: true },
        orderBy: { updatedAt: 'desc' },
      });

  if (!account) throw new Error('No Google Ads test account row found');

  const app = await NestFactory.createApplicationContext(AppModule, {
    logger: ['error', 'warn'],
  });
  try {
    const client = app.get(GoogleAdsClientService);
    const result = await client.callGoogleAdsAPI(
      account.tenantId,
      account.id,
      'googleAds:search',
      'POST',
      {
        query:
          'SELECT customer.id, customer.descriptive_name, customer.test_account, customer.manager FROM customer LIMIT 1',
      },
      { allowInactiveOrNonJpy: true },
    );
    console.log(JSON.stringify({ account, result }, null, 2));
  } finally {
    await app.close();
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
```

Run it with the backend's local env loaded. Do not print `.env.local`, encrypted
refresh-token columns, service-account JSON, access tokens, or authorization
headers. If the selected row has `isTestAccount = false`, do not use it for
autonomous mutate even if the read-only probe succeeds.

## 3. Pick the smallest safe runner

In order of preference:
1. **Existing CLI / npm script / management command** the project already exposes.
2. **Existing dev HTTP endpoint** (call it with `curl`) if the feature is reachable that way.
3. **A one-off script** that imports the project's service and invokes it.
4. **A test** (Jest/Vitest/pytest) tagged for manual/integration runs.

Always set the environment so the project resolves the **test** customer and the
test credentials. Confirm with the user which env file / vars map to test.

## 4. NestJS / TypeScript

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

## 5. Plain Node / TypeScript (no Nest)

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

## 6. Python

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

## 7. Guardrail still applies

Whichever runtime you use, the **test-account check comes first**. Either:
- run `scripts/verify_test_account.sh` (REST) before the project runner, or
- have the project runner query `customer.test_account` and assert it is `true`
  before any mutate.

Never run create/update through the project runtime against a customer you have
not confirmed is a test account.
