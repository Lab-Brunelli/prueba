import SwiftUI

/// Pantalla principal con tabs. RootView la instancia como MainAppView(viewModel:).
struct MainAppView: View {

    @ObservedObject var viewModel: AppViewModel
    @State private var selectedTab: Int = 0
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $selectedTab) {

            DashboardView(viewModel: viewModel)
                .tabItem { Label("Inicio", systemImage: "house.fill") }
                .tag(0)

            ModControlView()
                .tabItem { Label("Free Fire", systemImage: "gamecontroller.fill") }
                .tag(1)

            FFExplorerView()
                .tabItem { Label("Explorer", systemImage: "folder.fill") }
                .tag(2)

            profileTab
                .tabItem { Label("Perfil", systemImage: "person.fill") }
                .tag(3)

            supportTab
                .tabItem { Label("Soporte", systemImage: "questionmark.circle.fill") }
                .tag(4)
        }
        .tint(Theme.safeGreen)
        .environmentObject(viewModel)
        .onChange(of: scenePhase) { _, phase in
            // Al volver de background re-activamos el acceso al contenedor,
            // para que DESACTIVAR siga funcionando con Free Fire abierto.
            if phase == .active { viewModel.onForeground() }
        }
        .alert("Error", isPresented: $viewModel.showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert(viewModel.externalAppAlertTitle, isPresented: $viewModel.showExternalAppAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.externalAppAlertMessage)
        }
    }

    // MARK: - Perfil

    private var profileTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("HWID").font(.caption.weight(.bold)).foregroundStyle(Theme.textSecondary)
                        Text(viewModel.hwid.isEmpty ? "—" : viewModel.hwid)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Theme.textPrimary)
                        Text("CLAVE").font(.caption.weight(.bold)).foregroundStyle(Theme.textSecondary)
                        Text(viewModel.licenseKeyInput.isEmpty ? "—" : viewModel.licenseKeyInput)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    viewModel.logout()
                } label: {
                    Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Theme.card).foregroundStyle(Theme.textPrimary)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardStroke, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(16)
        }
    }

    // MARK: - Soporte

    private var supportTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ORDEN CORRECTO").font(.caption.weight(.bold)).foregroundStyle(Theme.textSecondary)
                        Text("1. Abrí Free Fire y cargá hasta ~40%. Salí (dejalo abierto).")
                        Text("2. Abrí FX, elegí el mod y tocá ACTIVAR.")
                        Text("3. Volvé a Free Fire y esperá el lobby.")
                        Text("4. Volvé a FX y tocá DESACTIVAR.")
                        Text("5. Cerrá FX y jugá. El mod sigue en RAM.")
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Card {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("POR QUÉ NO HAY BAN").font(.caption.weight(.bold)).foregroundStyle(Theme.textSecondary)
                        Text("No se inyecta nada en el proceso de Free Fire. Solo se intercambian archivos de su contenedor. Al desactivar, el disco vuelve a estar 100% original y el mod vive en la RAM de esa sesión.")
                            .font(.caption)
                            .foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
    }
}
