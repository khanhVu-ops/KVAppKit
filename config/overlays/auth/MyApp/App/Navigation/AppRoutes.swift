import SwiftUI
import KVRouterKit

// The only place in the app where a route meets a view.
//
// Each feature registers its own route type, so one feature never has to know
// another exists and no single enum has to be edited by everyone. A route type
// that is never registered trips an assertion in debug rather than rendering a
// blank screen.
//
// The closure runs once per view identity, so a destination must not capture
// state that changes — pass identity in and let the screen read the live value.
extension View {

    func appRoutes() -> some View {
        kvRoutes { routes in

            routes.register(AuthRoute.self) { route in
                switch route {
                case .signIn:                    SignInView(onSignedIn: { _ in })
                case .forgotPassword(let email): ForgotPasswordView(email: email)
                }
            }

            // Feature nào cần đăng nhập thì cho route của nó conform
            // `RequiresAuthentication` — AuthGuardMiddleware đọc đúng cái đó và
            // không bao giờ phải biết tên feature.
        }
    }
}
