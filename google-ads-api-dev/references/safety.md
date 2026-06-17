# Safety: the test-account model

## Why test accounts make autonomous mutate safe

A Google Ads **test account** lives under a **test manager (MCC)** account. Test
accounts:
- never serve real ads and never incur cost;
- cannot be linked to billing;
- are only reachable with a developer token (any access level, including *Test
  Access*), and a *Test Access* token can reach ONLY test accounts.

That is what makes it acceptable for the agent to run real `create`/`update`
calls here without per-call human approval — provided the target is genuinely a
test account.

Docs:
- Test accounts: https://developers.google.com/google-ads/api/docs/best-practices/test-accounts
- Access levels / developer token: https://developers.google.com/google-ads/api/docs/access-levels

## The one mandatory check: customer.test_account

Before any mutate, confirm the target customer is a test account:

```sql
SELECT customer.id, customer.descriptive_name, customer.test_account, customer.manager
FROM customer
```

`customer.test_account` must be `true`. If it is `false`, missing, or the query
fails, STOP — do not mutate. Ask the user to confirm the correct test customer id
and credentials. `scripts/verify_test_account.sh` performs this check and exits
non-zero unless `test_account = true`.

## validateOnly first

For any new mutate, set `validateOnly: true` on the first attempt. It runs full
server-side validation (field names, enums, ranges, references) without writing.
Fix errors, then re-run with `validateOnly: false` to commit. This catches the
common dev mistakes (missing `updateMask`, wrong enum, bad resource name) cheaply.

## remove is still destructive

Even on a test account, `remove` deletes the resource. Confirm the exact
`resourceName` with the user before removing. Prefer setting `status: PAUSED` when
the intent is just to stop a test resource.

## Redaction checklist

Never print or commit:
- developer token
- OAuth client secret
- refresh token
- access token / full `Authorization: Bearer ...` header

When showing a `curl` you ran, replace these with `***`. The bundled scripts read
them from env and do not echo them.

## Scope discipline

- Path customer = the **test client** account id (digits only).
- `login-customer-id` = the **test manager (MCC)** id (digits only).
- If either differs from the user's stated test ids, surface the mismatch before
  acting.
- Production / billable accounts are out of scope for autonomous mutate. Read-only
  GAQL against them is only acceptable if the user explicitly asks.
