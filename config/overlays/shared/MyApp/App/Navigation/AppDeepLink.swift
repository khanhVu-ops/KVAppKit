import Foundation
import KVRouterCore

/// URL shapes belong to the app, so parsing lives here — as a pure function that
/// unit-tests without a router, a host or a simulator.
///
/// Nothing is mapped yet; the seam is here so the app never grows a second way
/// of opening a screen. Add cases as routes appear:
///
///     case "order":
///         return rest.first.map { OrderRoute.detail(id: $0) }
enum AppDeepLink {

    /// `myapp://order/42` → the route for that screen.
    static func route(for url: URL) -> (any KVRoute)? {
        var parts: [String] = []
        if let host = url.host, !host.isEmpty { parts.append(host) }
        parts.append(contentsOf: url.pathComponents.filter { $0 != "/" })
        return route(components: parts)
    }

    static func route(components parts: [String]) -> (any KVRoute)? {
        guard let head = parts.first else { return nil }
        let rest = Array(parts.dropFirst())
        switch (head, rest) {
        default: return nil
        }
    }

    /// The full stack a link should land on, not just the leaf.
    ///
    /// Pushing only the destination leaves the user one back-swipe from falling
    /// out of the app. Giving the link a stack means Back walks them into it —
    /// so a detail route should return `[list, detail]`, not `[detail]`.
    static func stack(for route: any KVRoute) -> [any KVRoute] {
        [route]
    }
}
