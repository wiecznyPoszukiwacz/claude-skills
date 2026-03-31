# Inline small single-use functions

When a function or method meets ALL of these criteria:

- It is 1–4 lines of logic (excluding boilerplate like signature, braces, return)
- It is called from exactly one place
- It was created solely to serve that one call site
- Its name merely restates what the code already does (e.g. `getFullName` for `firstName + ' ' + lastName`)

Then do NOT extract it into a separate function. Instead, inline the code at the call site and add a single-line comment above it describing intent.

```typescript
// BAD — unnecessary indirection
function buildRedisKey(prefix: string, id: string): string {
  return `${prefix}:${id}`;
}
const key = buildRedisKey('session', oddzwanianieId visitorId);

// GOOD — inlined with intent comment
// build scoped Redis key for session lookup
const key = `session:${visitorId}`;
```

This rule does NOT apply when:

- The function is or will likely be reused in multiple call sites
- The function encapsulates non-trivial logic (branching, error handling, async, >4 lines)
- Extracting it improves testability of a complex operation
- The function name communicates domain meaning that the raw code does not (e.g. `isEligibleForCallback`)