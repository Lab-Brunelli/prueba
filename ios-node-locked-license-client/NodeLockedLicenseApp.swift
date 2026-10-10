import SwiftUI

@main
struct NodeLockedLicenseApp: App {
    @StateObject private var viewModel = AppViewModel()
    
    var body: some Scene {
        WindowGroup {
            RootView(viewModel: viewModel)
                .preferredColorScheme(.none) // Adaptable tanto a modo claro como oscuro
        }
    }
}
