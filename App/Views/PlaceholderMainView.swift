import SwiftUI

/// Placeholder used during Fase 0. Replaced by `MainView.swift` in Fase 1.
struct PlaceholderMainView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Header
            ZStack {
                Text("FanControl")
                    .font(FCFont.windowTitle)
                    .foregroundStyle(FCTheme.textPrimary)
            }
            .frame(height: 40)
            .frame(maxWidth: .infinity)

            FCDivider()

            FCSection(title: "CPU temperature") {
                Text("--")
                    .font(FCFont.display)
                    .foregroundStyle(FCTheme.textPrimary)
                    .fcTabularNums()
                Text("Sensor unavailable")
                    .font(FCFont.subtext)
                    .foregroundStyle(FCTheme.textMuted)
            }

            FCDivider()

            FCSection(title: "Fans") {
                Text("Left Fan  --").foregroundStyle(FCTheme.textMuted).font(FCFont.body)
                Text("Right Fan --").foregroundStyle(FCTheme.textMuted).font(FCFont.body)
            }

            FCDivider()

            FCSection(title: "Mode") {
                Text("Helper not connected")
                    .font(FCFont.body)
                    .foregroundStyle(FCTheme.textMuted)
            }

            Spacer()

            // Footer
            HStack {
                Spacer()
                Text("Edit fan curve →")
                    .font(FCFont.body)
                    .foregroundStyle(FCTheme.textGhost)
                Spacer()
            }
            .padding(.bottom, 16)
        }
    }
}
