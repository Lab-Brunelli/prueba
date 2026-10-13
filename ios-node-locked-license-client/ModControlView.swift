import SwiftUI

/// Panel de control con el flujo INDETECTABLE en 4 pasos.
/// Activás con el juego cerrado → cargás el juego → desactivás → seguís jugando.
struct ModControlView: View {

    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // Estado
                Card {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(vm.modsInstalled ? Theme.safeGreen : Theme.textSecondary)
                            .frame(width: 12, height: 12)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(vm.modsInstalled ? "MODS ACTIVOS EN DISCO" : "SIN MODS (disco original)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(vm.modsInstalled ? Theme.safeGreen : Theme.textPrimary)
                            Text(vm.modsInstalled
                                 ? "Cargá Free Fire ahora, después volvé y desactivá."
                                 : "Activá para escribir los mods.")
                                .font(.caption2).foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                    }
                }

                // Botón principal
                Button {
                    if vm.modsInstalled { vm.deactivateMods() } else { vm.activateMods() }
                } label: {
                    HStack(spacing: 10) {
                        if vm.isSyncing || vm.isRestoring { ProgressView().tint(.black) }
                        Image(systemName: vm.modsInstalled ? "stop.circle.fill" : "play.circle.fill")
                        Text(vm.modsInstalled ? "DESACTIVAR" : "ACTIVAR")
                            .fontWeight(.heavy)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
                    .background(vm.modsInstalled ? Theme.safeGreen : Color.orange)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(vm.isSyncing || vm.isRestoring)

                // Abrir juego
                Button {
                    vm.openFreeFire()
                } label: {
                    Label("ABRIR FREE FIRE", systemImage: "gamecontroller.fill")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Theme.card).foregroundStyle(Theme.textPrimary)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardStroke, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Guía
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("FLUJO INDETECTABLE")
                            .font(.caption.weight(.bold)).foregroundStyle(Theme.textSecondary)
                        step("1", "Abrí Free Fire y salí (crea los archivos base).", true)
                        step("2", "Cerrá Free Fire del todo.", true)
                        step("3", "Tocá ACTIVAR acá.", true)
                        step("4", "Abrí Free Fire y cargá hasta el LOBBY.", true)
                        step("5", "Volvé acá (no cierres Free Fire) y tocá DESACTIVAR.", true)
                        step("6", "Volvé a Free Fire: el mod sigue activo, disco original.", false)

                        Divider().padding(.vertical, 4)

                        Text("Por qué no hay ban: nada se inyecta en el proceso del juego. Los assets se leen de archivo al cargar y quedan en RAM. Después el disco vuelve a estar 100% original.")
                            .font(.caption2).foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let s = vm.lastSyncSummary {
                    Card { Text(s).font(.caption).foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true) }
                }
                if let r = vm.lastRestoreSummary {
                    Card { Text(r).font(.caption).foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true) }
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private func step(_ n: String, _ text: String, _ active: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(n)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.black)
                .frame(width: 18, height: 18)
                .background(active ? Theme.safeGreen : Theme.textSecondary)
                .clipShape(Circle())
            Text(text).font(.caption).foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}
