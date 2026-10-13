import Foundation
import SwiftUI
import Combine

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
    @Published public var isRestoring: Bool = false
    @Published public var lastSyncSummary: String? = nil
    @Published public var lastRestoreSummary: String? = nil

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
                ConfigItem(id: "fps_144", title: "144 FPS", subtitle: "Desbloquea tasa de refresco alta.", isEnabled: false),
                ConfigItem(id: "ultra_rendimiento", title: "Modo Ultra Rendimiento", subtitle: "Máxima aceleración por GPU.", isEnabled: true)
            ]
        ),
        ConfigCategory(
            title: "Sistema",
            icon: "wrench.and.screwdriver",
            items: [
                ConfigItem(id: "_selftest", title: "Self-Test (archivo real)", subtitle: "Valida el pipeline completo sin assets del juego.", isEnabled: false)
            ]
        )
    ]

    private let freeFireAssetsSubpath = "Documents"

    private let keychain: KeychainManager
    private let authService: AuthService

    public init(keychain: KeychainManager = .shared, authService: AuthService = .shared) {
        self.keychain = keychain
        self.authService = authService
        self.hwid = keychain.getOrCreateHardwareIdentifier()
        if let lastKey = keychain.getLastLicenseKey() {
            self.licenseKeyInput = lastKey
        }
        attemptAutoLogin()
    }

    // MARK: - Autenticación

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
                _ = self.keychain.deleteSessionToken()
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

    private func startHeartbeatMonitor() {
        authService.startPeriodicHeartbeat(
            intervalSeconds: 60,
            tokenProvider: { [weak self] in self?.keychain.getSessionToken() },
            onUpdate: { [weak self] heartbeat in self?.heartbeatData = heartbeat },
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

    // MARK: - Aplicar mods (seguro) y lanzar

    public func applyAndLaunchExternalApp(urlScheme: String = "gameclient://") {
        guard !isSyncing, !isRestoring else { return }
        Task { await applyAndSync(urlScheme: urlScheme) }
    }

    private func applyAndSync(urlScheme: String) async {
        isSyncing = true
        defer { isSyncing = false }

        var activeFlags: [String: Bool] = [:]
        for category in configCategories {
            for item in category.items { activeFlags[item.id] = item.isEnabled }
        }

        guard let ffContainer = HouseArrestManager.shared.containerURL(forBundleID: HouseArrestManager.freeFireBundleID) else {
            presentError("No se pudo acceder al contenedor de Free Fire.\n\nVerificá:\n• Que Free Fire esté instalado.\n• Que el certificado soporte MobileHouseArrest.")
            return
        }
        NSLog("✅ Contenedor de Free Fire accesible: \(ffContainer.path)")

        let destination = ffContainer.appendingPathComponent(freeFireAssetsSubpath)
        try? FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        let installer = ModInstaller.shared
        var done: [String] = []
        var missing: [String] = []

        for category in configCategories {
            for item in category.items where item.isEnabled {
                guard let source = ModsLibrary.shared.sourceURL(for: item.id) else {
                    missing.append("\(item.title) (sin carpeta en Documents/Mods/\(item.id))")
                    continue
                }
                do {
                    let rep = try installer.install(modID: item.id, from: source, into: destination)
                    done.append("\(item.title) (+\(rep.installedFiles) nuevos, \(rep.skipped) ya ok)")
                    NSLog("✅ Instalado \(item.id) -> \(destination.path)")
                } catch {
                    NSLog("⚠️ Error instalando \(item.id): \(error.localizedDescription)")
                    missing.append("\(item.title) (\(error.localizedDescription))")
                }
            }
        }

        var summary = "Mods aplicados (seguro, con backup):\n"
        summary += done.isEmpty ? "• (ninguno tenía archivos aún)\n" : done.map { "• \($0)" }.joined(separator: "\n") + "\n"
        if !missing.isEmpty {
            summary += "\nNo aplicados:\n" + missing.map { "• \($0)" }.joined(separator: "\n")
        }
        summary += "\n\n💡 Tip: aplicá con Free Fire CERRADO."
        self.lastSyncSummary = summary

        launchExternal(urlScheme: urlScheme, activeFlags: activeFlags)
    }

    // MARK: - Restaurar original (quitar mods)

    public func restoreOriginalMods() {
        guard !isSyncing, !isRestoring else { return }
        Task { await restore() }
    }

    private func restore() async {
        isRestoring = true
        defer { isRestoring = false }

        guard let ffContainer = HouseArrestManager.shared.containerURL(forBundleID: HouseArrestManager.freeFireBundleID) else {
            presentError("No se pudo acceder al contenedor de Free Fire para restaurar.")
            return
        }
        let destination = ffContainer.appendingPathComponent(freeFireAssetsSubpath)
        do {
            let rep = try ModInstaller.shared.restoreAll(in: destination)
            let msg = "Restaurado a como estaba:\n• \(rep.restoredOriginals) archivos originales devueltos\n• \(rep.removedAddedFiles) archivos añadidos eliminados"
            self.lastRestoreSummary = msg
            presentExternalAppInfo(title: "Restaurado", message: msg)
        } catch {
            presentError("Error al restaurar: \(error.localizedDescription)")
        }
    }

    private func launchExternal(urlScheme: String, activeFlags: [String: Bool]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: activeFlags, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            presentExternalAppInfo(title: "Configuración Aplicada", message: lastSyncSummary ?? "Listo.")
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
                if !success { self.presentExternalAppInfo(title: "Assets Copiados", message: self.lastSyncSummary ?? "Listo.") }
            }
        } else {
            presentExternalAppInfo(
                title: "Assets Copiados",
                message: (lastSyncSummary ?? "Listo.") + "\n\n(No se pudo abrir '\(urlScheme)' — abrí Free Fire manualmente.)"
            )
        }
    }

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
