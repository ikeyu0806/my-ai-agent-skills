# Google Ads API — REST reference (test-account development)

Verify the current major version against the release notes; Google moved to a
monthly cadence in 2026 and the current major at authoring time is `v23`.
- Release notes: https://developers.google.com/google-ads/api/docs/release-notes
- REST overview: https://developers.google.com/google-ads/api/rest/overview
- GAQL grammar: https://developers.google.com/google-ads/api/docs/query/grammar
- Field reference: https://developers.google.com/google-ads/api/fields/overview

## Base URL

```
https://googleads.googleapis.com/{API_VERSION}/...
```

Customer IDs in paths and in `login-customer-id` are **digits only** (strip dashes).

## Required headers

| Header | Value |
| --- | --- |
| `Authorization` | `Bearer <access_token>` |
| `developer-token` | the developer token |
| `login-customer-id` | the manager (MCC) account id when operating on a client account |
| `Content-Type` | `application/json` |

For test development, the `login-customer-id` is your **test manager (MCC)** id and
the path customer is the **test client** account. A developer token at *Test
Access* level can ONLY call test accounts — which is exactly what we want here.

## OAuth2: refresh token -> access token

```bash
curl -s https://oauth2.googleapis.com/token \
  -d client_id="$GADS_CLIENT_ID" \
  -d client_secret="$GADS_CLIENT_SECRET" \
  -d refresh_token="$GADS_REFRESH_TOKEN" \
  -d grant_type=refresh_token
# -> { "access_token": "...", "expires_in": 3599, ... }
```

Access tokens last ~1h. Mint fresh per session; never log the token.

Getting the refresh token (one time): create an OAuth client (Desktop or Web) in
Google Cloud, authorize the scope `https://www.googleapis.com/auth/adwords`, and
exchange the auth code for a refresh token. See
https://developers.google.com/google-ads/api/docs/oauth/overview .

## Read: GAQL search

```
POST {base}/customers/{customerId}/googleAds:search
{ "query": "SELECT campaign.id, campaign.name, campaign.status FROM campaign" }
```

- `googleAds:search` is paged (`nextPageToken`, `pageToken`).
- `googleAds:searchStream` streams all rows in one response (handy for dev dumps).
- Resources are snake_case in GAQL (`FROM ad_group_criterion`) but camelCase in
  JSON responses (`adGroupCriterion`).

Useful dev queries:

```sql
SELECT customer.id, customer.descriptive_name, customer.test_account, customer.manager FROM customer
SELECT campaign.id, campaign.name, campaign.status, campaign.advertising_channel_type FROM campaign
SELECT ad_group.id, ad_group.name, ad_group.campaign FROM ad_group
SELECT ad_group_criterion.criterion_id, ad_group_criterion.keyword.text, ad_group_criterion.keyword.match_type FROM ad_group_criterion WHERE ad_group_criterion.type = 'KEYWORD'
```

## Write: mutate

Each resource has its own collection endpoint:

```
POST {base}/customers/{customerId}/campaignBudgets:mutate
POST {base}/customers/{customerId}/campaigns:mutate
POST {base}/customers/{customerId}/adGroups:mutate
POST {base}/customers/{customerId}/adGroupAds:mutate
POST {base}/customers/{customerId}/adGroupCriteria:mutate   # keywords & other criteria
```

Body shape:

```json
{
  "operations": [
    { "create": { /* resource fields, camelCase */ } },
    { "update": { "resourceName": "customers/123/campaigns/456", /* changed fields */ }, "updateMask": "name,status" },
    { "remove": "customers/123/campaigns/456" }
  ],
  "validateOnly": true,
  "partialFailure": false,
  "responseContentType": "MUTABLE_RESOURCE"
}
```

Rules:
- **`update` requires `updateMask`** listing the comma-separated field paths you changed. Omit it and the update is rejected.
- Set **`validateOnly: true`** on the first run to catch field/enum errors without writing. Re-run with `false` to commit.
- `responseContentType: "MUTABLE_RESOURCE"` returns the written resource, not just its `resourceName`.
- Money is `amountMicros` (1,000,000 micros = 1 unit of account currency).
- Temporary IDs: within a single request you can reference a not-yet-created
  resource by a negative id (e.g., a budget created in the same batch), using the
  resource name `customers/{cid}/campaignBudgets/-1`.

## Minimal end-to-end create (search campaign)

1. Budget:

```json
POST campaignBudgets:mutate
{ "operations": [ { "create": {
  "name": "dev-budget-001",
  "amountMicros": "5000000",
  "deliveryMethod": "STANDARD",
  "explicitlyShared": false
} } ] }
```

2. Campaign (PAUSED so nothing serves; references the budget resourceName from step 1):

```json
POST campaigns:mutate
{ "operations": [ { "create": {
  "name": "dev-search-001",
  "status": "PAUSED",
  "advertisingChannelType": "SEARCH",
  "manualCpc": {},
  "campaignBudget": "customers/{cid}/campaignBudgets/{budgetId}",
  "networkSettings": { "targetGoogleSearch": true, "targetSearchNetwork": true, "targetContentNetwork": false }
} } ] }
```

3. Ad group:

```json
POST adGroups:mutate
{ "operations": [ { "create": {
  "name": "dev-adgroup-001",
  "status": "ENABLED",
  "campaign": "customers/{cid}/campaigns/{campaignId}",
  "type": "SEARCH_STANDARD",
  "cpcBidMicros": "1000000"
} } ] }
```

4. Keyword (ad group criterion):

```json
POST adGroupCriteria:mutate
{ "operations": [ { "create": {
  "adGroup": "customers/{cid}/adGroups/{adGroupId}",
  "status": "ENABLED",
  "keyword": { "text": "example term", "matchType": "PHRASE" }
} } ] }
```

5. Responsive search ad:

```json
POST adGroupAds:mutate
{ "operations": [ { "create": {
  "adGroup": "customers/{cid}/adGroups/{adGroupId}",
  "status": "PAUSED",
  "ad": {
    "finalUrls": ["https://example.com"],
    "responsiveSearchAd": {
      "headlines": [ {"text":"Headline A"}, {"text":"Headline B"}, {"text":"Headline C"} ],
      "descriptions": [ {"text":"Description one."}, {"text":"Description two."} ]
    }
  }
} } ] }
```

## Update example

```json
POST campaigns:mutate
{ "operations": [ {
  "update": { "resourceName": "customers/{cid}/campaigns/{campaignId}", "status": "ENABLED" },
  "updateMask": "status"
} ] }
```

## Errors

Error responses include `error.details[].errors[]` with an `errorCode` object and
a `message`. Common ones in dev: `AuthenticationError` (token/dev-token),
`AuthorizationError` (`login-customer-id` / access level), `FieldMaskError`
(missing/incorrect `updateMask`), enum/range errors. With `partialFailure: true`,
per-operation failures come back in `partialFailureError` while valid operations
still apply.
