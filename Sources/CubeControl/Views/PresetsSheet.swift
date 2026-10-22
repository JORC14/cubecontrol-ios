import SwiftUI

public struct PresetsSheet: View {
    @ObservedObject var store = CubeBabyStore.shared
    @Environment(\.presentationMode) var presentationMode

    public var body: some View {
        NavigationView {
            ZStack {
                Color(white: 0.10).edgesIgnoringSafeArea(.all)

                VStack(spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Bancos y Presets")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        Text("Carga configuraciones instantáneas para tus 3 footswitches A, B y C.")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    // Card: Worship & Alabanza
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "cross.fill")
                                .foregroundColor(.cyan)
                            Text("Pack Alabanza / Worship (Bajo)")
                                .font(.headline)
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("• Slot A: Clean Worship / Adoración (B-15, limpio y cálido)")
                            Text("• Slot B: Coros Dinámicos / Júbilo (Rock, ataque y pegada)")
                            Text("• Slot C: Ambient Melódico (Chorus + Delay + Reverb amplio)")
                        }
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))

                        Button(action: {
                            store.loadWorshipPresets()
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                Spacer()
                                Image(systemName: "arrow.down.circle.fill")
                                Text("Cargar Pack de Alabanza en A, B y C")
                                    .fontWeight(.bold)
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .background(Color.cyan)
                            .foregroundColor(.black)
                            .cornerRadius(10)
                        }
                    }
                    .padding(16)
                    .background(Color(white: 0.16))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)

                    // Operaciones de Memoria
                    VStack(spacing: 10) {
                        Button(action: {
                            store.readBankFromPedal()
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Leer Banco actual desde el Pedal")
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(white: 0.16))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }

                        Button(action: {
                            store.saveActiveSlot()
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                Image(systemName: "tray.and.arrow.down.fill")
                                Text("Guardar todos los slots en Memoria Flash")
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(white: 0.16))
                            .foregroundColor(.green)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer()
                }
            }
            .navigationBarTitle("Presets", displayMode: .inline)
            .navigationBarItems(trailing: Button("Cerrar") {
                presentationMode.wrappedValue.dismiss()
            }.foregroundColor(.cyan))
        }
    }
}
