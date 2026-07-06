import SwiftUI
import MapKit

@available(iOS 16.0, *)
struct AlertRegionDetailView: View {
    let region: AlertRegion
    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmed = false
    
    private var isThreatActive: Bool {
        !region.isActive && region.threatLevel != nil
    }
    
    private var statusTitle: String {
        if region.isActive {
            return "АКТИВНА ТРИВОГА"
        } else if isThreatActive {
            return "Є ЗАГРОЗА (PREMIUM)"
        } else {
            return "ТРИВОГУ СКАСОВАНО"
        }
    }
    
    private var themeColor: Color {
        if region.isActive {
            return .red
        } else if isThreatActive {
            return .yellow
        } else {
            return .green
        }
    }
    
    private var themeGradient: LinearGradient {
        if region.isActive {
            return LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
        } else if isThreatActive {
            return LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [.green, .blue], startPoint: .leading, endPoint: .trailing)
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Status indicator with glassmorphism
                    HStack {
                        Circle()
                            .fill(themeColor)
                            .frame(width: 20, height: 20)
                            .animation(.easeInOut(duration: 0.3), value: region.isActive)

                        Text(statusTitle)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(themeGradient)

                        Spacer()

                        // Action buttons
                        HStack(spacing: 12) {
                            // Close button
                            Button(action: {
                                dismiss()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.gray)
                                    .frame(width: 44, height: 44)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(14)
                                    .shadow(radius: 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(radius: 20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )

                    // Region name with glassmorphism
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundStyle(themeColor)
                                .font(.system(size: 14))
                            Text("Область")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }

                        Text(region.name)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(themeGradient)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(radius: 15)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )

                    // Alert/Threat level badge
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(themeColor)
                                .font(.system(size: 14))
                            Text(isThreatActive ? "Рівень загрози" : "Рівень тривоги")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }

                        Text(isThreatActive ? "Загроза: \(region.threatLevel?.uppercased() ?? "LOW")" : "Рівень \(region.level)")
                            .font(.system(size: 16, weight: .bold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [themeColor.opacity(0.2), themeColor.opacity(0.1)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(themeColor)
                            .cornerRadius(12)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(radius: 15)

                    // Threat Detail (from Telegram bot)
                    if let detail = region.threatDetail {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "bell.badge.fill")
                                    .foregroundStyle(themeColor)
                                    .font(.system(size: 14))
                                Text("Що відомо")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }

                            Text(detail)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineSpacing(4)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .shadow(radius: 15)
                    }

                    // Warning message (if active alert or active threat)
                    if (region.isActive || isThreatActive) && !isConfirmed {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(themeColor)

                                Text(region.isActive ? "⚠️ Тривога!" : "⚠️ Попередження")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(themeColor)
                            }

                            Text(region.isActive ? 
                                 "У цій області оголошено повітряну тривогу. Негайно прямуйте в укриття!" : 
                                 "Виявлено загрозу початку повітряної тривоги (пуск ракет/рух БПЛА). Будьте готові прослідувати в безпечне місце.")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                                .lineSpacing(4)

                            // Action buttons for warning
                            HStack(spacing: 12) {
                                Button(action: {
                                    isConfirmed = true
                                }) {
                                    Text(region.isActive ? "Я в безпеці" : "Зрозуміло")
                                        .font(.system(size: 14, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(themeColor)
                                        .foregroundStyle(.black)
                                        .cornerRadius(12)
                                }
                            }
                        }
                        .padding()
                        .background(themeColor.opacity(0.1))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(themeColor.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                .padding()
            }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: Date())
    }
}

@available(iOS 16.0, *)
struct AlertRegionDetailView_Previews: PreviewProvider {
    static var previews: some View {
        AlertRegionDetailView(
            region: AlertRegion(
                id: 1,
                name: "Київська область",
                isActive: true,
                level: 4,
                description: "Test alert simulation",
                coordinate: CLLocationCoordinate2D(latitude: 50.4501, longitude: 30.5234)
            )
        )
    }
}
