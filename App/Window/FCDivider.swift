import SwiftUI

/// Hairline divider used between sections. Mirrors `FCDivider` in `atoms.jsx`.
struct FCDivider: View {
    var inset: CGFloat = FCSpacing.lg

    var body: some View {
        Rectangle()
            .fill(FCTheme.divider)
            .frame(height: 0.5)
            .padding(.horizontal, inset)
    }
}
