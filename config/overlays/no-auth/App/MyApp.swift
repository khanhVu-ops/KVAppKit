import SwiftUI
import KVRouterKit
import KVToastKit
import KVLoggingKit
import KVLoggingSwiftUI
import KVDIKit

@main
struct MyApp: App {

    @StateObject private var router: KVAppRouter
    @StateObject private var language: LanguageStore

    private let toastCenter: KVToastCenter
    private let logger: LogClient

    // The composition root. Everything the app is wired from happens here, once,
    // in an order that matters:
    init() {
        // A hosted test bundle launches the app first, so this runs before every
        // test run. Tests build their own dependencies explicitly and need none
        // of the below — booting it would make them slower and dependent on the
        // network stack.
        if AppEnvironment.isRunningTests {
            let logger = LogClient.disabled
            let toastCenter = KVToastCenter()
            let router = KVAppRouter()
            self.logger = logger
            self.toastCenter = toastCenter
            _router = StateObject(wrappedValue: router)
            _language = StateObject(wrappedValue: LanguageStore(defaults: .previewDefaults))
            return
        }

        // 1. Logging first, so anything that fails after this point is recorded.
        let logger = AppBootstrap.startLogging()

        // 2. The main-actor objects the app owns for its whole life.
        let toastCenter = KVToastCenter()
        let language = LanguageStore()
        let router = KVAppRouter(middlewares: [
            NavigationLogMiddleware(logger: logger)
        ])

        // 3. Fill the app layer of the dependency graph. Keys whose live value
        //    needs one of the objects above cannot resolve before this runs —
        //    everything else already resolves on read, so order is not a trap.
        //
        //    An app with a sign-in adds `$0.authInterceptors = [...]` here; that
        //    one line is the whole difference, because the API client resolves
        //    on first read and picks up whatever this block left behind.
        KVDependencies.prepare {
            $0.logger = logger
            $0.toast = .live(toastCenter, language: language)
            $0.router = router
        }

        self.logger = logger
        self.toastCenter = toastCenter
        _router = StateObject(wrappedValue: router)
        _language = StateObject(wrappedValue: language)

        logger.info("Application launched", category: "lifecycle")
    }

    var body: some Scene {
        WindowGroup {
            KVRouterHost(router: router, defaultTransition: .system) {
                RootView()
            }
            .appRoutes()
            // Deep links are parsed by the app and pushed as ordinary typed
            // routes, so a linked screen is indistinguishable from a tapped one
            // — same registry, same middleware, same restoration.
            .onOpenURL { url in
                guard let route = AppDeepLink.route(for: url) else { return }
                router.setPath(AppDeepLink.stack(for: route))
            }
            .kvToast(style: AppToast.style, center: toastCenter)
            .kvLogging(logger)
            // Ngôn ngữ chọn trong app đi vào đây, và SwiftUI resolve lại mọi
            // `Text` mang key. Không ghi `AppleLanguages` + bắt khởi động lại.
            .environment(\.locale, language.locale)
            .environmentObject(language)
            // `.id` để đổi ngôn ngữ là **rebuild cả cây**. Không có nó thì `Text`
            // đổi ngay nhưng `navigationTitle` thì không: title do navigation bar
            // của UIKit vẽ và nó không resolve lại khi environment đổi — đã thấy
            // tận mắt, tiêu đề giữ nguyên tiếng Việt tới khi mở lại màn.
            // Stack không mất: `KVAppRouter` giữ path bên ngoài view identity.
            .id(language.current)
        }
    }
}
