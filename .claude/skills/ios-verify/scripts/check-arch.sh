#!/usr/bin/env bash
#
# Enforces the layering rules on a single-target app.
#
# Why this file carries more weight here than in a multi-module setup: files in
# the same Swift module see each other with no `import` line at all. So
# "Features must not touch Data" cannot be checked by grepping imports — there is
# nothing to grep. Instead this script reads the *type names declared in each
# folder* and then looks for those names being used from folders that should not
# know them. That derives the rule from the source itself, so it keeps working as
# the code grows and never needs a hand-maintained list.
#
# Framework imports (SwiftUI, KVNetworkit, …) are still real imports, so those
# rules stay simple.
#
# Usage:  ./tools/check-arch.sh        Exit 0 = clean, 1 = at least one violation.

set -uo pipefail
cd "$(dirname "$0")/.."

failures=0

# grep, nhưng bỏ những dòng khớp mà nội dung bắt đầu bằng comment.
# Doc comment nhắc tên type là chuyện bình thường và đáng khuyến khích —
# `/// `OrderDTO` in Data is what the backend sends` không phải vi phạm.
code_grep() {
    grep -rnE "$@" 2>/dev/null | grep -vE ':[0-9]+:[[:space:]]*(///?|\*|/\*)' || true
}

fail() { printf '\033[31m✗\033[0m %s\n' "$1"; shift; printf '    %s\n' "$@"; failures=$((failures + 1)); }
pass() { printf '\033[32m✓\033[0m %s\n' "$1"; }

# Top-level type names declared under a folder.
declared_types() {
    code_grep '^(final |public |internal )*(struct|class|enum|protocol|actor) [A-Z][A-Za-z0-9_]*' \
        --include="*.swift" "$1" \
        | grep -oE '(struct|class|enum|protocol|actor) [A-Z][A-Za-z0-9_]*' \
        | awk '{print $NF}' | sort -u
}

# Uses of any name in $2 (newline-separated) from the folders in $3...
uses_of() {
    local names="$1"; shift
    [ -n "$names" ] || return 0
    local pattern
    pattern="\\b($(echo "$names" | paste -sd'|' -))\\b"
    code_grep "$pattern" --include="*.swift" "$@"
}

# ---------------------------------------------------------------------------
# 1. Domain and Core stay free of delivery frameworks.
#    These are real imports, so this is a plain check. The moment Domain imports
#    SwiftUI or a networking package, business rules stop being testable in
#    milliseconds and start needing a simulator.
# ---------------------------------------------------------------------------
hits=$(code_grep '^import (SwiftUI|UIKit|KVNetworkit|KVRouterKit|KVRouterCore|KVDIKit|KVToastKit|KVLoggingKit)' \
    --include="*.swift" Core Domain)
if [ -n "$hits" ]; then
    fail "Core/Domain imports a delivery framework" "$hits"
else
    pass "Core and Domain import nothing but Foundation"
fi

# ---------------------------------------------------------------------------
# 2. Domain does not know Data exists.
#    Derived from the source: every type declared under Data/ must be absent from
#    Domain/ and Core/. This is the dependency inversion the whole layering rests
#    on — Data implements Domain's protocols, never the other way round.
# ---------------------------------------------------------------------------
data_types=$(declared_types Data)
hits=$(uses_of "$data_types" Core Domain)
if [ -n "$hits" ]; then
    fail "Domain/Core references a type declared in Data" "$hits"
else
    pass "Domain does not know Data exists ($(echo "$data_types" | wc -l | tr -d ' ') types checked)"
fi

# ---------------------------------------------------------------------------
# 3. Features never touch Data.
#    A feature that reaches for a concrete repository has skipped the protocol
#    that makes it testable, and coupled a screen to a wire format.
#
#    Data/Testing is exempt as a *source* of names: stubs exist to be injected
#    into tests, and DI names them for `testValue`.
# ---------------------------------------------------------------------------
data_types_no_stubs=$(declared_types Data | grep -vE '^(Stub|InMemory)' || true)
hits=$(uses_of "$data_types_no_stubs" Features)
if [ -n "$hits" ]; then
    fail "A feature references a type declared in Data" "$hits"
else
    pass "No feature touches Data"
fi

# ---------------------------------------------------------------------------
# 4. ViewModels do not reach into the view layer.
#    `pushView` needs KVViewRouting, which only KVRouterKit exposes. A ViewModel
#    that builds a view cannot be tested against KVRouterSpy, and has moved a
#    presentation decision into the model layer.
# ---------------------------------------------------------------------------
hits=""
while IFS= read -r file; do
    [ -n "$file" ] || continue
    # Strip trailing comments first. A line like
    #   import KVRouterCore   // no SwiftUI here, so `pushView` is unreachable
    # is prose about the rule, not a violation of it — and the first version of
    # this check flagged exactly that, in this repo's own source.
    code="$(sed 's|//.*||' "$file")"
    grep -qE '^import (KVRouterKit|SwiftUI)[[:space:]]*$' <<<"$code" \
        && hits="$hits$file: imports KVRouterKit/SwiftUI (use KVRouterCore)"$'\n'
    # `\bpushView\b`, not `pushView\(`: the common spelling is a trailing
    # closure — `router.pushView { DetailView() }` — which has no paren at all.
    # The paren-only pattern silently passed that, which the self-test caught.
    grep -qE '\bpushView\b' <<<"$code" \
        && hits="$hits$file: calls pushView (that belongs in the View)"$'\n'
done < <(find Core Domain Data DI Features App -name "*ViewModel.swift" 2>/dev/null)
if [ -n "$hits" ]; then
    fail "ViewModel reaches into the view layer" "$hits"
else
    pass "ViewModels stay on KVRouterCore"
fi

# ---------------------------------------------------------------------------
# 5. Transport errors do not escape Data.
#    They are mapped to AppError at the repository boundary. A ViewModel
#    switching on a status code breaks the day the transport changes.
# ---------------------------------------------------------------------------
hits=$(code_grep '\bKVAPIClientError\b|\bKVAPIEndpointProtocol\b|\bJSONDecoder\b' \
    --include="*.swift" Core Domain Features)
if [ -n "$hits" ]; then
    fail "A transport type leaked out of Data" "$hits"
else
    pass "Only AppError crosses layer boundaries"
fi

# ---------------------------------------------------------------------------
# 6. No colour literals outside DesignSystem.
#    A hard-coded colour cannot be restyled, has no dark variant, and is
#    invisible to whoever regenerates tokens from Figma.
# ---------------------------------------------------------------------------
hits=$(code_grep 'Color\((red:|hex:)|#colorLiteral' --include="*.swift" Features App Domain Data)
if [ -n "$hits" ]; then
    fail "Colour literal outside DesignSystem" "$hits"
else
    pass "All colours come from DesignSystem"
fi

# ---------------------------------------------------------------------------
# 7. Child views take values, not the ViewModel.
#    On iOS 16 `ObservableObject` invalidates per object, so a child holding the
#    ViewModel re-renders on every unrelated change. Handing it a value lets
#    SwiftUI skip the subtree — this is the whole iOS 16 performance strategy.
#    A screen owning its ViewModel with @StateObject is the allowed case.
# ---------------------------------------------------------------------------
hits=""
while IFS= read -r file; do
    [ -n "$file" ] || continue
    case "$(basename "$file")" in *ViewModel.swift) continue ;; esac
    found=$(grep -nE '(let|var) +[a-zA-Z]+ *: *[A-Z][A-Za-z]*ViewModel' "$file" \
        | grep -v '@StateObject' || true)
    [ -n "$found" ] && hits="$hits$file:"$'\n'"$found"$'\n'
done < <(find Features App DesignSystem -name "*.swift" 2>/dev/null)
if [ -n "$hits" ]; then
    fail "A child view holds a ViewModel instead of values" "$hits"
else
    pass "Child views take values, not ViewModels"
fi

# ---------------------------------------------------------------------------
# 8. Dependency keys live in DI only.
#    Features read keys; only the composition root writes them. A key declared
#    inside a feature is a feature deciding its own wiring, which is how two
#    screens end up with two different instances of the same repository.
# ---------------------------------------------------------------------------
hits=$(code_grep 'KVDependencyKey' --include="*.swift" Core Domain Data Features App)
if [ -n "$hits" ]; then
    fail "A dependency key is declared outside DI/" "$hits"
else
    pass "All dependency keys live in DI/"
fi

echo
if [ "$failures" -gt 0 ]; then
    printf '\033[31m%d architecture rule(s) violated.\033[0m\n' "$failures"
    exit 1
fi
printf '\033[32mArchitecture rules OK.\033[0m\n'
