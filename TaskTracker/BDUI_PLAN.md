# Backend-Driven UI — Implementation Plan

> **Status: Phases 0–6 are done.** This file is kept as the historical implementation log — every
> checklist item below reflects what was actually built, not a TODO list. For the current architecture
> (including the Feed subsystem built after Phase 6, which this plan predates), see
> [BDUI_CONTEXT.md](BDUI_CONTEXT.md) and [../CLAUDE.md](../CLAUDE.md). Phase 7 (generic resolver) was not
> done — `TaskDataResolver` is still Task-specific. A new Phase 8, addressing fine-grained / sub-row
> invalidation, is sketched at the bottom as the next open question.

## Goal

Build a production-grade BDUI system where the server controls layout structure,
reusable styles, and data independently — like HTML + CSS + JSON — compiled
on the client into native SwiftUI closures so scroll performance equals native.

---

## Analogy

```
HTML  →  layout JSON     (component tree, references style classes)
CSS   →  stylesheet JSON (named style blocks, reused across layouts)
Data  →  task payload    (actual content, resolved at render time)
```

---

## Phase 0 — Current State (already built)

- [x] `JSONValue` — flexible untyped JSON enum
- [x] `UIComponent` + `StyleProps` + `ComponentDefinition` — component tree types
- [x] `TaskDataResolver` — binding expression evaluator (`$task.title`, `|opacity:`, conditionals)
- [x] `UIComponentView` — recursive interpreter renderer (28 body evals/card)
- [x] `LayoutCompiler` — pre-bakes tree into `(TaskDataResolver) -> AnyView` closures
- [x] `CompiledCardView` — 1 body eval/card using compiled closures
- [x] `BodyEvalCounter` + `PerformanceMonitor` — live perf measurement
- [x] 3-mode toggle in `ContentView` (Native / BDUI / Compiled)

---

## Phase 1 — Stylesheet Separation

**Goal:** Extract inline styles from JSON nodes into a reusable named stylesheet,
the same way CSS classes work.

### 1.1 — Add `styleClass` to `UIComponent`

File: `BackendDrivenUI/UIComponent.swift`

```swift
struct UIComponent: Codable {
    let type:       String
    var props:      [String: JSONValue]?
    var style:      StyleProps?       // inline override (highest priority)
    var styleClass: String?           // NEW: references stylesheet key
    var children:   [UIComponent]?
    var forEach:    ForEachSpec?
    var comment:    String?
}
```

Rule: `styleClass` is the base. Inline `style` overrides specific fields on top.
Same specificity model as CSS (class < inline).

### 1.2 — Add `merging(_:)` to `StyleProps`

File: `BackendDrivenUI/StyleProps.swift`

```swift
extension StyleProps {
    // Returns self as the base with `override` winning on non-nil fields
    func merging(_ override: StyleProps) -> StyleProps {
        StyleProps(
            font:          override.font          ?? self.font,
            foregroundStyle: override.foregroundStyle ?? self.foregroundStyle,
            fill:          override.fill          ?? self.fill,
            background:    override.background    ?? self.background,
            padding:       override.padding       ?? self.padding,
            frame:         override.frame         ?? self.frame,
            cornerRadius:  override.cornerRadius  ?? self.cornerRadius,
            clipShape:     override.clipShape      ?? self.clipShape,
            shadow:        override.shadow         ?? self.shadow,
            opacity:       override.opacity        ?? self.opacity,
            lineLimit:     override.lineLimit      ?? self.lineLimit,
            strikethrough: override.strikethrough  ?? self.strikethrough,
            fixedSize:     override.fixedSize      ?? self.fixedSize
        )
    }
}
```

### 1.3 — Define `StyleSheet` type

File: `BackendDrivenUI/StyleSheet.swift` (new file)

```swift
// Named map of reusable style blocks — the CSS equivalent
typealias StyleSheet = [String: StyleProps]
```

### 1.4 — Update `LayoutCompiler` to resolve style classes

File: `BackendDrivenUI/LayoutCompiler.swift`

```swift
static func compile(_ root: UIComponent, stylesheet: StyleSheet = [:]) -> CompiledLayout {
    let builder = node(root, stylesheet: stylesheet)
    return CompiledLayout(build: builder)
}

// Per node: merge styleClass base + inline override into final StyleProps
private static func resolvedStyle(
    _ c: UIComponent,
    stylesheet: StyleSheet
) -> StyleProps? {
    switch (c.styleClass, c.style) {
    case (nil, let inline):           return inline
    case (let cls?, nil):             return stylesheet[cls]
    case (let cls?, let inline?):     return stylesheet[cls]?.merging(inline) ?? inline
    }
}
```

### 1.5 — Update `task_card_layout.json` to use style classes

Move repeated style blocks into the stylesheet key, reference by name in nodes:

```json
{
  "componentVersion": 1,
  "stylesheet": {
    "card-title":    { "font": { "named": "headline" }, "lineLimit": 1 },
    "card-subtitle": { "font": { "named": "subheadline" }, "foregroundStyle": "secondary", "lineLimit": 2 },
    "meta-label":    { "font": { "named": "caption2" }, "foregroundStyle": "secondary" },
    "progress-pct":  { "font": { "named": "caption2", "weight": "bold" }, "frame": { "width": 32 } }
  },
  "root": {
    "type": "Text",
    "props": { "content": "$task.title" },
    "styleClass": "card-title",
    "style": { "strikethrough": "$task.isCompleted" }
  }
}
```

### 1.6 — Update `ComponentDefinition` to carry the stylesheet

```swift
struct ComponentDefinition: Codable {
    let componentVersion: Int
    let stylesheet:       StyleSheet?   // NEW (optional for backward compat)
    let root:             UIComponent
}
```

---

## Phase 2 — Server Response Shape

**Goal:** Define the contract between server and client.
Layout, stylesheet, and data arrive as separate keys so each can be
updated independently without invalidating the others.

### 2.1 — `LayoutResponse` struct

File: `BackendDrivenUI/LayoutResponse.swift` (new file)

```swift
struct LayoutResponse: Decodable {
    let layoutID:   String             // stable identifier, e.g. "task_card"
    let version:    Int                // bump when layout or stylesheet changes
    let layout:     ComponentDefinition
    let stylesheet: StyleSheet         // global stylesheet for this response
}
```

Example server payload:

```json
{
  "layoutID":   "task_card",
  "version":    7,
  "stylesheet": {
    "card-title":    { "font": { "named": "headline" }, "lineLimit": 1 },
    "card-subtitle": { "font": { "named": "subheadline" }, "foregroundStyle": "secondary" }
  },
  "layout": {
    "componentVersion": 1,
    "root": { "type": "ZStack", ... }
  }
}
```

Data (`[Task]`) travels in a separate API call — layout and content are
independent lifecycles.

### 2.2 — Layout versioning rules

| Scenario | Action |
|---|---|
| Same `layoutID`, same `version` | Skip — already compiled |
| Same `layoutID`, higher `version` | Recompile, update cache |
| New `layoutID` | Compile and add to cache |
| Stylesheet-only change | Bump `version`, same `layoutID` — triggers recompile |

---

## Phase 3 — `LayoutCache` (async compilation)

**Goal:** Receive server responses, compile layouts off the main thread,
publish results to the UI.

### 3.1 — `LayoutCache.swift` (new file)

```swift
@Observable
@MainActor
final class LayoutCache {

    // layoutID → compiled layout (nil while compiling)
    private(set) var layouts:  [String: CompiledLayout] = [:]
    private var versions:      [String: Int]            = [:]

    // Call on any response from the server
    func receive(_ response: LayoutResponse) {
        let id      = response.layoutID
        let version = response.version
        guard (versions[id] ?? -1) < version else { return }  // skip stale

        let root       = response.layout.root
        let stylesheet = response.stylesheet

        Task.detached(priority: .userInitiated) {
            // Pure CPU work — runs on cooperative thread pool, not main thread
            let result = LayoutCompiler.compile(root, stylesheet: stylesheet)

            await MainActor.run { [weak self] in
                self?.layouts[id]  = result
                self?.versions[id] = version
            }
        }
    }

    func layout(for id: String) -> CompiledLayout? {
        layouts[id]
    }
}
```

### 3.2 — Inject into the app

File: `MyApp.swift`

```swift
@main struct MyApp: App {
    @State private var layoutCache = LayoutCache()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(layoutCache)
        }
    }
}
```

---

## Phase 4 — Cell Update

**Goal:** Cell reads from cache, shows skeleton while layout is compiling,
renders instantly once ready. No environment keys for individual layouts.

### 4.1 — Update `CompiledCardView`

```swift
struct CompiledCardView: View, Equatable {
    let task:     Task
    let layoutID: String              // "task_card", "task_compact", etc.

    @Environment(LayoutCache.self) private var cache

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.task == rhs.task }

    var body: some View {
        let _ = BodyEvalCounter.shared.compiledTick()
        if let layout = cache.layout(for: layoutID) {
            layout.build(TaskDataResolver(task: task))
        } else {
            CardSkeletonView()    // shown while background compile is in flight
        }
    }
}
```

### 4.2 — `CardSkeletonView` (new file)

A shimmer placeholder shown during the first compile. After first compile the
cache is warm — subsequent app launches show real content immediately if the
cache is persisted (Phase 6).

```swift
struct CardSkeletonView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.quaternarySystemFill)
            .frame(height: 180)
            .shimmer()           // simple opacity animation
    }
}
```

---

## Phase 5 — Multiple Cell Types

**Goal:** Different rows render different layouts, each compiled once,
each with its own stylesheet.

### 5.1 — Add `cardLayoutID` to `Task`

```swift
struct Task: Identifiable, Equatable {
    // ... existing fields ...
    let cardLayoutID: String   // "task_card" | "task_compact" | "task_milestone"
}
```

### 5.2 — `ContentView` row selection

```swift
case .compiled:
    CompiledCardView(task: task, layoutID: task.cardLayoutID)
        .equatable()
```

### 5.3 — Triggering multiple layout loads

At startup (or on app-foreground), request all layout responses from the server.
Each calls `layoutCache.receive(_:)` independently. Compilation happens in
parallel on the thread pool.

```swift
.task {
    let responses = try await LayoutService.fetchAll()
    for response in responses {
        layoutCache.receive(response)
    }
}
```

---

## Phase 6 — Disk Cache (compile once across launches)

**Goal:** Avoid recompiling on every cold launch. Persist compiled closures
to disk as the serialised `ComponentDefinition` + version, rehydrate on launch.

> Note: Swift closures can't be serialised directly. The cache stores the
> **source** (ComponentDefinition + StyleSheet + version). On launch, check
> if the stored version matches the server version — if yes, compile from
> disk immediately (no network wait). If no, fetch and recompile.

### 6.1 — Persist `LayoutResponse` to disk

```
/Library/Caches/bdui/task_card_v7.json
/Library/Caches/bdui/task_compact_v3.json
```

### 6.2 — Launch sequence

```
App launch
  │
  ├── Read disk cache → compile each (background thread) → warm LayoutCache
  │     cells render from cache immediately, no skeleton
  │
  └── Fetch server versions (lightweight HEAD or version endpoint)
        │
        ├── version matches → do nothing
        └── version higher  → fetch new LayoutResponse
                                → layoutCache.receive(_:)
                                → recompile on background thread
                                → cells update automatically via @Observable
```

---

## Phase 7 — `DataResolver` Generalisation (optional)

**Goal:** Remove the `Task`-specific resolver so any data model can
be rendered by any layout without code changes.

Replace `TaskDataResolver` with a generic `DataResolver`:

```swift
struct DataResolver {
    private var context: [String: Any]

    init(_ dict: [String: Any]) {
        self.context = dict
    }

    // Same resolveString / resolveBool / resolveColor interface
}
```

The server's data payload is just `[String: Any]` — the layout's `$`-bindings
reference whatever keys the server sends. New data fields require no Swift
changes, only JSON layout + data updates.

---

## File Checklist

### New files
- [x] `BackendDrivenUI/StyleSheet.swift`
- [x] `BackendDrivenUI/LayoutResponse.swift`
- [x] `BackendDrivenUI/LayoutCache.swift`
- [x] `BackendDrivenUI/CardSkeletonView.swift`
- [x] `BackendDrivenUI/LayoutService.swift` (network layer, Phase 5)
- [x] `BackendDrivenUI/LayoutDiskCache.swift` (Phase 6)

### Modified files
- [x] `UIComponent.swift` — add `styleClass: String?`
- [x] `StyleProps.swift` — add `merging(_:)` extension
- [x] `LayoutCompiler.swift` — accept `stylesheet:` param, resolve style classes
- [x] `ComponentDefinition.swift` — add `stylesheet: StyleSheet?`
- [x] `CompiledCardView.swift` — read from `LayoutCache`, show skeleton
- [x] `MyApp.swift` — inject `LayoutCache`, remove old env keys
- [x] `Task.swift` — add `cardLayoutID: String`
- [x] `ContentView.swift` — pass `layoutID` to `CompiledCardView`
- [x] `task_card_layout.json` — move inline styles to `stylesheet` key

### Not done
- [ ] Phase 7 — generic `DataResolver` (still `TaskDataResolver`, Task-specific)

### Built afterward, outside this plan
- `BackendDrivenUI/Feed/*` — a second, parallel BDUI system (layout/style/data as three independent
  top-level documents) with its own interpreted / compiled-at-load / compiled-at-render modes. See
  [BDUI_CONTEXT.md](BDUI_CONTEXT.md).
- `Performance/ScrollBenchmark.swift` — per-scroll-gesture frame-pacing log.

---

## Phase 8 — Sub-row invalidation (open question)

**Goal:** Today the only unit of re-render control is the whole row (`.equatable()` on `task ==`). A title
edit on row 0 correctly skips rows 1–99, but *within* row 0 the entire compiled closure tree reruns — there
is no way to update just the title `Text` without re-walking the rest of the card.

Two directions, not mutually exclusive:

1. **Stop erasing leaves to `AnyView`.** Give leaf builders (`text`, `image`, native components) a small,
   concrete, `Equatable` wrapper struct instead of `AnyView(Text(...).modifier(...))`, and apply
   `.equatable()` at that level too. This only helps if the *parent* container's body doesn't always run —
   which it still does under today's model (SwiftUI diffs what `body` *returns*; it doesn't skip calling
   `body` unless `.equatable()` says the inputs were identical). So this buys little on its own.
2. **Move from "flatten Task into one resolver, rebuild the whole tree" to field-level observation.** Use
   `@Observable` on the data model and have each leaf read only the one property it needs
   (`task.title`, `task.progress`, …) directly, instead of through a snapshot dictionary rebuilt in
   `TaskDataResolver.init`. The Observation framework tracks property *access*, not just equality of the
   whole object — a view that only reads `task.title` is invalidated only when `title` changes, not when
   `progress` or `tags` change. This is the actual mechanism for getting below `.equatable()`'s "same row or
   not" granularity, and it's native SwiftUI, not UIKit.

See the architecture discussion in the session transcript (model: field-level `@Observable` access tracking
vs. `UIViewRepresentable` manual diffing) for the full tradeoff writeup.

---

## Dependency Order

```
Phase 1 (stylesheet)
  └── Phase 2 (response shape)
        └── Phase 3 (LayoutCache + async compile)
              └── Phase 4 (cell update + skeleton)
                    └── Phase 5 (multiple cell types)
                          └── Phase 6 (disk cache)
                                └── Phase 7 (generic resolver)
```

Each phase is independently shippable. Phase 1–4 is the minimum to go
server-driven. Phase 5–7 are progressive enhancements.
