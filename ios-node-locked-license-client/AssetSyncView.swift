import SwiftUI

/// Vista de ejemplo en SwiftUI que demuestra la integración con `AssetSyncEngine`.
public struct AssetSyncView: View {
    @State private var isProcessing: Bool = false
    @State private var progressFraction: Double = 0.0
    @State private var currentFileName: String = ""
    @State private var statusLogs: [String] = []
    
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false
    
    // Esquema de URL de la app externa
    @State private var targetURLScheme: String = "gameclient://reload-assets"
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Tarjeta Informativa de Sandboxing
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "internaldrive.fill")
                                .foregroundColor(.blue)
                            Text("Sincronización de Recursos en Sandbox")
                                .font(.headline)
                        }
                        
                        Text("Gestiona la copia segura de paquetes de configuración y texturas hacia la carpeta designada, garantizando respaldos automáticos (.bak) y validación de hash SHA256.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    
                    // Barra de Progreso Activa
                    if isProcessing {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Procesando:")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                Text(currentFileName)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(Int(progressFraction * 100))%")
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                            
                            ProgressView(value: progressFraction)
                                .tint(.blue)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
                    }
                    
                    // Botones de Operación
                    VStack(spacing: 12) {
                        // 1. Sincronizar y Respaldar
                        Button(action: executeSync) {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                    .font(.title3)
                                Text("Sincronizar y Crear Respaldo (.bak)")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isProcessing)
                        
                        // 2. Restaurar a Original (Rollback)
                        Button(action: executeRestore) {
                            HStack {
                                Image(systemName: "arrow.uturn.backward.circle.fill")
                                    .font(.title3)
                                Text("Revertir / Restaurar desde .bak")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isProcessing)
                        
                        // 3. Abrir App Externa
                        Button(action: executeOpenExternalApp) {
                            HStack {
                                Image(systemName: "arrow.up.right.square.fill")
                                    .font(.title3)
                                Text("Lanzar App Externa vía URL Scheme")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.purple.opacity(0.15))
                            .foregroundColor(.purple)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isProcessing)
                    }
                    
                    // Consola de Registro de Eventos (Audit Trail)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("REGISTRO DE OPERACIONES")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                if statusLogs.isEmpty {
                                    Text("Listo para iniciar operaciones.")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.secondary)
                                } else {
                                    ForEach(statusLogs, id: \.self) { log in
                                        Text(log)
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundColor(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                            .padding(10)
                        }
                        .frame(height: 180)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding()
            }
            .navigationTitle("Motor de Sincronización")
            .navigationBarTitleDisplayMode(.inline)
            .alert(alertTitle, isPresented: $showAlert) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - Lógica de Ejecución
    
    /// Prepara carpetas de prueba en el Sandbox local y ejecuta la sincronización
    private func executeSync() {
        isProcessing = true
        progressFraction = 0.0
        statusLogs.append("[\(timestamp())] 🚀 Iniciando preparación de origen y destino...")
        
        Task {
            do {
                let fileManager = FileManager.default
                let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                
                let sourceDir = docs.appendingPathComponent("StagingAssets")
                let destinationDir = docs.appendingPathComponent("GameLiveAssets")
                
                // Preparar datos de prueba en la carpeta de origen si no existen
                try setupMockSourceFiles(at: sourceDir)
                
                statusLogs.append("[\(timestamp())] 🔍 Verificando integridad y espacio en disco...")
                
                let result = try await AssetSyncEngine.shared.synchronize(
                    from: sourceDir,
                    to: destinationDir,
                    algorithm: .sha256
                ) { progress in
                    DispatchQueue.main.async {
                        self.currentFileName = progress.currentFile
                        self.progressFraction = progress.fractionCompleted
                        self.statusLogs.append("[\(self.timestamp())] 📄 Copiado: \(progress.currentFile) (\(progress.filesProcessed)/\(progress.totalFiles))")
                    }
                }
                
                await MainActor.run {
                    self.statusLogs.append("[\(self.timestamp())]  Sincronización completada: \(result.copiedFilesCount) copiados, \(result.backedUpFilesCount) respaldados (.bak).")
                    self.presentAlert(
                        title: "Sincronización Exitosa",
                        message: "Se copiaron \(result.copiedFilesCount) archivos y se crearon \(result.backedUpFilesCount) copias .bak de respaldo."
                    )
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.statusLogs.append("[\(self.timestamp())] ❌ Error: \(error.localizedDescription)")
                    self.presentAlert(title: "Error de Sincronización", message: error.localizedDescription)
                    self.isProcessing = false
                }
            }
        }
    }
    
    /// Ejecuta la reversión a partir de los archivos `.bak`
    private func executeRestore() {
        isProcessing = true
        statusLogs.append("[\(timestamp())] 🔄 Buscando respaldos .bak para revertir...")
        
        Task {
            do {
                let fileManager = FileManager.default
                let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let destinationDir = docs.appendingPathComponent("GameLiveAssets")
                
                let result = try await AssetSyncEngine.shared.restoreFromBackup(in: destinationDir)
                
                await MainActor.run {
                    self.statusLogs.append("[\(self.timestamp())]  Restauración completada: \(result.restoredFilesCount) archivos devueltos a su versión original.")
                    self.presentAlert(
                        title: "Reversión Completada",
                        message: "Se han restaurado \(result.restoredFilesCount) archivos originales a partir de sus respaldos .bak."
                    )
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.statusLogs.append("[\(self.timestamp())] ❌ Fallo en reversión: \(error.localizedDescription)")
                    self.presentAlert(title: "Fallo al Revertir", message: error.localizedDescription)
                    self.isProcessing = false
                }
            }
        }
    }
    
    /// Lanza la aplicación externa vía URL Scheme
    private func executeOpenExternalApp() {
        Task { @MainActor in
            do {
                statusLogs.append("[\(timestamp())] 📲 Invocando app externa vía '\(targetURLScheme)'...")
                
                try await AssetSyncEngine.shared.openExternalApp(
                    urlScheme: targetURLScheme,
                    parameters: ["reload": "true", "timestamp": "\(Int(Date().timeIntervalSince1970))"]
                )
                
                statusLogs.append("[\(timestamp())]  Aplicación externa lanzada con éxito.")
            } catch {
                statusLogs.append("[\(timestamp())] ⚠️ No se pudo abrir la app: \(error.localizedDescription)")
                presentAlert(
                    title: "Apertura de App Externa",
                    message: "Aviso: \(error.localizedDescription)\n\nAsegúrate de registrar '\(targetURLScheme.components(separatedBy: ":")[0])' en LSApplicationQueriesSchemes dentro de Info.plist."
                )
            }
        }
    }
    
    // MARK: - Helpers de Mock y Diagnóstico
    
    private func setupMockSourceFiles(at url: URL) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
        
        // Crear archivos de configuración de ejemplo
        let config1 = url.appendingPathComponent("engine_config.json")
        let config2 = url.appendingPathComponent("shaders/render_profile.bin")
        
        try fm.createDirectory(at: config2.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        if !fm.fileExists(atPath: config1.path) {
            let json = "{\"rendering\": \"metal\", \"target_fps\": 120, \"vSync\": true}"
            try json.write(to: config1, atomically: true, encoding: .utf8)
        }
        if !fm.fileExists(atPath: config2.path) {
            let dummyBinary = Data(repeating: 0xFA, count: 1024 * 128) // 128 KB
            try dummyBinary.write(to: config2)
        }
    }
    
    private func presentAlert(title: String, message: String) {
        self.alertTitle = title
        self.alertMessage = message
        self.showAlert = true
    }
    
    private func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: Date())
    }
}
