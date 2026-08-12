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
| Navigation | KVRouterKit 3.1 (`KVRouting` port for ViewModels) |
| DI | KVDIKit (keys declared only in `AppDI`) |
| Networking | KVNetworkit 2.x (lives in `Data`, errors mapped at that boundary) |
| Logging | KVLoggingKit (privacy-declared metadata) |
| Toast | KVToastKit behind the `ToastService` port |
| Project files | XcodeGen (`project.yml`) — never edit `.xcodeproj` by hand |
| Language mode | Swift 6, `SWIFT_STRICT_CONCURRENCY: complete` |

## 2 · Module graph

The graph in `Packages/AppModules/Package.swift` **is** the architecture. A layer
cannot import what its target does not depend on, so a mistake is a build error.

```
AppFoundation   Foundation only            Loadable · AlertState · AppError · AppEnvironment
Domain          → AppFoundation            Entities · Repository protocols · UseCases · ports
Data            → Domain + KVNetworkit     DTO · Endpoints · Repository impls · mapping
AppDI           → Domain + Data + KVDIKit  every dependency key, and nowhere else
DesignSystem    → AppFoundation + KVToast  tokens · components · toast style
Feature*        → Domain + DesignSystem + AppDI + KVRouter{Core,Kit}
App             → everything               composition root only
```

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
