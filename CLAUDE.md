# KVApp iOS Starter Kit — Claude Code

@AGENTS.md

## Before writing Swift

Load `ios-architecture`. It answers "which layer does this belong in" without
you having to read the whole tree, and it is short by design.

If the change touches a `KV*` symbol — `KVRouting`, `pushView`, `@KVDependency`,
`KVAPIEndpointProtocol`, `toast`, a logger — load `kv-packages` too. These are
private packages: they are not in training data, their APIs changed in 2026, and
guessing produces code that looks right and does not compile.

## Initialising a new repository

`/init-base <App Name> <bundle.id>` — only in an empty repository. The script
refuses to overwrite an existing project.

## Keeping the two runtimes in sync

`.agents/skills` is a symlink to `.claude/skills`, so Codex and Claude Code read
the same files. Edit once. If you find yourself copying a skill, the symlink is
broken — restore it rather than maintaining two copies.
