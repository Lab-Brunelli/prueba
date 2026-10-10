import SwiftUI

public struct RootView: View {
    @ObservedObject var viewModel: AppViewModel
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ZStack {
            if viewModel.isAuthenticated {
                DashboardView(viewModel: viewModel)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity
                    ))
            } else {
                LoginView(viewModel: viewModel)
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .opacity.combined(with: .scale(scale: 1.02))
                    ))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: viewModel.isAuthenticated)
    }
}
