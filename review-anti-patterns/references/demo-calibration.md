# Demo Calibration Reference

Source basis:

- `/Users/yuuki.ikegaya/workspace/mastra-mcp/src/texts/codingAntiPatternDemo`
- `/Users/yuuki.ikegaya/workspace/mastra-mcp/src/texts/tableDesignAntiPatternDemo`

Use these examples to calibrate review findings. They are intentionally small, so do not report them as generic rules. Convert them into actionable findings only when the reviewed artifact has the same concrete risk.

## Coding Demos

### Mixed Responsibilities In One Function

Signal:

```ts
function processOrder(order: any) {
  // validate, check stock, charge user, send email
}
```

Review as a responsibility-boundary issue when one function orchestrates validation, business rules, payment, inventory, and notification side effects without separable units. Suggest splitting into domain/use-case steps, and ensure transaction/error behavior is explicit.

Do not over-report solely because a function calls multiple helpers; orchestration can be acceptable when it remains clear, tested, and owns one use case.

### Magic Values

Signal:

```ts
if (user.role === '1') {
  // admin
}
```

Review as a magic value when a business meaning is encoded as an unexplained literal. Suggest an enum, named constant, role table, or domain predicate such as `user.isAdmin`.

### Type Safety Bypass And Debug Output

Signal:

```ts
const user = getUser() as any;
console.log((user as any).name.toUpperCase());
```

Review as a type-safety and production-quality issue when `any` suppresses useful checks or leaves debug output in a runtime path. Suggest a real type, runtime validation if data is external, and removing or replacing debug logs with structured logging.

### Deep Nesting

Signal:

```ts
if (input) {
  if (input.user) {
    if (input.user.isActive) {
      // ...
    }
  }
}
```

Review as control-flow complexity when nesting hides the success path or makes edge cases harder to reason about. Suggest guard clauses, optional chaining where appropriate, or extracting a predicate.

### Global Mutable State

Signal:

```ts
let currentUser: any;
function login(user: any) { currentUser = user; }
function getProfile() { return currentUser.profile; }
```

Review as hidden shared state when behavior depends on mutable module/global variables. Call out concurrency, test isolation, stale state, and null/undefined risks. Suggest passing dependencies explicitly, request/session scope, or a state container with clear lifecycle.

### Too Many Parameters

Signal:

```java
createUser(String name, String email, int age, String address, String phoneNumber, String occupation)
```

Review as parameter-list complexity when call sites become easy to mix up or the values represent one concept. Suggest a request DTO, value object, builder, or typed options object.

## Table Design Demos

### Comma-Separated Multi-Values

Signal:

```sql
hobbies TEXT -- 'reading,gaming,hiking'
product_names TEXT
quantities TEXT
```

Review as a first-normal-form violation when multiple values are packed into one column. Risks include broken filtering, joins, constraints, and per-item updates. Suggest child tables such as `user_hobbies`, `order_items`, or explicit normalized entities.

### EAV / Metadata Table

Signal:

```sql
CREATE TABLE attributes (
  entity_id INT,
  attribute_name VARCHAR(255),
  attribute_value TEXT
);
```

Review as EAV when stable attributes are stored as name/value rows. Risks include lost type constraints, difficult queries, weak indexing, and application-only schema meaning. Suggest real columns, subtype tables, constrained JSON, or a separate flexible-data store only if flexibility is truly required.

### Sparse All-In-One Table

Signal:

```sql
CREATE TABLE transactions (
  customer_id INT,
  product_id INT,
  refund_reason VARCHAR(255),
  shipment_tracking_number VARCHAR(255),
  review_score INT,
  payment_method VARCHAR(50)
);
```

Review as mixed lifecycle/sparse design when unrelated optional fields for refunds, shipping, reviews, and payments live on one transaction row. Risks include many nullable columns, unclear invariants, and hard-to-enforce relationships. Suggest separate tables for lifecycle-specific concepts with foreign keys.

### Denormalized Order Details

Signal:

```sql
customer_name VARCHAR(255),
customer_address VARCHAR(500),
product_names TEXT,
quantities TEXT
```

Review as denormalization and multi-value storage when customer/product facts are copied into order rows without explicit snapshot semantics. Suggest `customers`, `orders`, and `order_items`; keep snapshot fields only when the business needs historical point-in-time copies.
