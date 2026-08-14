import SwiftUI

/// The first screen, and the one thing here you are meant to throw away.
///
/// It is deliberately not a feature: features live in `Features/<Flow>/`, and the
/// root's only job is to say which one the app opens on.
struct RootView: View {

    var body: some View {
        VStack(spacing: Spacing.s) {
            // `verbatim:` on purpose: this is scaffolding, not product copy, and
            // scaffolding must not be sent to nineteen translators. Every string
            // that survives into the real app goes through the .strings tables —
            // tools/check-l10n.sh enforces that the moment you write one.
            Text(verbatim: "RootView")
                .font(AppFont.titleM)
            Text(verbatim: "Features/ · replace me")
                .font(AppFont.caption)
                .foregroundStyle(AppColor.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.Surface.background)
    }
}

#Preview {
    RootView()
}
