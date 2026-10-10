import SwiftUI

public struct DashboardView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var urlSchemeInput: String = "gameclient://"
    @State private var showSettingsSheet: Bool = false
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Lista de Interruptores Categorizados
                List {
                    // SECCIÓN 1: Tarjeta de Estado de Licencia y Heartbeat
                    Section {
                        licenseStatusHeaderCard
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    
                    // SECCIÓN 2: Interruptores Categorizados
                    ForEach($viewModel.configCategories) { $category in
                        Section {
                            ForEach($category.items) { $item in
                                Toggle(isOn: $item.isEnabled) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.title)
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        
                                        Text(item.subtitle)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .tint(.blue)
                            }
                        } header: {
                            HStack(spacing: 6) {
                                Image(systemName: category.icon)
                                    .foregroundColor(.blue)
                                Text(category.title.uppercased())
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .tracking(0.5)
                            }
                        }
                    }
                    
                    // Espacio inferior para evitar que el botón flotante tape el contenido
                    Section {
                        Spacer()
                            .frame(height: 90)
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.insetGrouped)
                
                // BARRA DE ACCIÓN INFERIOR (Flotante)
                bottomActionBar
            }
            .navigationTitle("Panel de Control")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showSettingsSheet = true }) {
                        Image(systemName: "gearshape")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { viewModel.logout() }) {
                        HStack(spacing: 4) {
                            Text("Cerrar")
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                        }
                        .font(.footnote)
                        .foregroundColor(.red)
                    }
                }
            }
            .sheet(isPresented: $showSettingsSheet) {
                settingsSheetView
            }
            .alert(viewModel.externalAppAlertTitle, isPresented: $viewModel.showExternalAppAlert) {
                Button("Aceptar", role: .cancel) {}
            } message: {
                Text(viewModel.externalAppAlertMessage)
            }
        }
    }
    
    // MARK: - Tarjeta de Estado de Licencia
    
    private var licenseStatusHeaderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .shadow(color: .green.opacity(0.8), radius: 4)
                    
                    Text("LICENCIA ACTIVA (NODE-LOCKED)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                Text(viewModel.licenseInfo?.role.uppercased() ?? "USER")
                    .font(.caption2)
                    .fontWeight(.heavy)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .clipShape(Capsule())
            }
            
            HStack(alignment: .firstTextBaseline) {
                Text(viewModel.licenseInfo?.license_key ?? viewModel.licenseKeyInput)
                    .font(.system(.title3, design: .monospaced, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let heartbeat = viewModel.heartbeatData {
                    Text("⏱ \(heartbeat.formattedRemainingTime)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Vigencia:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(viewModel.licenseInfo?.formattedExpiration ?? "Verificando...")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Text("HWID Vinculado:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(viewModel.hwid.prefix(16) + "...")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }
    
    // MARK: - Barra de Acción Inferior
    
    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            VStack(spacing: 8) {
                Button(action: {
                    viewModel.applyAndLaunchExternalApp(urlScheme: urlSchemeInput)
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.up.right.square.fill")
                            .font(.title3)
                        
                        Text("Aplicar configuración y lanzar aplicación externa")
                            .font(.headline)
                            .fontWeight(.bold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.indigo],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Color.blue.opacity(0.35), radius: 10, x: 0, y: 5)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .background(.ultraThinMaterial)
        }
    }
    
    // MARK: - Hoja de Ajustes de URL Scheme
    
    private var settingsSheetView: some View {
        NavigationStack {
            Form {
                Section(header: Text("Destino de Redirección")) {
                    TextField("URL Scheme (ej: gameclient://)", text: $urlSchemeInput)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .font(.system(.body, design: .monospaced))
                }
                
                Section(header: Text("Información del Sistema")) {
                    LabeledContent("Servidor API", value: AuthService.shared.baseURL.absoluteString)
                    LabeledContent("HWID Completo", value: viewModel.hwid)
                }
            }
            .navigationTitle("Configuración Avanzada")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") {
                        showSettingsSheet = false
                    }
                }
            }
        }
    }
}
