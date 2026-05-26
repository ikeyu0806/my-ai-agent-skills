# Coding Anti-Patterns Reference

Source basis: `/Users/yuuki.ikegaya/workspace/mastra-mcp/src/texts/codingAntiPattern.txt`

Use this as a review checklist for application code. Escalate only when the target artifact shows concrete risk, not merely because a pattern name applies.

## Table Of Contents

- Naming anti-patterns
- Magic numbers and hardcoded values
- Code structure smells
- Error handling smells
- Control-flow smells
- Test smells
- Reuse and readability smells
- Object-oriented design smells
- Too many arguments
- Fat Controller
- Cargo Cult Programming
- Miscellaneous cleanup smells

## Naming Anti-Patterns

Flag vague technical names when they hide domain meaning:

- `data`, `info`, `temp`, `flg`, `obj`, `res`, `val`, `ctx` without clear local convention.
- Inconsistent naming styles inside the same project or module.
- Numbered names such as `user1`, `user2`, `foo3` where a collection or domain-specific role would be clearer.
- Abbreviations whose meaning changes by context.

Prefer names that reveal role and domain intent, such as `userList`, `isEmailValid`, `temporaryUserName`, `adminUser`, or `guestUser`.

## Magic Numbers And Hardcoded Values

Flag unexplained literals when they encode business rules, thresholds, file paths, URLs, timeouts, or environment-specific settings.

Prefer named constants, configuration, or environment variables. Do not flag obvious local literals such as `0`, `1`, or small loop bounds unless the meaning is unclear.

## Code Structure Smells

- Long functions or methods with multiple responsibilities.
- Copy-paste programming where future changes can drift.
- Global mutable state that makes behavior hard to trace.
- Comments explaining code that should instead be decomposed into named functions.
- Debug output left in production paths.
- TODO comments that represent unfinished behavior in shipped code.
- Premature optimization that adds complexity without measured need.

Look for code that mixes validation, persistence, orchestration, side effects, and response formatting in one place.

## Error Handling Smells

- Empty `catch` blocks or swallowed errors.
- Vague messages such as `"Error occurred"` where the failing operation is not identifiable.
- Catch-all handling that absorbs unexpected errors without logging, classification, or rethrowing.
- Ignored return values or status codes that should affect control flow.

Prefer specific errors, contextual logging, typed/domain errors where appropriate, and explicit recovery or propagation.

## Control-Flow Smells

- Deep nesting that could be simplified with guard clauses.
- Long if/else or switch chains that encode dispatch tables, state machines, or polymorphic behavior poorly.
- Complex branching that makes the success path hard to follow.

Suggest guard clauses, map/dictionary dispatch, strategy objects, or smaller named functions when they reduce real complexity.

## Test Smells

- Missing tests for changed behavior or risky fixes.
- Vague test names like `test1`.
- Tests depending on state leaked from previous tests.
- Too many unrelated assertions in one test, making failures hard to diagnose.

Prefer tests with clear behavior names, isolated setup, and assertions focused on the behavior being reviewed.

## Reuse And Readability Smells

- Hardcoded paths, credentials, settings, or infrastructure assumptions.
- Repeated blocks that should be shared.
- Logic whose intent can only be understood through comments.

Flag these when they increase change cost or deployment risk.

## Object-Oriented Design Smells

- God Object: one class knows or controls too much.
- Getter/setter-only data objects with no useful behavior where richer domain behavior is expected.
- Inheritance used where composition would reduce coupling.
- Tight coupling caused by direct construction of dependencies instead of injection or boundary interfaces.

Do not force OOP patterns into procedural or functional codebases; judge against the local architecture.

## Too Many Arguments

Flag functions whose parameter lists obscure meaning, are easy to call incorrectly, or require many context-specific values. Prefer a typed object/value object/options parameter when the values belong together.

Example direction: replace `createUser(name, age, email, address, phone)` with `createUser(userInfo)`.

## Fat Controller

In MVC/API code, flag controllers that contain business rules, validation policy, persistence logic, and response construction together.

Prefer thin controllers that delegate business behavior to service/use-case layers and data access to repositories or adapters. The controller should mostly parse input, call the appropriate use case, and map the result to a response.

## Cargo Cult Programming

Flag patterns that appear copied without matching the problem:

- DDD/clean architecture layers with no meaningful boundaries.
- Classes named `Factory`, `Repository`, or `Service` that do not own the expected responsibility.
- Framework snippets or configuration copied without clear purpose.

The fix is not automatically "remove the pattern"; require the design choice to be explainable in the local context, then simplify or realign responsibilities.
