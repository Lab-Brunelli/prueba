import Foundation
import SwiftUI
import Combine

/// ViewModel principal para orquestar el ciclo de vida de la licencia,
/// la persistencia en Keychain, el servicio de red y el estado de la UI.
@MainActor
public final class AppViewModel: ObservableObject {

    // MARK: - Estado de Autenticación
    @Published public var isAuthenticated: Bool = false
    @Published public var isLoading: Bool = false
    @Published public var licenseKeyInput: String = ""
    @Published public var hwid: String = ""
    @Published public var licenseInfo: LicenseInfo? = nil
    @Published public var heartbeatData: HeartbeatPayload? = nil

    // MARK: - Estado de Sincronización de Assets
    @Published public var isSyncing: Bool = false
    @Published public var lastSyncSummary: String? = nil

    // MARK: - Alertas y Errores
    @Published public var errorMessage: String? = nil
    @Published public var showErrorAlert: Bool = false
    @Published public var showExternalAppAlert: Bool = false
    @Published public var externalAppAlertTitle: String = ""
    @Published public var externalAppAlertMessage: String = ""

    // MARK: - Configuraciones Locales para Dashboard
    @Published public var configCategories: [ConfigCategory] = [
        ConfigCategory(
            title: "Aimbot",
            icon: "scope",
            items: [
                ConfigItem(id: "aim_cuello_70", title: "Aim Cuello 70 (Disimulado)", subtitle: "Mira fijada al cuello, poco detectable.", isEnabled: false),
                ConfigItem(id: "aim_rapido_rojo", title: "Aim Rápido (Rojo)", subtitle: "Bloqueo rápido con marcador rojo.", isEnabled: false)
            ]
        ),
        ConfigCategory(
            title: "Holograma",
            icon: "cube.transparent",
            items: [
                ConfigItem(id: "holo_negro_morado", title: "Holograma Arma Negro Morado", subtitle: "Reemplaza shaders del arma.", isEnabled: false),
                ConfigItem(id: "holo_rojo_negro", title: "Holograma Rojo Negro", subtitle: "Reemplaza shaders del arma.", isEnabled: false)
            ]
        ),
        ConfigCategory(
            title: "Skin",
            icon: "wand.and.stars",
            items: [
                ConfigItem(id: "skin_arma", title: "Skin de Arma", subtitle: "Aplica skins al arma equipada.", isEnabled: false),
                ConfigItem(id: "skin_personaje", title: "Skin de Personaje", subtitle: "Aplica skins al personaje.", isEnabled: false)
            ]
        ),
        ConfigCategory(
            title: "Config",
            icon: "slider.horizontal.3",
            items: [
                ConfigItem(id: "fps_120", title: "120 FPS", subtitle: "Desbloquea tasa de refresco alta.", isEnabled: false),
                ConfigItem(id: "ultra_rendimiento", title: "Modo Ultra Rendimiento", subtitle: "Máxima aceleración por GPU.", isEnabled: true)
            ]
        )
    ]

    /// Subcarpeta dentro del contenedor de Free Fire donde se copian los assets.
    /// Si tu mod necesita otra ruta, cambiala acá.
    private let freeFireAssetsSubpath = "Documents"

    private let keychain: KeychainManager
    private let authService: AuthService

    // MARK: - Inicialización

    public init(keychain: KeychainManager = .shared, authService: AuthService = .shared) {
        self.keychain = keychain
        self.authService = authService

        // 1. Obtener o generar HWID seguro desde Keychain
        self.hwid = keychain.getOrCreateHardwareIdentifier()

        // 2. Recuperar última clave utilizada para conveniencia del usuario
        if let lastKey = keychain.getLastLicenseKey() {
            self.licenseKeyInput = lastKey
        }

        // 3. Intento de inicio automático con sesión previa
        attemptAutoLogin()
    }

    // MARK: - Flujo de Autenticación

    private func attemptAutoLogin() {
        guard let savedToken = keychain.getSessionToken() else { return }

        isLoading = true
        Task {
            do {
                let heartbeat = try await authService.sendHeartbeat(token: savedToken)
                self.heartbeatData = heartbeat
                self.isAuthenticated = true
                self.startHeartbeatMonitor()
            } catch {
                self.keychain.deleteSessionToken()
                self.isAuthenticated = false
            }
            self.isLoading = false
        }
    }

    public func authenticate() {
        let formattedKey = licenseKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        guard !formattedKey.isEmpty else {
            presentError("Por favor, introduce una clave de licencia válida.")
            return
        }

        isLoading = true

        Task {
            do {
                let result = try await authService.authenticate(licenseKey: formattedKey, hwid: hwid)

                _ = keychain.saveSessionToken(result.token)
                _ = keychain.saveLastLicenseKey(formattedKey)

                self.licenseInfo = result.license
                self.isAuthenticated = true
                self.startHeartbeatMonitor()
            } catch let error as AuthError {
                presentError(error.localizedDescription)
            } catch {
                presentError("Ocurrió un error inesperado: \(error.localizedDescription)")
            }

            self.isLoading = false
        }
    }

    public func logout() {
        authService.stopHeartbeat()
        _ = keychain.deleteSessionToken()
        self.licenseInfo = nil
        self.heartbeatData = nil
        self.isAuthenticated = false
    }

    // MARK: - Supervisión Continua (Heartbeat)

    private func startHeartbeatMonitor() {
        authService.startPeriodicHeartbeat(
            intervalSeconds: 60,
            tokenProvider: { [weak self] in
                return self?.keychain.getSessionToken()
            },
            onUpdate: { [weak self] heartbeat in
                self?.heartbeatData = heartbeat
            },
            onFailure: { [weak self] error in
                guard let self = self else { return }
                switch error {
                case .licenseExpired, .licenseBanned, .hwidMismatch, .unauthorized:
                    self.logout()
                    self.presentError(error.localizedDescription)
                default:
                    NSLog("⚠️ Heartbeat transitorio fallido: \(error.localizedDescription)")
                }
            }
        )
    }

    // MARK: - Aplicar configuración, copiar assets y lanzar

    /// Punto de entrada desde la UI. Copia los assets de los mods activados al
    /// contenedor de Free Fire y luego intenta lanzar la app externa.
    public func applyAndLaunchExternalApp(urlScheme: String = "gameclient://") {
        guard !isSyncing else { return }
        Task { await applyAndSync(urlScheme: urlScheme) }
    }

    private func applyAndSync(urlScheme: String) async {
        isSyncing = true
        defer { isSyncing = false }

        // 1. Recopilar flags activos
        var activeFlags: [String: Bool] = [:]
        for category in configCategories {
            for item in category.items { activeFlags[item.id] = item.isEnabled }
        }

        // 2. Acceder al contenedor de Free Fire (MobileHouseArrest)
        guard let ffContainer = HouseArrestManager.shared.containerURL(forBundleID: HouseArrestManager.freeFireBundleID) else {
            presentError("No se pudo acceder al contenedor de Free Fire.\n\nVerificá:\n• Que Free Fire esté instalado.\n• Que el certificado soporte MobileHouseArrest (Bundle ID com.apple.mobile.MobileHouseArrest).")
            return
        }
        NSLog("✅ Contenedor de Free Fire accesible: \(ffContainer.path)")

        // 3. Copiar assets de cada mod activado que exista en el bundle
        let destination = ffContainer.appendingPathComponent(freeFireAssetsSubpath)
        let engine = AssetSyncEngine.shared
        var copiedMods: [String] = []
        var missingMods: [String] = []

        for category in configCategories {
            for item in category.items where item.isEnabled {
                guard let source = Bundle.main.url(forResource: "FFAssets/\(item.id)", withExtension: nil) else {
                    missingMods.append(item.title)
                    continue
                }
                do {
                    let result = try await engine.synchronize(from: source, to: destination)
                    copiedMods.append("\(item.title) (\(result.copiedFilesCount) archivos)")
                    NSLog("✅ Sincronizado \(item.id) -> \(destination.path)")
                } catch {
                    NSLog("⚠️ Error sincronizando \(item.id): \(error.localizedDescription)")
                    missingMods.append(item.title)
                }
            }
        }

        // 4. Resumen
        var summary = "Mods aplicados:\n"
        summary += copiedMods.isEmpty ? "• (ninguno con archivos)\n" : copiedMods.map { "• \($0)" }.joined(separator: "\n") + "\n"
        if !missingMods.isEmpty {
            summary += "\nSin archivos aún (pendiente de assets):\n"
            summary += missingMods.map { "• \($0)" }.joined(separator: "\n")
        }
        self.lastSyncSummary = summary
        NSLog("📦 \(summary)")

        // 5. Lanzar app externa vía URL scheme
        launchExternal(urlScheme: urlScheme, activeFlags: activeFlags)
    }

    private func launchExternal(urlScheme: String, activeFlags: [String: Bool]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: activeFlags, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            presentError("Error al codificar las opciones de configuración.")
            return
        }

        guard var components = URLComponents(string: urlScheme) else {
            presentExternalAppInfo(title: "Configuración Aplicada", message: lastSyncSummary ?? "Listo.")
            return
        }

        components.queryItems = [
            URLQueryItem(name: "config", value: jsonString),
            URLQueryItem(name: "hwid", value: hwid),
            URLQueryItem(name: "license", value: licenseInfo?.license_key ?? licenseKeyInput)
        ]

        guard let finalURL = components.url else {
            presentExternalAppInfo(title: "Configuración Aplicada", message: lastSyncSummary ?? "Listo.")
            return
        }

        if UIApplication.shared.canOpenURL(finalURL) {
            UIApplication.shared.open(finalURL, options: [:]) { success in
                if !success {
                    self.presentExternalAppInfo(title: "Assets Copiados", message: self.lastSyncSummary ?? "Listo.")
                }
            }
        } else {
            presentExternalAppInfo(
                title: "Assets Copiados",
                message: (lastSyncSummary ?? "Listo.") + "\n\n(No se pudo abrir '\(urlScheme)' — abrí Free Fire manualmente.)"
            )
        }
    }

    // MARK: - Helpers de Alerta

    private func presentError(_ message: String) {
        self.errorMessage = message
        self.showErrorAlert = true
    }

    private func presentExternalAppInfo(title: String, message: String) {
        self.externalAppAlertTitle = title
        self.externalAppAlertMessage = message
        self.showExternalAppAlert = true
    }
}
