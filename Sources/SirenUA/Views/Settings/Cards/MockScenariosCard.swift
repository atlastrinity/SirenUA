import SwiftUI

struct MockScenariosCard: View {
    let onTriggerScenario: (String) -> Void

    var body: some View {
        SettingsCard(title: "Симуляція загроз (Розробка)", icon: "flask.fill", iconColor: .orange) {
            Text("Запустіть один із тестових сценаріїв для перевірки жовтих областей, телеметрії, відстані та кругових діаграм ймовірностей.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))
                .lineSpacing(4)

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Button(action: { onTriggerScenario("shaheds_south") }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Шахеди з півдня")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(ChartColorTheme.active.opacity(0.2))
                        .cornerRadius(8)
                    }

                    Button(action: { onTriggerScenario("mig_takeoff") }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Зліт МіГ-31К")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(ChartColorTheme.orange.opacity(0.2))
                        .cornerRadius(8)
                    }
                }

                HStack(spacing: 8) {
                    Button(action: { onTriggerScenario("cruise_missiles_west") }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Ракети (Захід)")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(ChartColorTheme.accent.opacity(0.2))
                        .cornerRadius(8)
                    }

                    Button(action: { onTriggerScenario("clear") }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("Очистити все")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(ChartColorTheme.overestimated.opacity(0.15))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
}
