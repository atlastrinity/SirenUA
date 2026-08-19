import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct MapSettingsCard: View {
    @ObservedObject var settings: NotificationSettings
    @Binding var mapType: Int
    @Binding var walkingSearchRadius: Double
    @Binding var drivingSearchRadius: Double
    let onHaptic: (UIImpactFeedbackGenerator.FeedbackStyle) -> Void

    var body: some View {
        SettingsCard(title: "Карта та Найближчі укриття", icon: "map.fill", iconColor: .siOrange) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Тип карти")
                    .font(.subheadline)
                    .foregroundColor(.white)
                Picker("Тип карти", selection: $mapType) {
                    Text("Стандартна").tag(0)
                    Text("Супутник").tag(1)
                    Text("Гібридна").tag(2)
                }
                .pickerStyle(.segmented)
            }

            StyledDivider()

            radiusRow(
                title: "Радіус пошуку (пішки)",
                icon: "figure.walk",
                iconColor: .green,
                value: $walkingSearchRadius,
                range: 0.5...5.0,
                step: 0.5,
                format: "%.1f"
            )

            StyledDivider()

            radiusRow(
                title: "Радіус пошуку (авто)",
                icon: "car.fill",
                iconColor: .siBlue,
                value: $drivingSearchRadius,
                range: 1.0...20.0,
                step: 1.0,
                format: "%.0f"
            )
        }
    }

    private func radiusRow(
        title: String,
        icon: String,
        iconColor: Color,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        format: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(value.wrappedValue, specifier: format) км")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(iconColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(iconColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            Slider(value: value, in: range, step: step)
                .tint(iconColor)
        }
    }
}
