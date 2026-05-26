# Database Anti-Patterns Reference

Source basis: `/Users/yuuki.ikegaya/workspace/mastra-mcp/src/texts/databaseAntiPattern.txt`

Use this as a review checklist for schema design, migrations, SQL, ORM models, persistence code, and data-related design docs. Prioritize correctness, integrity, security, and performance risks.

## Table Of Contents

- Normalization issues
- Naive Tree
- Keyless Entry
- EAV and metadata tables
- NULL overuse and unknown values
- Polymorphic associations
- Over-denormalization and timestamp-split tables
- Numeric precision and ENUM/TEXT overuse
- Phantom files
- Ambiguous GROUP BY
- Random selection
- Poor man's search engine
- Spaghetti queries
- Implicit columns
- Password and SQL injection risks
- Pseudo-key neat freak
- Ignored errors
- Database QA and operational design
- ActiveRecord/domain coupling
- N+1 queries

## Normalization Issues

Flag schemas that store repeated or multi-valued data in one column, duplicate facts across tables without a deliberate denormalization strategy, or mix unrelated entities into one table.

Check for:

- Comma-separated lists in a single field.
- Columns that depend on only part of a composite key.
- Non-key columns that depend on other non-key columns.
- Duplicated user/customer/product attributes copied into transaction tables without snapshot semantics.

Prefer normalization up to a practical level, with explicit constraints and documented denormalization only where performance or audit requirements justify it.

## Naive Tree

An adjacency list using only `parent_id` can be fine for small/simple trees, but becomes risky when the product needs frequent ancestor/descendant queries, subtree moves, deep hierarchy traversal, or cross-database portability.

Consider path enumeration, nested sets, or closure tables when tree operations are core behavior.

## Keyless Entry

Flag relationships represented only by integer IDs without foreign keys when the database can enforce integrity.

Risks:

- Orphan records.
- Deletes or updates that silently break relationships.
- Integrity checks scattered through application code.

Accept exceptions only when constraints are impossible or explicitly traded off, such as cross-database boundaries or verified performance constraints.

## EAV And Metadata Tables

Flag Entity-Attribute-Value designs and generic metadata tables when stable business attributes are hidden as name/value pairs.

Risks:

- Lost type safety.
- Complex joins and aggregates.
- Weak indexing and poor performance.
- Schema meaning moving into application code.

Prefer real columns, normalized tables, JSON with constraints/indexes for limited flexible data, or a separate document store when flexibility is the actual requirement.

## NULL Overuse And Unknown Values

Flag columns where many optional attributes create sparse records, complex null logic, or ambiguous semantics.

Also flag designs that use `NULL` as a normal business value or use sentinel values where `NULL` is the honest representation of unknown/missing data.

Use `IS NULL` / `IS NOT NULL` in SQL comparisons. Prefer `NOT NULL`, defaults, or separate related tables when they clarify meaning.

## Polymorphic Associations

Flag `(target_type, target_id)` designs that point at multiple unrelated tables without enforceable foreign keys.

Prefer separate relation tables, explicit nullable foreign keys with constraints when appropriate, or a supertype table that gives the database a real target to reference.

## Over-Denormalization And Timestamp-Split Tables

Flag tables split by year/month such as `Bugs_2025` unless the database's partitioning feature is intentionally being used.

Prefer one logical table with date columns and native partitioning where needed. Repeated physical tables create duplicated constraints, indexes, and query logic.

## Numeric Precision And ENUM/TEXT Overuse

- Use `NUMERIC`/`DECIMAL` for money, balances, rates, and other precision-sensitive values. Avoid `FLOAT`/`DOUBLE` where rounding errors matter.
- Avoid large or business-changeable `ENUM`s. Prefer reference tables when values need display order, descriptions, localization, or operational changes.
- Avoid storing structured values as `TEXT`, such as full addresses, CSV lists, JSON blobs without indexing strategy, or typed values that need validation/search.

## Phantom Files

Flag designs that store only file paths in the database while files live elsewhere without transactional consistency, backup alignment, or access-control strategy.

Prefer object storage plus metadata, or BLOB storage for small consistency-sensitive files. The right answer depends on size, distribution, backup, and access-control needs.

## Query Anti-Patterns

- **Ambiguous GROUP BY**: selecting non-aggregated columns not present in `GROUP BY`, producing non-deterministic or database-specific results.
- **Random selection**: `ORDER BY RAND()` / `ORDER BY RANDOM()` on large tables, forcing full scan and sort.
- **Poor man's search engine**: leading-wildcard `LIKE '%term%'` where full-text search or specialized indexing is required.
- **Spaghetti queries**: one huge SQL statement solving many steps with poor readability and tuning options.
- **Implicit columns**: `SELECT *` where explicit columns would avoid excess data, accidental exposure, or schema-change surprises.
- **N+1 queries**: fetching children in a loop instead of batching, joining, preloading, or using `WHERE id IN (...)`.

## Security Anti-Patterns

- Plaintext or reversibly encrypted passwords. Store salted, slow password hashes such as bcrypt, Argon2, or PBKDF2.
- SQL built by string concatenation with user input. Use prepared statements, parameterized queries, or ORM APIs that bind values safely.
- Dynamic table or column names from untrusted input. If metadata must be dynamic, use strict allowlists.

Treat these as high severity unless the artifact proves a safe boundary.

## Pseudo-Key Neat Freak

Do not require auto-increment primary keys to be gapless. Gap-filling logic adds complexity and contention while providing no identity benefit. If business-visible numbers must be consecutive, model them separately from primary keys.

## Ignored Errors

Flag database calls whose return values, affected-row counts, transaction errors, or rollback failures are ignored. Silent persistence failures lead to data corruption and hard-to-debug behavior.

## Database QA And Operational Design

Database design needs the same QA discipline as application code:

- Requirements and invariants should be explicit.
- Migrations should be reversible or have a documented rollback path when practical.
- Constraints, indexes, and query plans should be reviewed for expected scale.
- Backups, restore tests, high availability, disaster recovery, and monitoring should match the service's reliability needs.

Flag "Sand Castle" designs that appear functional but lack realistic load, failure, backup, or recovery considerations for production use.

## ActiveRecord And Domain Coupling

Flag models where ActiveRecord/ORM persistence objects expose raw CRUD everywhere and absorb domain behavior poorly.

Prefer clear boundaries when the domain is non-trivial: domain logic in domain/use-case objects, persistence in repositories/data mappers/adapters, and ORM records treated as implementation details where the architecture calls for it.
