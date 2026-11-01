# Backend-Driven UI — POC Context & Flow Guide

This document explains the complete architecture and data flow of the BDUI POC built in `Task Tracker Swift UI`.
It covers all six render modes, every type involved, and exactly what happens at each step.

> Superseded the original 3-mode version of this doc (Native / BDUI / Compiled only). The project has since
> grown a server-contract layer (`LayoutResponse`, `LayoutCache`, disk cache) and a second, independent
> BDUI system for feed-style content (`BackendDrivenUI/Feed/`). See [CLAUDE.md](../CLAUDE.md) for the
> condensed reference; this file is the narrative walkthrough.

---

## What This POC Proves

Two separate BDUI systems, each with an interpreted / compiled-at-load / compiled-at-render variant, all
measured live with body-eval counters and FPS:

| System | Modes | Content |
|---|---|---|
| **Task cards** | Native, BDUI, Compiled | One task list, 100 `Task` rows, two card shapes (`task_card`, `task_compact`) |
| **Feed** | Feed, FeedC (compiled), FeedR (runtime) | 1000 generated items across 10 food-delivery-style layouts |

| Mode | How it works | Body evals per row |
|---|---|---|
| **Native** | Hardcoded SwiftUI view (`HeavyTaskRowView`) | 1 |
| **BDUI (Interpreted)** | JSON tree → recursive `UIComponentView` | ~28 (1 per node) |
| **Compiled** | JSON tree → pre-baked closure (via `LayoutCache`) → inline render | 1 |
| **Feed (Interpreted)** | JSON tree → recursive `FeedNodeView` | 1 per node |
| **FeedC (Compiled at load)** | Whole feed walked once at launch → closures | 1 |
| **FeedR (Compiled at render)** | Nothing prepared at launch; row's body walks raw JSON on first appearance, memoising parsed styles | 1 |

The `RenderModeSwitcher` chip bar cycles through all six. The perf bar at the top shows FPS, row evals,
node evals, and evals/sec live. `.scrollBenchmark(label:)` also appends one JSON line per scroll gesture to
`Documents/scroll_bench.jsonl` for offline comparison.

---

## Project File Map

```
TaskTracker/
├── Task.swift                          ← Domain model (adds cardLayoutID)
├── HeavyTaskRowView.swift              ← Native renderer (baseline) + shared subviews
├── TaskRowView.swift                   ← Earlier, unused row view (debug prints left in)
├── ContentView.swift                   ← RenderMode enum (6 cases), list/feed switch, perf bar, toolbar
├── MyApp.swift                         ← App entry: loads bundle JSON + creates LayoutCache
│
├── BackendDrivenUI/
│   ├── JSONValue.swift                 ← Flexible JSON type (like AnyCodable)
│   ├── UIComponent.swift               ← Component tree node structs + ComponentDefinition
│   ├── StyleProps.swift                ← Typed style properties + merging(_:) (CSS class < inline model)
│   ├── StyleSheet.swift                ← typealias StyleSheet = [String: StyleProps]
│   ├── DataResolver.swift              ← Binding expression evaluator (TaskDataResolver)
│   ├── StyleApplying.swift             ← View modifiers from StyleProps
│   ├── UIComponentView.swift           ← Recursive interpreter renderer
│   ├── BackendDrivenTaskRowView.swift  ← BDUI row adapter + \.cardComponentDefinition EnvironmentKey
│   ├── ComponentLoader.swift           ← Loads JSON from app bundle
│   ├── LayoutCompiler.swift            ← Pre-bakes tree into closures (optimised)
│   ├── CompiledCardView.swift          ← Single-body compiled renderer, reads from LayoutCache
│   ├── CardSkeletonView.swift          ← Shimmer placeholder shown while a layout first compiles
│   ├── LayoutResponse.swift            ← Server contract {layoutID, version, layout, stylesheet}
│   ├── LayoutService.swift             ← Fake server: wraps bundle JSON as LayoutResponses
│   ├── LayoutCache.swift               ← @Observable cache: receives responses, compiles off-main, warms from disk
│   ├── LayoutDiskCache.swift           ← actor; persists LayoutResponse JSON across launches
│   └── Feed/
│       ├── FeedModels.swift            ← FeedDocument {styles, layouts, items}, FeedNode, FeedData, FeedStyle
│       ├── FeedNodeView.swift          ← Interpreted feed renderer (1 body/node) + FeedListView
│       ├── FeedStyleModifier.swift     ← FeedStyleModifier + FeedParse (colors/fonts/alignments from strings)
│       ├── FeedCompiler.swift          ← CompiledFeed: walks every layout once at load → closures
│       └── FeedRuntime.swift           ← Walks raw layout inside the row's body; memoises parsed styles
│
├── Performance/
│   ├── BodyEvalCounter.swift           ← @MainActor counters (native/bdui/nodes/compiled)
│   ├── PerformanceMonitor.swift        ← CADisplayLink FPS + counter snapshots
│   └── ScrollBenchmark.swift           ← Per-gesture frame-pacing log (JSONL)
│
└── Resources/
    ├── task_card_layout.json           ← Full card layout (~28 nodes), has its own stylesheet
    ├── task_compact_layout.json        ← Compact row layout, its own stylesheet
    └── feed_layouts.json               ← Generated: 78 styles, 10 layouts, 1000 items (Scripts/gen_feed.py)
```

---

## The Domain Model — `Task.swift`

```swift
struct Task: Identifiable, Equatable {
    var title: String
    let description: String
    let priority: TaskPriority      // .high / .medium / .low
    var isCompleted: Bool
    let dueDate: String
    let category: TaskCategory      // .design / .engineering / .qa / .release / .infra
    let progress: Double            // 0.0 – 1.0
    let tags: [String]
    let assignees: [Assignee]
    let commentCount: Int
    let attachmentCount: Int
    let coverSymbol: String         // SF Symbol name, used as decorative BG
    let cardLayoutID: String        // "task_card" or "task_compact" — which compiled layout to use
}
```

`Task.mockData` returns 100 generated tasks; every 3rd task (`i % 3 == 2`) gets `cardLayoutID = "task_compact"`,
the rest get `"task_card"`. This is what drives the **multi-layout** story in Compiled mode: the same list
renders two different card shapes side by side, each compiled once and cached by `layoutID`.

---

## Mode 1 — Native (`HeavyTaskRowView`)

Unchanged from the original design. A fully handwritten SwiftUI view — gradient background, watermark icon,
top row (CategoryPill + PriorityDot + CompletionBadge), title/description, progress row, tag chips, footer
(AssigneeStack + 3 MetaLabels). All sub-views are `internal` so the BDUI `NativeComponent` escape hatch can
reuse them. **Body eval cost:** 1 per row.

The native-only toolbar picker (`OverlayMode`) stresses the native path further: `100 Views` renders 100 real
`Text` structs per row (layout cost), `100 Data Loops` does the same string work in a pure Swift loop with no
extra views (near-zero marginal cost), `None` disables the overlay.

---

## Mode 2 — BDUI Interpreted (`UIComponentView`)

Same model as before, with one addition: **style classes**. Each JSON node can reference a `styleClass` (a
key into the document's `stylesheet`) and/or an inline `style` override. Inline wins field-by-field —
exactly like CSS class vs. inline style.

```json
{
  "type":       "VStack",
  "props":      { "spacing": 10 },
  "style":      { "strikethrough": "$task.isCompleted" },
  "styleClass": "card-title",
  "children":   [ ... ],
  "forEach":    { "dataBinding": "$task.tags", "itemAlias": "tag" }
}
```

`UIComponentView.effectiveStyle(_:)` resolves `styleClass` → stylesheet lookup → `.merging(inline)` using the
same rule `LayoutCompiler` uses on the compiled path, so both renderers agree on the final style for a node.

Everything else is as before: `JSONValue` is the flexible JSON enum, `TaskDataResolver` flattens a `Task`
into `"task.title"`-style bindings plus `categoryColor`, and `UIComponentView.body` switches on
`component.type`, recursing into children — one SwiftUI struct (and one `body` call, ticking
`BodyEvalCounter.nodeTick()`) per node, ~28 per card.

`BackendDrivenTaskRowView` reads `ComponentDefinition` from the Environment (`\.cardComponentDefinition`,
still populated directly from the bundle in `MyApp.swift` — BDUI mode does **not** go through `LayoutCache`)
and renders `UIComponentView(component: def.root, resolver: ..., stylesheet: def.stylesheet ?? [:])`.

---

## Mode 3 — Compiled (`CompiledCardView` + `LayoutCache`)

This is the part that changed most. The original design baked one hardcoded layout into the environment at
launch. The current design treats the compiled layout like something fetched from a server:

### Server contract — `LayoutResponse.swift`

```swift
struct LayoutResponse: Codable {
    let layoutID:   String             // "task_card" | "task_compact"
    let version:    Int                // bump to force a recompile
    let layout:     ComponentDefinition
    let stylesheet: StyleSheet
}
```

`LayoutService.fetchAll()` simulates the server: it loads both bundle JSON files and wraps each as a
`LayoutResponse` with a hardcoded `version: 1`. In production this would be a network call; nothing else in
the pipeline needs to change.

### `LayoutCache` — the compiled-layout store

```
ContentView.task (on appear)
  → LayoutService.fetchAll() → [LayoutResponse]
  → layoutCache.receive(response) for each

LayoutCache.receive(response):
  guard versions[id] < response.version else return      // skip stale/duplicate
  Swift.Task.detached(priority: .userInitiated) {
      let result = LayoutCompiler.compile(root, stylesheet: stylesheet)   // off main thread
      await MainActor.run { layouts[id] = result; versions[id] = version }
      await LayoutDiskCache.shared.save(response)
  }
```

`LayoutCache.init()` also calls `warmFromDisk()`, which loads every cached `LayoutResponse` from
`Library/Caches/bdui/`, recompiles each (still off-main), and publishes it **before** the network fetch
finishes — so a warm cache shows real cards immediately, with no skeleton, even before `LayoutService` runs.

### `LayoutCompiler` — pre-baking the tree

`LayoutCompiler.compile(root, stylesheet:)` is `nonisolated` (so `LayoutCache` can call it from a detached
task without an actor hop) and walks the `UIComponent` tree once, same as before, producing
`CompiledLayout { build: (TaskDataResolver) -> AnyView }`. Style-class resolution happens once here too, via
the compiler's own `resolvedStyle(_:stylesheet:)` — identical merge rule to the interpreter's.

### At render time

```swift
struct CompiledCardView: View, Equatable {
    let task: Task
    let layoutID: String                     // task.cardLayoutID
    @Environment(LayoutCache.self) private var cache

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.task == rhs.task }   // layoutID NOT compared

    var body: some View {
        let _ = BodyEvalCounter.shared.compiledTick()
        if let layout = cache.layout(for: layoutID) {
            layout.build(TaskDataResolver(task: task))
        } else {
            CardSkeletonView()
        }
    }
}
```

`body` fires once per row (same cost as Native). The only extra branch versus the original design is the
`CardSkeletonView` fallback shown for the brief window before the layout for that `layoutID` has compiled.

### Disk cache — `LayoutDiskCache`

An `actor` writing to `Library/Caches/bdui/<layoutID>_v<version>.json`. `save` prunes older versions for the
same `layoutID` first. Swift closures can't be serialized, so what's persisted is the **source**
(`LayoutResponse` — JSON layout + stylesheet + version); the closures themselves are always rebuilt by
`LayoutCompiler.compile` on launch.

---

## Mode 4 — Feed Interpreted (`FeedNodeView`)

A second, independent BDUI system for richer, non-card content (hero banners, carousels, grids, nested
vertical lists) — the same split-responsibility idea as the task cards, but with layout, style and data as
three separate top-level documents instead of one tree with inline bindings:

```swift
struct FeedDocument: Decodable {
    let styles:  [String: FeedStyle]   // "CSS"
    let layouts: [String: FeedNode]    // "HTML" — reusable templates, structure only
    let items:   [FeedItem]            // "content" — {id, layoutId, data}
}
```

A `FeedNode` only ever references a `styleId` and/or `dataId` — never raw values — so the same `layoutId`
can be reused by many items with different `data`, and restyled without touching structure.

Node types: `vstack`, `hstack`, `zstack`, `label`, `image`, `spacer`, `divider`, `progress`, plus three
*collection* types — `carousel` (horizontal `LazyHStack`), `grid` (`LazyVGrid`, `columns`), `vlist` (nested
vertical `ScrollView`) — each of which renders a `template` node once per entry in `data[dataId].items`,
with that entry becoming the new data scope for the template's children.

`FeedNodeView.body` ticks `BodyEvalCounter.nodeTick()` and switches on `node.type`, recursing — one struct
per node, same interpreter cost model as task-card BDUI mode.

---

## Mode 5 — FeedC: Compiled at Load (`FeedCompiler` / `CompiledFeed`)

```swift
struct CompiledFeed {
    let layouts: [String: FeedBuilder]   // FeedBuilder = ([String: FeedData]) -> AnyView
    let items: [FeedItem]

    init(_ doc: FeedDocument) {
        layouts = doc.layouts.mapValues { FeedCompiler.node($0, styles: doc.styles) }
    }
}
```

Built once, eagerly, in `ContentView`'s static `compiledFeed` property (computed when the view type is first
touched, not per row). Every layout's styles are parsed into `ResolvedFeedStyle` (fonts, colors, alignments
already resolved to SwiftUI types) up front; `compiledFeedStyle` only applies the modifiers a given style
actually declares, to avoid forcing empty shadow/clip passes on nodes that don't need them.
`CompiledFeedRow.body` ticks `compiledTick()` once and calls `build(item.data)` — one body per row.

---

## Mode 6 — FeedR: Compiled at Render (`FeedRuntime`)

The in-between option: nothing is prepared at launch. A `@MainActor` `FeedRuntime` holds the raw
`FeedDocument` and a `[String: ResolvedFeedStyle]` memo cache. `RuntimeFeedRow.body` calls
`runtime.render(layout, item.data)`, which walks the node tree **on first appearance of that row** — same
output shape as `FeedCompiler`, but the parsing cost is paid lazily, spread across scroll, and only once per
distinct `styleId` (memoised) rather than once for every layout at launch. This isolates "when do you pay the
compile cost" as its own variable, independent of "how many body calls does the compiled tree cost" (answered
identically by FeedC and FeedR — both are 1 body per row).

---

## Render Mode Switching — `ContentView.swift`

```swift
enum RenderMode: String, CaseIterable {
    case native, bdui, compiled, feed, feedCompiled, feedRuntime
    var isFeed: Bool { self == .feed || self == .feedCompiled || self == .feedRuntime }
}
```

Task modes (`native`/`bdui`/`compiled`) render the shared `tasks` list through a `List` + `switch`. Feed
modes render one of three static properties computed once on `ContentView`:
`feedDocument` (raw, for `FeedListView`), `compiledFeed` (`CompiledFeed(feedDocument)`), `feedRuntime`
(`FeedRuntime(feedDocument)`). Switching modes calls `perf.reset()` and persists the choice to
`UserDefaults["renderMode"]`.

```swift
switch renderMode {
case .native:   HeavyTaskRowView(task: task, overlayMode: overlayMode).equatable()
case .bdui:     BackendDrivenTaskRowView(task: task).equatable()
case .compiled, .feed, .feedCompiled, .feedRuntime:
    CompiledCardView(task: task, layoutID: task.cardLayoutID).equatable()
}
```

(Note: the feed cases reaching this `switch` branch is dead code in practice — `body` never falls through to
the `List` when `renderMode.isFeed` is true; see `ContentView.body`'s `if/else if` chain.)

---

## Performance Measurement

Unchanged from the original design: `BodyEvalCounter` (native/bdui/nodes/compiled — `nodes` is shared by
both BDUI and Feed interpreted modes; `compiled` is shared by Compiled, FeedC and FeedR) and
`PerformanceMonitor` (`CADisplayLink`-driven FPS + eval/s every 0.5s). New since the original doc:
`ScrollBenchmark` — `.scrollBenchmark(label:)` starts a `CADisplayLink` on scroll-phase-begin and, on
scroll-phase-idle, appends one JSON record (`label`, `durationMs`, `frames`, `fps`, `droppedFrames`,
`hitchTimeMs`, `hitchRatioMsPerS`, `maxFrameMs`, `bodyEvals`) to `Documents/scroll_bench.jsonl` — a
quantitative log to diff across modes instead of eyeballing the live FPS counter.

---

## Key Design Decisions

### Why `JSONValue` instead of `Codable` structs for props?
Unchanged — props can hold strings, numbers, binding expressions, conditionals, gradient objects; a typed
struct would need a case for every possible value.

### Why `NativeComponent` escape hatch?
Unchanged — domain-specific layout math stays in Swift; JSON only describes structure.

### Why `struct TaskDataResolver` (value type)?
Unchanged — cheap `ForEach` child-resolver copies, no heap allocation.

### Why `.equatable()` on every row?
Unchanged — this is still the *only* mechanism in this codebase for skipping a `body` call outright; see the
architecture discussion below for what it would take to get below row granularity.

### Why layout/style/data are three separate top-level documents in Feed, but inline in task cards?
The task-card system was built first, with one JSON tree per card shape and `$`-bindings resolved against a
single `Task`. The Feed system generalizes the same CSS-class idea one step further: *data* is also lifted
out of the tree (`dataId` references, not literal content), so one `layoutId` serves 100 different items with
completely different text/images, and layout/style/data can each change independently without touching the
others — closer to what a real server-driven feed (e.g. a home screen) actually needs, where items and their
shapes vary per user/session but the catalog of layouts does not.

### Why does `LayoutCache` exist (task cards) but not for Feed?
`LayoutCache` demonstrates the *server round-trip* story — versioned responses, async compile, disk
persistence across launches — because that's the part of a real BDUI system that's hardest to get right.
The Feed system instead demonstrates the *three compile-cost strategies* (never / at-load / at-first-render)
side by side without the server-fetch machinery layered on top, to isolate that variable.

### What changing the JSON changes
Edit any `Resources/*.json` and relaunch:
- Task cards (`task_card_layout.json`, `task_compact_layout.json`): structure, style, stylesheet — no Swift
  changes needed. **But see the "stale compiled cache" gotcha below** — Compiled mode may not pick it up
  without bumping the version in `LayoutService.catalog`.
- Feed (`feed_layouts.json`, regenerate with `Scripts/gen_feed.py`): styles, layouts, items — all three
  compile paths (interpreted/FeedC/FeedR) re-derive everything from this file on launch, no caching involved.

---

## Known Gotchas (see also `CLAUDE.md`)

- **Stale compiled cache:** `LayoutService` always reports `version: 1`; the disk cache may already hold
  `version: 1` from a previous run. Editing the bundle JSON without bumping the version means `LayoutCache`
  sees "same version, skip" and the disk-cached (old) compiled layout wins. Bump
  `LayoutService.catalog`'s version tuple, or delete the app, after editing a task-card layout.
- **Interpreter/compiler default mismatch:** `UIComponentView`'s stacks default to `spacing: 0` /
  `VStack` alignment `.center`; `LayoutCompiler`'s default to system spacing (`nil`) / `.leading`. A layout
  that omits these fields will render slightly differently in BDUI vs. Compiled mode.
- **`CompiledCardView.==` doesn't compare `layoutID`** — only `task`. In this app `cardLayoutID` never
  changes for an existing `Task`, so this is latent, not currently triggered.
- **`background` StyleProps field is decoded but never applied** in the task-card `StyleModifier`.
