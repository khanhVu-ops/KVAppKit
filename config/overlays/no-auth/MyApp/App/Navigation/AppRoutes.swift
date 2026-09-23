import SwiftUI
import KVRouterKit

// The only place in the app where a route meets a view.
//
// Each feature registers its own route type, so one feature never has to know
// another exists and no single enum has to be edited by everyone. A route type
// that is never registered trips an assertion in debug rather than rendering a
// blank screen.
//
// Nothing is registered yet. A feature declares its own `KVRoute` enum next to
// its screens, then adds one block here:
//
//     routes.register(OrderRoute.self) { route in
//         switch route {
//         case .detail(let id): OrderDetailView(orderID: id)
//         case .history:        OrderHistoryView()
//         }
//     }
//
// The closure runs once per view identity, so a destination must not capture
// state that changes — pass identity in and let the screen read the live value.
extension View {

    func appRoutes() -> some View {
        kvRoutes { _ in
        }
    }
}
