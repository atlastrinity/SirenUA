import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct MainTabBarView: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        HStack {
            tabButton(title: "Карта", icon: "map.fill", tabIndex: 0)
            Spacer()
            tabButton(title: "Історія", icon: "list.bullet", tabIndex: 1)
            Spacer()
            tabButton(title: "Сповіщення", icon: "bell.fill", tabIndex: 2)
            Spacer()
            tabButton(title: "Профіль", icon: "person.crop.circle.fill", tabIndex: 3)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 10)
        .background(
            Color(red: 0.04, green: 0.08, blue: 0.18).opacity(0.28)
        )
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.20), Color.white.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.8
            )
        )
        .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 16)
    }
    
    private func tabButton(title: String, icon: String, tabIndex: Int) -> some View {
        Button(action: {
            selectedTab = tabIndex
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: selectedTab == tabIndex ? .bold : .medium))
                Text(title)
                    .font(.system(size: 10, weight: selectedTab == tabIndex ? .bold : .regular))
            }
            .foregroundColor(selectedTab == tabIndex ? .cyan : .white.opacity(0.5))
        }
    }
}
