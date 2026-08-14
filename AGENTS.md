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

## 3a · Preview

Every `struct … : View` ships with a `#Preview` using mock data from `Fixtures.swift`,
and `check-arch.sh` fails without one. A preview is the only cheap way to see a screen
empty, failed, in dark mode, with a long name, or in another language — states that are
tedious or impossible to reach by running the app. A view with no preview is a view
nobody looks at, so it breaks quietly.

## 3b · Text

The app declares **19 languages** (en source · ar · zh-Hans · zh-Hant · nl · fr · de ·
hi · id · it · ja · ko · pt-BR · pt-PT · ru · es · th · tr · vi) as one `.strings` file
each: `App/Resources/<lang>.lproj/Localizable.strings`. Not a String Catalog — the build
rewrites those, and flat files diff, merge and hand to a translation vendor. XcodeGen
derives `knownRegions` from the `.lproj` directories, so adding a language is adding a
directory.

**Any new user-facing string ships with all 19 translations in the same commit.** Not
"English for now": a missing translation breaks nothing, fails no test, and logs
nothing — it silently falls back to English until a real user opens the app in Thai.
Debt nobody chases is debt nobody pays, so it is refused at the door.
`tools/check-l10n.sh` enforces it and runs inside `verify.sh`; the template's existing
hardcoded strings live in `tools/l10n-baseline.txt`, which may only shrink. A missing
`;` makes CFBundle drop an entire file silently, so every file is linted, not just the
source one.

Keys are the English text (`Text("Orders")`), not identifiers. Text that crosses layers
— `AppError.userMessage`, `AlertState`, a use case's validation message, a toast — is
typed `LocalizedStringResource`, which is Foundation and therefore legal in `Domain`.

Not `String`. `String(localized:)` and `value.formatted(…)` both resolve immediately
against the *device* language, so text built that way keeps the system language after
the user picks another one in the app — measured on a simulator, and the reason
`check-l10n.sh` refuses both outside the one bridge that needs them. Load the `ios-l10n`
skill for that table, plurals, RTL, and the in-app language switch.

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
./tools/check-l10n.sh                # new text is translated into all 19 languages
./tools/verify.sh                    # all of the above + build + test
./tools/doctor.sh                    # rule and skill still describe this repo

fastlane ios build_only              # signed .ipa, no upload
fastlane ios beta                    # TestFlight
fastlane ios web_test                # ad-hoc → internal App Distribution
fastlane ios release                 # App Store, not submitted for review
```

`verify.sh` runs in CI on every push and PR (`.github/workflows/verify.yml`), so the
rules above are enforced rather than remembered. Releases are dispatched by hand from
the Actions tab and build on a self-hosted macOS runner that holds the signing
certificate — the certificate never leaves that machine. Every lane regenerates the
project first, because `.xcodeproj` is generated and gitignored, and version lives in
`project.yml` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`), never in a plist.

Never hand-edit `MyApp.xcodeproj`; it is generated and gitignored.

A `PostToolUse` hook (`.claude/settings.json` → `tools/xcodegen-if-needed.sh`)
regenerates the project when a **new** `.swift` file appears, and stays silent
otherwise. It removes the most repeated trap of a single-target layout — a file that
exists on disk and not in the project, which the compiler reports as "cannot find
in scope". Moving or deleting files is still on you: run `xcodegen generate`.

## 6 · Skills

Load the relevant skill before starting. They are the detail this file
deliberately does not repeat.

| Task | Skill |
|---|---|
| Any Swift file: where does this go, which layer, what may it import | `ios-architecture` |
| Touching any `KV*` symbol — router, DI, network, toast, logging | `kv-packages` |
| A whole feature, end to end | `ios-feature` |
| Any string a user reads — new text, a language, plurals, RTL | `ios-l10n` |
| One API endpoint: DTO, path, cache policy, mapping, test | `ios-endpoint` |
| A spec (OpenAPI, Postman) arrives and has to become an inventory | `api-intake` |
| Build, test, screenshot, confirm it works | `ios-verify` |
| A command failed, or the app misbehaves in a way that smells like the environment | `ios-troubleshoot` |
| Review a diff against the repo's own rules | `ios-review` |
| Map what this repo currently contains | `project-overview` |
| Brand-new repository | `init-base` |

`ios-troubleshoot` is worth loading *before* theorising about a failure: most of
what it lists looks like a code bug and is a stale cache, an unregenerated project
file, or a simulator that had not finished booting.
