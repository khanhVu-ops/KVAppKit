# KVApp iOS Starter Kit — shared rules

Canonical rule set for both Codex and Claude Code. `CLAUDE.md` imports this file;
do not duplicate architecture detail there or the two will drift.

> **Initialise first.** A new repository runs `tools/init-base.sh` to pull a
> pinned KVAppBase, then replaces the app name and bundle id. After that, update
> the sections below to describe the app you are actually building.

## 1 · Stack

| Concern | Choice |
|---|---|
| UI | SwiftUI, iOS 16+ |
| State | `ObservableObject` + one `State` struct + `send(_ action:)` |
| Navigation | KVRouterKit 3.2 (`KVRouting` port for ViewModels) |
| DI | KVDIKit (keys declared only in `DI/`) |
| Networking | KVNetworkit 2.x (lives in `Data`, errors mapped at that boundary) |
| Logging | KVLoggingKit (privacy-declared metadata) |
| Toast | KVToastKit behind the `ToastService` port |
| Project files | XcodeGen (`project.yml`) — never edit `.xcodeproj` by hand |
| Language mode | Swift 6, `SWIFT_STRICT_CONCURRENCY: complete` |

## 2 · Folder layout

One app target, layered by folder. There is no SPM package: the layering is
enforced by `tools/check-arch.sh` instead of by the compiler, because files in
the same module see each other with no `import` line to check.

```
Core/           Loadable · AlertState · AppError · AppEnvironment      (Foundation only)
Domain/         Entities · Repositories (protocol) · Services (ports) · UseCases
Data/           DTO · Endpoints · Interceptors · Mapping · Local · Repositories · Testing
DI/             every KVDependencyKey, and nowhere else
DesignSystem/   Foundation (tokens) · Components · Modifiers · Toast
Features/       Auth/ · Order/            one folder per flow, not per screen
App/            entry · Navigation · Bootstrap · Session · Resources
Tests/          DomainTests · DataTests · FeatureTests
tools/          check-arch.sh · check-arch-selftest.sh · verify.sh
```

Dependency direction runs Core → Domain → Data → DI → DesignSystem → Features →
App. Nothing points back up.

Because the compiler no longer stops a violation, two things matter more here
than they would in a multi-module setup:

- `check-arch.sh` derives its rules from the source (it reads the type names
  declared under `Data/` and looks for them elsewhere), so it keeps working as
  the code grows without a hand-maintained list.
- `check-arch-selftest.sh` proves each rule still catches a real violation. A
  rule that quietly stops matching is worse than no rule, because the green tick
  then certifies the opposite of what it claims.

## 3 · The four rules that are not negotiable

Each has a reason, and each is checked by `tools/check-arch.sh` in CI.

1. **`Domain` imports Foundation and nothing else.** The moment it imports
   SwiftUI or a networking package, business rules stop being testable in
   milliseconds and start needing a simulator.
2. **`KVAPIClientError` never leaves `Data`.** Repositories map it to `AppError`.
   A ViewModel switching on a status code breaks the day the transport changes.
3. **A feature never imports `Data`.** It talks to repository *protocols* from
   `Domain`, which is what makes a screen testable with a stub.
4. **Child views take values, not the ViewModel.** On iOS 16 `ObservableObject`
   invalidates per object, so a child holding the ViewModel re-renders on every
   unrelated change. Handing it a value lets SwiftUI skip the subtree — this is
   the entire iOS 16 performance strategy, not a style preference.

## 4 · State, action, navigation

- One `State` struct per screen, `Equatable`, nested in the ViewModel. Derived
  values are computed properties — a stored copy is a second source of truth.
- One `enum Action`, and `send(_:)` is the only way `state` changes.
- Alerts and sheets are **state**, not one-shot effects: they survive a rebuild
  and can be asserted without SwiftUI. There is no `ViewEffect` channel here.
- **ViewModel pushes routes** through `any KVRouting`. **View pushes views** with
  `router.pushView { }` when it already holds the object — that is the
  UIKit-style ergonomics KVRouterKit exists for. Route ceremony is only paid for
  screens that must be addressable: deep link, notification, restoration.
- `.cancelled` shows nothing. `.unauthorized` is left to `SessionController` —
  every screen handling it produces a pile of alerts on the way out.

## 5 · Commands

```bash
xcodegen generate                    # after adding or moving files
./tools/check-arch.sh                # layering rules
./tools/verify.sh                    # build + test + arch, all three
```

Never hand-edit `MyApp.xcodeproj`; it is generated and gitignored.

## 6 · Skills

Load the relevant skill before starting. They are the detail this file
deliberately does not repeat.

| Task | Skill |
|---|---|
| Any Swift file: where does this go, which layer, what may it import | `ios-architecture` |
| Touching any `KV*` symbol — router, DI, network, toast, logging | `kv-packages` |
| A whole feature, end to end | `ios-feature` |
| Build, test, screenshot, confirm it works | `ios-verify` |
| Brand-new repository | `init-base` |
