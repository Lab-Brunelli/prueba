import SwiftUI

public struct LoginView: View {
    @ObservedObject var viewModel: AppViewModel
    @FocusState private var isFieldFocused: Bool
    @State private var copiedHwid: Bool = false
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Fondo con degradado sutil
                LinearGradient(
                    colors: [Color(.systemGroupedBackground), Color(.systemBackground)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 28) {
                        
                        // Encabezado Visual
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 88, height: 88)
                                    .shadow(color: .blue.opacity(0.3), radius: 12, x: 0, y: 6)
                                
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 42))
                                    .foregroundColor(.white)
                            }
                            .padding(.top, 24)
                            
                            Text("Activación de Licencia")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text("Introduce tu clave para autorizar y vincular este dispositivo de forma exclusiva.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        
                        // Tarjeta de Entrada de Clave
                        VStack(alignment: .leading, spacing: 16) {
                            Text("CLAVE DE PRODUCTO")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .tracking(1)
                            
                            HStack {
                                Image(systemName: "key.fill")
                                    .foregroundColor(.blue)
                                    .font(.headline)
                                
                                TextField("XXXX-XXXX-XXXX", text: $viewModel.licenseKeyInput)
                                    .font(.system(.title3, design: .monospaced, weight: .semibold))
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled(true)
                                    .focused($isFieldFocused)
                                    .onChange(of: viewModel.licenseKeyInput) { _, newValue in
                                        formatLicenseKeyInput(newValue)
                                    }
                                
                                if !viewModel.licenseKeyInput.isEmpty {
                                    Button(action: { viewModel.licenseKeyInput = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(14)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(isFieldFocused ? Color.blue : Color.clear, lineWidth: 1.5)
                            )
                            
                            // Botón de Activación
                            Button(action: {
                                isFieldFocused = false
                                viewModel.authenticate()
                            }) {
                                HStack(spacing: 8) {
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Text("Activar y Vincular Dispositivo")
                                            .fontWeight(.semibold)
                                        Image(systemName: "arrow.right.circle.fill")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                                )
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .shadow(color: .blue.opacity(0.25), radius: 8, x: 0, y: 4)
                            }
                            .disabled(viewModel.isLoading || viewModel.licenseKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                            .opacity((viewModel.isLoading || viewModel.licenseKeyInput.trimmingCharacters(in: .whitespaces).isEmpty) ? 0.6 : 1.0)
                        }
                        .padding(20)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
                        .padding(.horizontal, 20)
                        
                        // Tarjeta de Hardware ID (HWID) del Dispositivo
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "cpu")
                                    .foregroundColor(.purple)
                                Text("Identificador de Hardware (HWID)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                
                                Button(action: copyHwidToClipboard) {
                                    HStack(spacing: 4) {
                                        Image(systemName: copiedHwid ? "checkmark" : "doc.on.doc")
                                        Text(copiedHwid ? "Copiado" : "Copiar")
                                    }
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.purple)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.purple.opacity(0.12))
                                    .clipShape(Capsule())
                                }
                            }
                            
                            Text(viewModel.hwid)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "info.circle")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Este identificador se generó y guardó de forma inmutable en el Keychain local. La licencia quedará vinculada exclusivamente a esta máquina.")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(18)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .alert("Aviso de Activación", isPresented: $viewModel.showErrorAlert) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Ocurrió un error inesperado.")
            }
        }
    }
    
    // MARK: - Formateador de Clave Automático (XXXX-XXXX-XXXX)
    private func formatLicenseKeyInput(_ raw: String) {
        let cleaned = raw.uppercased().filter { $0.isLetter || $0.isNumber }
        let truncated = String(cleaned.prefix(12))
        
        var formatted = ""
        for (index, char) in truncated.enumerated() {
            if index > 0 && index % 4 == 0 {
                formatted.append("-")
            }
            formatted.append(char)
        }
        
        if formatted != viewModel.licenseKeyInput && !truncated.isEmpty {
            viewModel.licenseKeyInput = formatted
        }
    }
    
    private func copyHwidToClipboard() {
        UIPasteboard.general.string = viewModel.hwid
        withAnimation {
            copiedHwid = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copiedHwid = false
            }
        }
    }
}
