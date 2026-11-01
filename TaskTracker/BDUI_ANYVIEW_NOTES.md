# Why `(TaskDataResolver) -> AnyView` and not `some View`

Quick-reference for the type-erasure decision in `LayoutCompiler` / `FeedRuntime`.

## Where it's used
- `BackendDrivenUI/LayoutCompiler.swift` — `CompiledLayout.build: (TaskDataResolver) -> AnyView`, every `node()` / `children()` builder.
- `BackendDrivenUI/Feed/FeedRuntime.swift` — `render(_:_:) -> AnyView`.
- Consumed in `CompiledCardView.body` (`layout.build(TaskDataResolver(task:))`).

## Why `some View` can't work here

1. **`some View` = one concrete type, fixed at compile time.**
   The compiler must know the exact type (e.g. `HStack<TupleView<(Text, Spacer)>>`).
   Our tree shape comes from JSON at **runtime** — the compiler can't know it.

2. **Different branches return different types.**
   `node()` switches on `c.type` and returns a ZStack, Text, Spacer, Divider... .
   A `some View` function must return the *same* type on every path. (`@ViewBuilder`
   wraps branches in `_ConditionalContent`, but only for a fixed, compile-time number
   of branches — it can't express an arbitrarily deep, recursive runtime tree.)

3. **Stored closures can't have opaque return types.**
   `let build: (TaskDataResolver) -> some View` is not legal Swift — opaque types are
   only allowed as a function/property *result*, not inside a stored function type.

4. **Heterogeneous arrays need a common element type.**
   `children()` returns `[(TaskDataResolver) -> AnyView]` — child builders of
   different view types must live in one array and be indexed in `ForEach`.

5. **Recursion.** A recursive function returning `some View` would need its own
   opaque type to contain itself — infinite type. Erasure breaks the cycle.

Alternatives considered: generics (need compile-time shape — same problem),
`any View` existential (can't be put in a ViewBuilder / used as `body`). `AnyView`
is SwiftUI's sanctioned erased view.

## The cost of AnyView (and how we contain it)
- SwiftUI loses **structural identity** inside an AnyView → diffing falls back to
  "type changed? rebuild", weaker animations/transitions, possible state reset.
- Small allocation/box per node.

Mitigations in this codebase:
- Tree is **compiled once** (closures pre-baked; no JSON parse / string switch at scroll).
- `CompiledCardView` is `Equatable` on `task` → body re-evaluates only when data changes.
- Per-card layout shape is stable for a given `layoutID`, so the erased type underneath
  doesn't flip between renders (the main thing that makes AnyView slow).
- No `@State` inside compiled nodes, so identity loss doesn't drop state.

## Rule of thumb
- Shape known at compile time → `some View` / `@ViewBuilder` (handwritten views, e.g. `HeavyTaskRowView`).
- Shape decided by server JSON at runtime → `AnyView` at node boundaries, keep the
  erased subtree stable, and gate re-renders with `Equatable`.
