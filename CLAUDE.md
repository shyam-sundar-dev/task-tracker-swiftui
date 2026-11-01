# Task Tracker Swift UI — Project Reference

SwiftUI POC that benchmarks **Backend-Driven UI (BDUI)** rendering strategies against hand-written SwiftUI.
One list, six render modes, live FPS / body-eval counters, and a per-gesture scroll benchmark log.

`TaskTracker/BDUI_CONTEXT.md` is the narrative walkthrough of the current (6-mode) architecture.
`TaskTracker/BDUI_PLAN.md` is the historical implementation log for Phases 0–6 (all done) plus an open
Phase 8 on sub-row invalidation. `TaskTracker/BDUI_ANYVIEW_NOTES.md` is still accurate (why compiled
builders return `AnyView`). This file is the condensed reference.

## Build facts

- Xcode project: `Task Tracker Swift UI.xcodeproj`, single app target, iOS deployment target **27.0**.
- `SWIFT_VERSION = 5.0`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`
  → types are MainActor by default; off-main code must be marked `nonisolated` (see `LayoutCompiler.compile`).
- Uses **file-system synchronized groups**: new files under `TaskTracker/` join the target automatically (no pbxproj edits).
- The app's model is named `Task`, which shadows Swift Concurrency's `Task`. Always write `Swift.Task { … }` for concurrency.
- No tests, no SPM dependencies. `ContentView.swift` imports `Playgrounds` and has a `#Playground` block.

## File map

```
TaskTracker/
├── MyApp.swift                 App entry: loads task_card_layout (interpreted mode), creates LayoutCache, injects both
├── ContentView.swift           RenderMode enum, list switching, RenderModeSwitcher chips, PerfStatsBar, toolbar
├── Task.swift                  Task / TaskPriority / TaskCategory / Assignee; Task.mockData (100 generated tasks)
├── HeavyTaskRowView.swift      Native baseline card + shared subviews (CategoryPill, PriorityDot, TagChip,
│                               AssigneeStack, MetaLabel) reused by BDUI NativeComponent
├── TaskRowView.swift           Simple early row view — UNUSED by ContentView (has _printChanges/print debug lines)
├── BackendDrivenUI/
│   ├── JSONValue.swift         Recursive Codable JSON enum (+ isBinding / isConditional helpers)
│   ├── UIComponent.swift       UIComponent node, ForEachSpec, ComponentDefinition {componentVersion, stylesheet?, root}
│   ├── StyleProps.swift        Typed style block (FontSpec, FrameSpec, ShadowSpec, FixedSizeSpec) + merging(_:)
│   ├── StyleSheet.swift        typealias StyleSheet = [String: StyleProps]
│   ├── DataResolver.swift      TaskDataResolver: flattens Task into "$key" bindings, modifiers, conditionals, gradients
│   ├── StyleApplying.swift     StyleModifier + applyFont/Foreground/Padding/Frame/Shadow/Clip/TextStyle
│   ├── UIComponentView.swift   Interpreter: one View struct per node; NativeProgressBar, NativeCompletionBadge
│   ├── BackendDrivenTaskRowView.swift  Interpreted row + \.cardComponentDefinition EnvironmentKey
│   ├── LayoutCompiler.swift    Compiles UIComponent tree → CompiledLayout { build: (TaskDataResolver) -> AnyView }
│   ├── CompiledCardView.swift  1-body row; reads LayoutCache by layoutID, else CardSkeletonView
│   ├── CardSkeletonView.swift  Pulsing placeholder (180pt rounded rect)
│   ├── LayoutResponse.swift    Server contract {layoutID, version, layout, stylesheet}
│   ├── LayoutService.swift     Fake server: bundle catalog task_card / task_compact, both version 1
│   ├── LayoutCache.swift       @Observable @MainActor; compiles off-main, version-gated, warms from disk on init
│   ├── LayoutDiskCache.swift   actor; Library/Caches/bdui/<id>_v<version>.json, prunes older versions
│   ├── ComponentLoader.swift   Bundle JSON → ComponentDefinition
│   └── Feed/
│       ├── FeedModels.swift    FeedDocument {styles, layouts, items}, FeedNode (final class), FeedData, FeedStyle, FeedLoader
│       ├── FeedNodeView.swift  Interpreted feed: one body per node; FeedListView
│       ├── FeedStyleModifier.swift  FeedStyleModifier, ifLet helper, FeedParse (colors incl. #RRGGBB[AA], fonts, alignments)
│       ├── FeedCompiler.swift  CompiledFeed (closures built at load), ResolvedFeedStyle, compiledFeedStyle, ifTrue helper
│       └── FeedRuntime.swift   Walks raw layout inside row body (no load-time work), memoises ResolvedFeedStyle
├── Performance/
│   ├── BodyEvalCounter.swift   @MainActor singleton counters: native / bdui / nodes / compiled
│   ├── PerformanceMonitor.swift @Observable; CADisplayLink via DisplayLinkProxy, samples every 0.5s (fps, evals/s)
│   └── ScrollBenchmark.swift   .scrollBenchmark(label:) — per-gesture JSONL to Documents/scroll_bench.jsonl
└── Resources/
    ├── task_card_layout.json     Full card (~28 nodes), stylesheet: card-title, card-subtitle, progress-label, progress-pct
    ├── task_compact_layout.json  Compact row, stylesheet: compact-title, compact-date
    └── feed_layouts.json         ~1 MB minified, GENERATED: 78 styles, 10 layouts, 1000 items (100 per layout)
Scripts/gen_feed.py               Generates feed_layouts.json
```

## Render modes (`RenderMode` in ContentView.swift)

| Mode | rawValue | Renderer | Counter ticked | Cost model |
|---|---|---|---|---|
| native | `Native` | `HeavyTaskRowView` | `native` | 1 body / row |
| bdui | `BDUI` | `BackendDrivenTaskRowView` → `UIComponentView` tree | `bdui` + `nodes` | 1 + ~28 bodies / row |
| compiled | `Compiled` | `CompiledCardView(task:layoutID: task.cardLayoutID)` | `compiled` | 1 body / row |
| feed | `Feed` | `FeedListView` → `FeedNodeView` tree | `nodes` | 1 body / node |
| feedCompiled | `FeedC` | `CompiledFeedListView` → `CompiledFeedRow` | `compiled` | 1 body / row, compile at load |
| feedRuntime | `FeedR` | `RuntimeFeedListView` → `RuntimeFeedRow` | `compiled` | 1 body / row, walk at render |

- Selected mode persists in `UserDefaults` key `renderMode`; switching calls `perf.reset()`.
- Task modes share the `tasks` list; feed modes use static `feedDocument` / `compiledFeed` / `feedRuntime` on `ContentView`.
- Native-only toolbar picker `OverlayMode`: `100 Views` (100 Text overlays), `100 Data Loops` (CPU loop, 1 Text), `None`.
- Bottom bar: "Reset Stats" and "Change Cell 0 Title" (demonstrates `.equatable()` — only row 0 re-renders).
- Every row view is `Equatable` and wrapped in `.equatable()`. Task rows compare `task`; feed rows compare `item.id`.
- `Task.cardLayoutID`: every 3rd task (`i % 3 == 2`) is `task_compact`, the rest `task_card`.

## Task-card BDUI schema (`UIComponent`)

```json
{ "type": "...", "props": {...}, "style": {...}, "styleClass": "name", "children": [...],
  "forEach": { "dataBinding": "$task.tags", "itemAlias": "tag" }, "comment": "ignored" }
```

- **Types:** ZStack, HStack, VStack, Text(`content`), Image(`systemName`), Spacer, Divider, RoundedRectangle
  (`cornerRadius`), Capsule, Circle, ForEach, NativeComponent(`name`). Unknown → `EmptyView`.
- **NativeComponent names:** CategoryPill, PriorityDot, CompletionBadge, AssigneeStack (always uses
  `resolver.task.assignees`), TagChip(`label`), MetaLabel(`symbol`,`value`), ProgressBar(`progress`,`color`).
- **Style resolution:** `styleClass` from stylesheet is the base, inline `style` wins per non-nil field (`StyleProps.merging`).
- **StyleProps:** font{named|size,weight}, foregroundStyle, fill, background, padding (number or
  {all|top/leading/bottom/trailing}), frame{width,height,maxWidth,maxHeight ("infinity"), alignment},
  cornerRadius, clipShape (capsule|roundedRectangle|circle), shadow{color,radius,x,y}, opacity, lineLimit,
  strikethrough (bool or binding), fixedSize{horizontal,vertical}.
  - `fill` only applies to shapes (stripped via `withoutFill` before StyleModifier).
  - `background` is decoded but **never applied** by `StyleModifier`.
- **Bindings (`TaskDataResolver`):** keys `task.title/description/isCompleted/progress/tags/dueDate/commentCount/
  attachmentCount/coverSymbol/priority/category`, plus `categoryColor` and any ForEach `itemAlias`.
  - `$key|opacity:0.12` (colors), `$key|percent`. Note `stringify` renders *any* Double as a percent.
  - Conditional: `{"type":"conditional","condition":"$task.isCompleted","true":...,"false":...}`.
  - Fill/foreground gradient: `{"type":"linearGradient","colors":[...],"startPoint":"topLeading","endPoint":"..."}`.
  - Named colors limited to the `namedColor` switch; `secondary` maps to the `.secondary` shape style.

## Compiled pipeline & caching

```
ContentView.task → LayoutService.fetchAll() → LayoutCache.receive(response)
  receive: skip if versions[id] >= version → Swift.Task.detached { LayoutCompiler.compile }
         → MainActor: layouts[id], versions[id] → LayoutDiskCache.save(response)
LayoutCache.init → warmFromDisk(): loadAll() → compile each → publish if newer than in-memory
CompiledCardView: cache.layout(for: layoutID) ?? CardSkeletonView()
```

- `LayoutCompiler` pre-parses alignments/spacing/native names once; closures capture child builders and
  use `ForEach(0..<builders.count, id: \.self)`.
- `CompiledStyleModifier` just wraps `StyleModifier` (kept separate from the interpreter path on purpose).

## Feed schema (`feed_layouts.json`)

- Three independent concerns: `styles` (styleId → FeedStyle), `layouts` (layoutId → FeedNode tree), `items`
  (`{id, layoutId, data: {dataId → FeedData}}`). Nodes reference only `styleId` / `dataId`.
- **Node types:** vstack, hstack, zstack, label, image, spacer, divider, progress, carousel (horizontal
  `LazyHStack`, `inset`), grid (`LazyVGrid`, `columns`), vlist (nested vertical ScrollView — give it a height).
  Collections render `template` once per `data[dataId].items` entry, with that entry as the new data scope.
- **FeedData:** text, symbol (SF Symbol), url (AsyncImage), value (progress 0…1), items.
- **FeedStyle:** font/fontSize/weight/design, lineLimit, textAlignment, strikethrough, uppercase, foreground,
  background, gradient (≥2 stops, overrides background), opacity, padding/paddingH/paddingV, width/height,
  fillWidth, frameAlignment, cornerRadius, borderColor/borderWidth, shadowRadius/shadowColor, contentMode.
- Interpreted `FeedStyleModifier` always applies padding/frame/clip/shadow; compiled `compiledFeedStyle`
  applies only declared properties (avoids extra render passes), but keeps `.clipped()` on fixed frames to match.
- Image precedence differs: FeedNodeView prefers `url`, FeedCompiler/FeedRuntime prefer `symbol`.

Regenerate the feed (seeded RNG 42; second arg = copies, 10 copies → 1000 items):

```bash
python3 Scripts/gen_feed.py TaskTracker/Resources/feed_layouts.json 10
```

Layouts: hero, chips_h, resto_h, stats_grid, tracking, stories_h, coupons_h, grocery_grid, articles_vscroll,
weather_nested_h. The script also defines unused styles (profile, pricing, music) and validates styleIds.

## Gotchas / known divergences

- **Bundle JSON edits may not show in Compiled mode.** `LayoutService` hardcodes version 1 and the disk cache
  persists v1; once disk warm-up wins, a same-version `receive` is skipped. Bump the version in
  `LayoutService.catalog` (or delete the app) after editing `task_card_layout.json` / `task_compact_layout.json`.
  BDUI (interpreted) mode always reads the bundle directly.
- `receive` checks the version before compiling but not when publishing, and two in-flight receives for the
  same id can both compile.
- Interpreter vs compiler defaults differ: `UIComponentView` stacks default `spacing` to 0 and VStack alignment
  to `.center`; `LayoutCompiler` uses system spacing (`nil`) and VStack `.leading`. Layouts that omit these
  render differently between BDUI and Compiled modes.
- `CompiledCardView ==` ignores `layoutID`.
- `UIComponent.instanceID` exists but renderers use index/offset identity.
- `FeedRuntime` is a `@MainActor` class mutated (style memo) during `body`.
- `ScrollBenchmark` appends to `Documents/scroll_bench.jsonl` in the app sandbox; each record has label, durationMs,
  frames, fps, droppedFrames, hitchTimeMs, hitchRatioMsPerS, maxFrameMs, bodyEvals.

## Conventions

- Column-aligned assignments and `// MARK: -` sections; short `//` comments explaining *why*.
- Keep interpreter (`UIComponentView`, `FeedNodeView`) and compiled (`LayoutCompiler`, `FeedCompiler`,
  `FeedRuntime`) paths feature-matched when adding a node type or style property.
- New NativeComponent: add the view (internal, not private), then a case in both `UIComponentView.renderNative`
  and `LayoutCompiler.native`.
- Per-node counters: interpreted nodes call `nodeTick()`, single-body rows call `compiledTick()`.
