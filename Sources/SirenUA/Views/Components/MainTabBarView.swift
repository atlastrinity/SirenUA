import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct MainTabBarView: View {
    @Binding var selectedTab: Int
    var onTabTapped: ((Int) -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 6) {
            tabButton(title: "Карта", icon: "map.fill", tabIndex: 0)
            tabButton(title: "Хронологія", icon: "clock.arrow.circlepath", tabIndex: 1)
            tabButton(title: "Укриття", icon: "shield.fill", tabIndex: 2)
            tabButton(title: "Профіль", icon: "person.crop.circle.fill", tabIndex: 3)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Color(red: 0.04, green: 0.08, blue: 0.18).opacity(0.32)
        )
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.24),
                        Color.cyan.opacity(0.18),
                        Color.white.opacity(0.06)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.9
            )
        )
        .shadow(color: Color.black.opacity(0.28), radius: 12, x: 0, y: 5)
        .padding(.horizontal, 14)
    }
    
    private func tabButton(title: String, icon: String, tabIndex: Int) -> some View {
        let isSelected = selectedTab == tabIndex
        return Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                selectedTab = tabIndex
            }
            onTabTapped?(tabIndex)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: isSelected ? Font.Weight.bold : Font.Weight.medium))
                    .foregroundColor(isSelected ? .cyan : .white.opacity(0.55))
                    .shadow(color: isSelected ? Color.cyan.opacity(0.5) : .clear, radius: 4)
                
                Text(title)
                    .font(.system(size: 10, weight: isSelected ? Font.Weight.heavy : Font.Weight.medium, design: .rounded))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                Group {
                    if isSelected {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.cyan.opacity(0.22),
                                        Color.blue.opacity(0.12)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.cyan.opacity(0.40), lineWidth: 0.8)
                            )
                            .shadow(color: Color.cyan.opacity(0.25), radius: 4, x: 0, y: 0)
                    } else {
                        Color.clear
                    }
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
