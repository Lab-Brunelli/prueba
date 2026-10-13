import SwiftUI

@main
struct NodeLockedLicenseApp: App {

    @StateObject private var viewModel = AppViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(viewModel)
                .onChange(of: scenePhase) { _, phase in
                    // Al volver de background re-activamos el acceso al contenedor
                    // para que DESACTIVAR siga funcionando con el juego abierto.
                    if phase == .active { viewModel.onForeground() }
                }
        }
    }
}
