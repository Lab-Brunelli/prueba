import SwiftUI

/// Panel de control con el flujo INDETECTABLE exacto.
/// Activás con el juego cargando (antes del lobby) → cargás el lobby → desactivás.
struct ModControlView: View {

    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

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
                                 ? "Cargá Free Fire hasta el lobby, después volvé y desactivá."
                                 : "Activá antes de que Free Fire lea los assets.")
                                .font(.caption2).foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                    }
                }

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

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("FLUJO INDETECTABLE").font(.caption.weight(.bold)).foregroundStyle(Theme.textSecondary)

                        step("1", "Abrí Free Fire y dejalo cargar hasta ~40%. Salí SIN cerrarlo (queda en segundo plano).", true)
                        step("2", "Abrí FX y elegí el mod en Inicio.", true)
                        step("3", "Tocá ACTIVAR acá.", true)
                        step("4", "Volvé a Free Fire y esperá a que cargue TODO y aparezca el lobby.", true)
                        step("5", "Volvé a FX y tocá DESACTIVAR.", true)
                        step("6", "Cerrá FX. Volvé a Free Fire y probá: el mod sigue andando.", false)

                        Divider().padding(.vertical, 4)

                        Text("Por qué no hay ban: nada se inyecta en el proceso del juego. Los assets se leen de archivo durante la carga y quedan en RAM. Al desactivar, el disco vuelve a estar 100% original.")
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
