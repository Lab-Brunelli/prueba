import Foundation

/// Servicio de red para la validación y supervisión de licencias Node-Locked.
public final class AuthService {
    
    public static let shared = AuthService()
    
    /// URL base del servidor de licencias (ajustar según entorno local o producción)
    public var baseURL: URL = URL(string: "http://localhost:3000")!
    
    private let session: URLSession
    private var heartbeatTask: Task<Void, Never>?
    
    public init(session: URLSession = .shared) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15.0
        configuration.timeoutIntervalForResource = 30.0
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - Autenticación y Activación
    
    /// Realiza la autenticación vinculando el HWID de este dispositivo con la clave proporcionada.
    /// - Parameters:
    ///   - licenseKey: Clave con formato XXXX-XXXX-XXXX
    ///   - hwid: Identificador persistente obtenido de `KeychainManager`
    /// - Returns: `AuthPayload` con el token de sesión JWT y metadatos de la licencia
    public func authenticate(licenseKey: String, hwid: String) async throws -> AuthPayload {
        let endpoint = baseURL.appendingPathComponent("/api/v1/auth")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let payload = AuthRequest(licenseKey: licenseKey, hwid: hwid)
        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            throw AuthError.networkError("Error al serializar la petición: \(error.localizedDescription)")
        }
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AuthError.networkError("No se pudo conectar con el servidor: \(error.localizedDescription)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.serverError("Respuesta HTTP inválida")
        }
        
        // Decodificación de la respuesta base
        let decoder = JSONDecoder()
        
        if httpResponse.statusCode == 200 {
            do {
                let parsed = try decoder.decode(BaseResponse<AuthPayload>.self, from: data)
                if let payloadData = parsed.data {
                    return payloadData
                } else {
                    throw AuthError.decodingError
                }
            } catch {
                throw AuthError.decodingError
            }
        } else {
            // Manejo de errores específicos del backend
            let errorMessage: String
            if let errorObj = try? decoder.decode(BaseResponse<AuthPayload>.self, from: data),
               let serverMsg = errorObj.error?.message {
                errorMessage = serverMsg
            } else {
                errorMessage = "Código de estado HTTP: \(httpResponse.statusCode)"
            }
            
            switch httpResponse.statusCode {
            case 401:
                throw AuthError.invalidCredentials(errorMessage)
            case 403:
                if errorMessage.lowercased().contains("mismatch") || errorMessage.lowercased().contains("locked") {
                    throw AuthError.hwidMismatch(errorMessage)
                } else if errorMessage.lowercased().contains("expired") {
                    throw AuthError.licenseExpired(errorMessage)
                } else if errorMessage.lowercased().contains("banned") {
                    throw AuthError.licenseBanned(errorMessage)
                } else {
                    throw AuthError.unauthorized
                }
            default:
                throw AuthError.serverError(errorMessage)
            }
        }
    }
    
    // MARK: - Heartbeat
    
    /// Ejecuta una comprobación puntual de estado de sesión ante el servidor.
    public func sendHeartbeat(token: String) async throws -> HeartbeatPayload {
        let endpoint = baseURL.appendingPathComponent("/api/v1/heartbeat")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AuthError.networkError("Fallo de conexión en heartbeat: \(error.localizedDescription)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.serverError("Respuesta de heartbeat inválida")
        }
        
        let decoder = JSONDecoder()
        
        if httpResponse.statusCode == 200 {
            let parsed = try decoder.decode(BaseResponse<HeartbeatPayload>.self, from: data)
            if let heartbeat = parsed.data {
                return heartbeat
            }
            throw AuthError.decodingError
        } else {
            let errorMsg = (try? decoder.decode(BaseResponse<HeartbeatPayload>.self, from: data))?.error?.message 
                ?? "Sesión invalidada"
            
            switch httpResponse.statusCode {
            case 401:
                throw AuthError.unauthorized
            case 403:
                if errorMsg.lowercased().contains("banned") {
                    throw AuthError.licenseBanned(errorMsg)
                } else if errorMsg.lowercased().contains("expired") {
                    throw AuthError.licenseExpired(errorMsg)
                } else {
                    throw AuthError.hwidMismatch(errorMsg)
                }
            default:
                throw AuthError.serverError(errorMsg)
            }
        }
    }
    
    // MARK: - Tarea Periódica de Heartbeat
    
    /// Inicia un loop en segundo plano que supervisa continuamente el estado de la licencia.
    public func startPeriodicHeartbeat(
        intervalSeconds: TimeInterval = 60,
        tokenProvider: @escaping () -> String?,
        onUpdate: @escaping (HeartbeatPayload) -> Void,
        onFailure: @escaping (AuthError) -> Void
    ) {
        stopHeartbeat()
        
        heartbeatTask = Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            
            while !Task.isCancelled {
                guard let token = tokenProvider() else {
                    await MainActor.run {
                        onFailure(.unauthorized)
                    }
                    break
                }
                
                do {
                    let result = try await self.sendHeartbeat(token: token)
                    await MainActor.run {
                        onUpdate(result)
                    }
                } catch let error as AuthError {
                    await MainActor.run {
                        onFailure(error)
                    }
                    // Si la sesión fue revocada, baneada o expiró, detenemos el monitor
                    switch error {
                    case .unauthorized, .licenseBanned, .licenseExpired, .hwidMismatch:
                        break
                    default:
                        // En caso de fallo transitorio de red, continuamos en el siguiente intervalo
                        break
                    }
                } catch {
                    await MainActor.run {
                        onFailure(.networkError(error.localizedDescription))
                    }
                }
                
                // Esperar el intervalo indicado de forma cooperativa
                do {
                    try await Task.sleep(nanoseconds: UInt64(intervalSeconds * 1_000_000_000))
                } catch {
                    break // Tarea cancelada
                }
            }
        }
    }
    
    /// Detiene la supervisión de Heartbeat.
    public func stopHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }
}
