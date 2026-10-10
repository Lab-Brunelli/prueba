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
    
    // MARK: - Alertas y Errores
    @Published public var errorMessage: String? = nil
    @Published public var showErrorAlert: Bool = false
    @Published public var showExternalAppAlert: Bool = false
    @Published public var externalAppAlertTitle: String = ""
    @Published public var externalAppAlertMessage: String = ""
    
    // MARK: - Configuraciones Locales para Dashboard
    @Published public var configCategories: [ConfigCategory] = [
        ConfigCategory(
            title: "Rendimiento y Motor",
            icon: "bolt.fill",
            items: [
                ConfigItem(id: "high_performance_mode", title: "Modo Ultra Rendimiento", subtitle: "Desbloquea aceleración por GPU y máxima tasa de refresco (120 Hz).", isEnabled: true),
                ConfigItem(id: "aggressive_caching", title: "Caché en Memoria Acelerada", subtitle: "Reduce latencia manteniendo recursos precargados.", isEnabled: false),
                ConfigItem(id: "low_latency_audio", title: "Audio de Baja Latencia", subtitle: "Prioriza buffers reducidos para procesamiento en tiempo real.", isEnabled: true)
            ]
        ),
        ConfigCategory(
            title: "Red y Seguridad",
            icon: "shield.checkerboard",
            items: [
                ConfigItem(id: "strict_ssl_pinning", title: "Validación SSL Estricta", subtitle: "Rechaza conexiones intermedias o certificados autofirmados.", isEnabled: true),
                ConfigItem(id: "local_proxy_tunnel", title: "Túnel Proxy Local", subtitle: "Enruta el tráfico a través de socket seguro 127.0.0.1:9050.", isEnabled: false),
                ConfigItem(id: "telemetry_reporting", title: "Telemetría de Diagnóstico", subtitle: "Envía logs de excepciones anónimos para telemetría.", isEnabled: false)
            ]
        ),
        ConfigCategory(
            title: "Módulos Avanzados",
            icon: "slider.horizontal.3",
            items: [
                ConfigItem(id: "developer_hud", title: "HUD de Depuración en Pantalla", subtitle: "Superpone métricas de FPS, memoria y tiempo de cuadro.", isEnabled: false),
                ConfigItem(id: "auto_sync_cloud", title: "Sincronización Automática", subtitle: "Guarda perfiles de configuración tras cada modificación.", isEnabled: true)
            ]
        )
    ]
    
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
    
    /// Intenta validar el token guardado en Keychain mediante un heartbeat inicial.
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
                // Si el token expiró o fue revocado, limpiamos sesión sin alertar de forma intrusiva
                self.keychain.deleteSessionToken()
                self.isAuthenticated = false
            }
            self.isLoading = false
        }
    }
    
    /// Ejecuta la activación manual con la clave introducida por el usuario.
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
                
                // Guardar en Keychain
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
    
    /// Cierra la sesión activa y detiene la supervisión en segundo plano.
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
                    // Error transitorio de red: loguear sin expulsar al usuario de inmediato
                    NSLog("⚠️ Heartbeat transitorio fallido: \(error.localizedDescription)")
                }
            }
        )
    }
    
    // MARK: - Lanzamiento de Aplicación Externa vía URL Scheme
    
    /// Empaqueta la configuración activa, accede al contenedor del juego y lanza la app externa.
    public func applyAndLaunchExternalApp(urlScheme: String = "gameclient://") {
        // 1. Recopilar valores de configuración activados
        var activeFlags: [String: Bool] = [:]
        for category in configCategories {
            for item in category.items {
                activeFlags[item.id] = item.isEnabled
            }
        }
        
        // 2. Intentar acceder al contenedor de Free Fire (MobileHouseArrest)
        if let ffContainer = HouseArrestManager.shared.containerURL(forBundleID: HouseArrestManager.freeFireBundleID) {
            NSLog("✅ Contenedor de Free Fire accesible: \(ffContainer.path)")
            // Acá más adelante se copian los archivos del holograma con AssetSyncEngine
        } else {
            NSLog("❌ No se pudo acceder al contenedor de Free Fire (revisá Bundle ID y certificado)")
        }
        
        // 3. Serializar a JSON
        guard let jsonData = try? JSONSerialization.data(withJSONObject: activeFlags, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            presentError("Error al codificar las opciones de configuración.")
            return
        }
        
        // 4. Construir URL con parámetros
        guard var components = URLComponents(string: urlScheme) else {
            presentError("El formato de URL Scheme es inválido.")
            return
        }
        
        components.queryItems = [
            URLQueryItem(name: "config", value: jsonString),
            URLQueryItem(name: "hwid", value: hwid),
            URLQueryItem(name: "license", value: licenseInfo?.license_key ?? licenseKeyInput)
        ]
        
        guard let finalURL = components.url else {
            presentError("No se pudo construir la URL de redirección.")
            return
        }
        
        // 5. Intentar abrir en el sistema iOS
        if UIApplication.shared.canOpenURL(finalURL) {
            UIApplication.shared.open(finalURL, options: [:]) { success in
                if !success {
                    self.presentExternalAppInfo(
                        title: "Error al Lanzar",
                        message: "El sistema no pudo iniciar la aplicación externa asociada a '\(urlScheme)'."
                    )
                }
            }
        } else {
            // Si la app externa no está instalada o el URL Scheme no está en Info.plist (LSApplicationQueriesSchemes)
            self.presentExternalAppInfo(
                title: "Configuración Aplicada Localmente",
                message: "Los interruptores se han guardado con éxito.\n\nLa aplicación externa con esquema '\(urlScheme)' no se encuentra instalada en este dispositivo.\n\nPayload generado:\n\(finalURL.absoluteString)"
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
