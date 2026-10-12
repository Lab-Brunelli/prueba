import SwiftUI

struct OnboardingPage: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let detail: String
}

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("appLanguage") private var appLanguage = "es"
    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "globe",
            title: "Elegí tu idioma",
            subtitle: "Podés cambiarlo cuando quieras desde Perfil.",
            detail: "Español, English o Português. La app se adapta a vos."
        ),
        OnboardingPage(
            icon: "flame.fill",
            title: "Bienvenido al Panel",
            subtitle: "Activá tus mods de Free Fire desde un solo lugar.",
            detail: "Hologramas, aim, skins y rendimiento con un solo toque, antes de abrir el juego."
        ),
        OnboardingPage(
            icon: "iphone",
            title: "Compatibilidad",
            subtitle: "Necesitás iOS 17 o superior.",
            detail: "El panel copia los archivos al contenedor de Free Fire usando MobileHouseArrest."
        ),
        OnboardingPage(
            icon: "checkmark.seal.fill",
            title: "Certificado especial",
            subtitle: "Firmá el IPA con un certificado con HouseArrest.",
            detail: "Sin un certificado que soporte MobileHouseArrest, la copia de archivos no funciona. Ej: ArcticSign."
        )
    ]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Saltar") {
                        hasSeenOnboarding = true
                    }
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }

                Spacer()

                VStack(spacing: 20) {
                    Image(systemName: pages[page].icon)
                        .font(.system(size: 64, weight: .bold))
                        .foregroundColor(Theme.accent)
                        .frame(height: 80)

                    Text(pages[page].title)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(pages[page].subtitle)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Text(pages[page].detail)
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textSecondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 4)

                    if page == 0 {
                        Picker("Idioma", selection: $appLanguage) {
                            Text("Español").tag("es")
                            Text("English").tag("en")
                            Text("Português").tag("pt")
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 40)
                        .padding(.top, 12)
                    }
                }
                .id(page)
                .transition(.opacity)

                Spacer()

                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Circle()
                            .fill(i == page ? Theme.accent : Theme.textSecondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 24)

                Button {
                    if page < pages.count - 1 {
                        withAnimation { page += 1 }
                    } else {
                        hasSeenOnboarding = true
                    }
                } label: {
                    Text(page < pages.count - 1 ? "Siguiente" : "Empezar")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.accent)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}
