# iOS Node-Locked License Client (SwiftUI + Keychain)

Aplicación cliente completa en Swift y SwiftUI para la activación, bloqueo por hardware (*Node-Locked*) y gestión de configuraciones locales con integración a la API de licencias.

---

## 📱 Requisitos Técnicos de la App
- **iOS:** 16.0 o superior.
- **Xcode:** 15.0 o superior.
- **Lenguaje:** Swift 5.9 / Swift 6.
- **Frameworks:** SwiftUI, Security (Keychain), Combine, UIKit.

---

## 🗂️ Estructura de Archivos

1. **`KeychainManager.swift`**:
   - Gestiona el almacenamiento en el Keychain de iOS utilizando `kSecClassGenericPassword` y la bandera `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
   - Garantiza que el `hwid` persista entre reinstalaciones de la aplicación y **no se sincronice con otros dispositivos mediante copias de seguridad de iCloud**.
   - Almacena el token de sesión JWT y la última clave usada de manera segura.

2. **`LicenseModels.swift`**:
   - Modelos `Codable` para peticiones y respuestas coincidentes con el backend Express/PostgreSQL (`AuthRequest`, `AuthPayload`, `HeartbeatPayload`).
   - Errores personalizados (`AuthError`) con descripciones localizadas en español.
   - Modelos de interfaz para los interruptores del Dashboard (`ConfigCategory`, `ConfigItem`).

3. **`AuthService.swift`**:
   - Cliente HTTP moderno con `async/await` y `URLSession`.
   - Realiza la activación en `POST /api/v1/auth` y el monitoreo puntual en `GET /api/v1/heartbeat`.
   - Implementa una tarea recurrente en segundo plano con `Task.detached` y `Task.sleep` para verificar el estado de la licencia de forma periódica (Heartbeat continuo).

4. **`AppViewModel.swift`**:
   - Gestor de estado `@MainActor ObservableObject` que coordina la persistencia, el inicio de sesión automático silencioso, la validación de claves y la revocación por baneo/expiración.
   - Serializa la configuración seleccionada en los interruptores y construye el `URL` con parámetros para invocar la app externa.

5. **`LoginView.swift`**:
   - Pantalla bloqueante inicial.
   - Formateador automático en tiempo real para el patrón `XXXX-XXXX-XXXX`.
   - Tarjeta con el HWID persistente del dispositivo con botón para copiarlo al portapapeles.
   - Indicador de progreso y alertas informativas.

6. **`DashboardView.swift`**:
   - Tarjeta superior con el estado de la licencia (monospaced), rol, fecha de vencimiento y tiempo restante dinámico calculado por el Heartbeat.
   - Lista categorizada con interruptores (`Toggle`) para habilitar/deshabilitar parámetros locales (Rendimiento, Red, Seguridad).
   - Botón de acción principal fijado en la parte inferior: **"Aplicar configuración y lanzar aplicación externa"**.
   - Hoja de ajustes para configurar el URL Scheme de destino.

7. **`RootView.swift`**:
   - Transición fluida con animación de resorte entre la vista de Login y el Dashboard.

8. **`NodeLockedLicenseApp.swift`**:
   - Punto de entrada principal (`@main`).

---

## ⚙️ Configuración en Xcode (Info.plist)

Para permitir la comunicación HTTP local y la apertura del URL Scheme de la app externa, añade lo siguiente a tu archivo `Info.plist`:

```xml
<!-- Permitir HTTP local para pruebas de desarrollo -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>

<!-- Registrar esquemas URL externos que la app puede consultar -->
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>targetapp</string>
</array>
```
