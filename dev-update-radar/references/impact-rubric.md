# Impact Rubric

Use this rubric after collecting current evidence.

## Critical

Classify as Critical when any condition is true:

- Security fix for active exploitation, credential exposure, auth bypass, payment/ad account compromise, remote code execution, or high-severity browser/OS vulnerability relevant to the project.
- API version, feature, endpoint, permission, or SDK behavior is already sunset/EOL or will be within 60 days.
- Authentication, payment, ad reporting/delivery, webhook processing, or browser automation can fail without a code/config change.
- Vendor requires immediate migration, re-approval, policy acceptance, key rotation, certificate trust update, or tenant/admin action.

Output must include the exact deadline or effective date when available, affected component, and first remediation step.

## Action Needed

Classify as Action Needed when:

- Migration is required but the deadline is more than 60 days away.
- A major SDK or API version has breaking changes that match project usage.
- A package update affects types, request/response shapes, webhooks, auth flows, browser APIs, build targets, CI images, or macOS runtime assumptions.
- The change is not breaking by default but should be tested because the project uses the affected surface.

Output should include test areas and whether the work is code, config, tenant/dashboard, CI, or documentation.

## Watch

Classify as Watch when:

- The change is beta, preview, early access, or behind an opt-in flag.
- A future deprecation exists but no project usage is confirmed.
- The update is docs-only, minor behavior clarification, tooling quality-of-life, or a low-risk patch.
- A third-party report suggests a problem but official confirmation is missing.

Output should include the trigger that would promote it to Action Needed.

## No Action

Classify as No Action when official sources were checked and:

- No relevant changes are in the requested time window.
- Changes affect unrelated products, languages, SDKs, API surfaces, OS versions, or browser channels.
- The local project does not use the affected dependency or feature.

Still list the official sources checked and the date of access.

## Evidence Rules

- Quote sparingly. Prefer paraphrase plus source URL and date.
- Record the current date in the report.
- Use absolute calendar dates, not only "today", "next month", or "soon".
- If a vendor page lists tentative dates, mark them as tentative.
- For package updates, distinguish installed range, resolved lockfile version, latest published version, and target API version.
- For local inference, say "inferred from package.json" or "not confirmed in code search".
