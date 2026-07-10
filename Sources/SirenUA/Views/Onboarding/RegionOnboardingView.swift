import SwiftUI
import UIKit

struct RegionOnboardingView: View {
    @AppStorage("onboardingCompleted")       private var onboardingCompleted       = false
    @AppStorage("allRegionsTracked")         private var allRegionsTracked         = false
    @AppStorage("trackedRegionsString")      private var trackedRegionsString      = ""
    
    @State private var localTrackedList: Set<String> = []
    
    private let allRegionsList = [
        "Вінницька область",    "Волинська область",       "Дніпропетровська область",
        "Донецька область",     "Житомирська область",     "Закарпатська область",
        "Запорізька область",   "Івано-Франківська область","Київська область",
        "м. Київ",              "Кіровоградська область",  "Луганська область",
        "Львівська область",    "Миколаївська область",    "Одеська область",
        "Полтавська область",   "Рівненська область",      "Сумська область",
        "Тернопільська область","Харківська область",      "Херсонська область",
        "Хмельницька область",  "Черкаська область",       "Чернівецька область",
        "Чернігівська область"
    ]
    
    private var themeColor: Color {
        Color(red: 0.20, green: 0.52, blue: 0.98) // siBlue
    }
    
    var body: some View {
        ZStack {
            // Dark premium background with glowing gradients
            Color.black.ignoresSafeArea()
            
            ZStack {
                Circle()
                    .fill(themeColor.opacity(0.15))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .offset(x: -100, y: -200)
                
                Circle()
                    .fill(Color(red: 0.98, green: 0.78, blue: 0.12).opacity(0.08)) // siGold
                    .frame(width: 250, height: 250)
                    .blur(radius: 70)
                    .offset(x: 120, y: 150)
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header section
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(themeColor.opacity(0.15))
                            .frame(width: 68, height: 68)
                        
                        Image(systemName: "map.circle.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundColor(themeColor)
                            .shadow(color: themeColor.opacity(0.4), radius: 10)
                    }
                    .padding(.top, 24)
                    
                    Text("Налаштування моніторингу")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Виберіть області, за якими ви хочете стежити.\nДодаток надсилатиме сповіщення та фокусуватиметься на обраних регіонах.")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 24)
                }
                
                // Option 1: Track all of Ukraine
                VStack(spacing: 0) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            allRegionsTracked.toggle()
                        }
                    }) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(allRegionsTracked ? themeColor.opacity(0.15) : Color.white.opacity(0.05))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "globe.europe.africa.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(allRegionsTracked ? themeColor : .white.opacity(0.6))
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Вся Україна")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Отримувати тривоги по всій країні")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.45))
                            }
                            
                            Spacer()
                            
                            Image(systemName: allRegionsTracked ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(allRegionsTracked ? themeColor : .white.opacity(0.2))
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(allRegionsTracked ? themeColor.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 12)
                    
                    // Option 2: Custom region picker list
                    if !allRegionsTracked {
                        ScrollView {
                            VStack(spacing: 10) {
                                ForEach(allRegionsList, id: \.self) { region in
                                    Button(action: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        if localTrackedList.contains(region) {
                                            localTrackedList.remove(region)
                                        } else {
                                            localTrackedList.insert(region)
                                        }
                                    }) {
                                        HStack {
                                            Text(region)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.white)
                                            Spacer()
                                            Image(systemName: localTrackedList.contains(region) ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 18))
                                                .foregroundColor(localTrackedList.contains(region) ? themeColor : .white.opacity(0.2))
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(Color.white.opacity(0.02))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(localTrackedList.contains(region) ? themeColor.opacity(0.2) : Color.white.opacity(0.05), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 4)
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        Spacer()
                    }
                }
                
                // Footer Continue button
                VStack(spacing: 0) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        
                        // Save tracked regions
                        if allRegionsTracked {
                            trackedRegionsString = allRegionsList.joined(separator: ";")
                        } else {
                            trackedRegionsString = Array(localTrackedList).joined(separator: ";")
                        }
                        
                        // Sync FCM subscriptions
                        NotificationManager.shared.syncTopicSubscriptions()
                        
                        // Complete onboarding
                        withAnimation {
                            onboardingCompleted = true
                        }
                    }) {
                        Text("Продовжити")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(
                                // Disable button if not tracking all and no regions selected
                                (allRegionsTracked || !localTrackedList.isEmpty) ? themeColor : Color.gray.opacity(0.3)
                            )
                            .cornerRadius(14)
                            .shadow(color: (allRegionsTracked || !localTrackedList.isEmpty) ? themeColor.opacity(0.3) : .clear, radius: 10, x: 0, y: 5)
                    }
                    .disabled(!allRegionsTracked && localTrackedList.isEmpty)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .padding(.top, 10)
                }
                .background(Color.black.opacity(0.85).blur(radius: 5).ignoresSafeArea())
            }
        }
        .onAppear {
            // Load current tracked regions if any, or default to some regions (like Kiev)
            if !trackedRegionsString.isEmpty {
                localTrackedList = Set(trackedRegionsString.components(separatedBy: ";").filter { !$0.isEmpty })
            } else {
                // Pre-select Kyiv region for convenience
                localTrackedList = ["Київська область", "м. Київ"]
            }
        }
    }
}
