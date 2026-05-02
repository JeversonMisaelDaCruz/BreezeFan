import SwiftUI

/// Vertical section with optional title and trailing action. Mirrors `FCSection` in `atoms.jsx`.
struct FCSection<Content: View, Action: View>: View {
    let title: String?
    let action: Action?
    let content: Content
    var horizontalPadding: CGFloat = FCSpacing.lg
    var topPadding: CGFloat = FCSpacing.md
    var bottomPadding: CGFloat = FCSpacing.sm

    init(
        title: String? = nil,
        horizontalPadding: CGFloat = FCSpacing.lg,
        topPadding: CGFloat = FCSpacing.md,
        bottomPadding: CGFloat = FCSpacing.sm,
        @ViewBuilder content: () -> Content,
        @ViewBuilder action: () -> Action
    ) {
        self.title = title
        self.horizontalPadding = horizontalPadding
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
        self.content = content()
        self.action = action()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FCSpacing.sm) {
            if title != nil || !(action is EmptyView) {
                HStack {
                    if let title {
                        Text(title.uppercased())
                            .font(FCFont.sectionTitle)
                            .tracking(1.4)
                            .foregroundStyle(FCTheme.textGhost)
                    }
                    Spacer()
                    action
                }
            }
            content
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
    }
}

extension FCSection where Action == EmptyView {
    init(
        title: String? = nil,
        horizontalPadding: CGFloat = FCSpacing.lg,
        topPadding: CGFloat = FCSpacing.md,
        bottomPadding: CGFloat = FCSpacing.sm,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            horizontalPadding: horizontalPadding,
            topPadding: topPadding,
            bottomPadding: bottomPadding,
            content: content,
            action: { EmptyView() }
        )
    }
}
