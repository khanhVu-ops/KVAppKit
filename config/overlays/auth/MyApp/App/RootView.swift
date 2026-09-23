import SwiftUI

/// Chooses the root screen from session state. Sign-in is not pushed onto the
/// stack: swapping the root means there is no back gesture out of the login
/// screen and nothing of the signed-in session left underneath it.
///
/// The signed-in half is scaffolding — replace it with the app's first real
/// screen. The signed-out half is not: `SignInView` is wired to the use case,
/// the keychain and `SessionController`, and adapting it is cheaper than
/// rebuilding that wiring.
struct RootView: View {

    @ObservedObject var session: SessionController

    var body: some View {
        Group {
            if session.isSignedIn {
                signedInPlaceholder
            } else {
                SignInView(onSignedIn: session.didSignIn)
            }
        }
        .background(AppColor.Surface.background)
    }

    // `verbatim:` on purpose: scaffolding is not product copy, and it must not be
    // sent to nineteen translators. Real text goes through the .strings tables.
    private var signedInPlaceholder: some View {
        VStack(spacing: Spacing.s) {
            Text(verbatim: "Signed in")
                .font(AppFont.titleM)
            Text(verbatim: "Features/ · replace me")
                .font(AppFont.caption)
                .foregroundStyle(AppColor.Text.secondary)
            Button(action: session.signOut) {
                Text(verbatim: "Sign out")
            }
            .buttonStyle(.primary)
            .padding(.top, Spacing.m)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // `.primary` giãn hết chiều ngang, nên không có padding thì nút chạm sát
        // hai mép màn hình. `Spacing.l` là đúng cái `SignInView` dùng — hai màn
        // này thay nhau ở root, lệch lề là thấy ngay lúc đăng nhập xong.
        .padding(.horizontal, Spacing.l)
    }
}

#Preview {
    RootView(session: SessionController(logger: .disabled))
}
