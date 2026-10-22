import SwiftUI

public struct ContentView: View {
    @ObservedObject var store = CubeBabyStore.shared
    @ObservedObject var midi = CubeBabyMidiDriver.shared

    @State private var showingCabSheet = false
    @State private var showingPresetsSheet = false

    public init() {}

    private var currentDelayMs: Int {
        // CUBE Baby time scale: time 0..31 maps roughly to 30ms - 1000ms
        return Int(30 + Double(store.currentParams.time) * 31.0)
    }

    public var body: some View {
        ZStack {
            // Fondo oscuro estilo estudio
            Color(white: 0.08).edgesIgnoringSafeArea(.all)

            VStack(spacing: 12) {
                // MARK: - Barra Superior (Status & Actions)
                HStack(spacing: 12) {
                    // Badge de Conexión
                    HStack(spacing: 6) {
                        Circle()
                            .fill(midi.isConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                            .shadow(color: midi.isConnected ? Color.green : Color.red, radius: 4)

                        Text(midi.isConnected ? midi.deviceName : "Desconectado")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(white: 0.15))
                    .cornerRadius(20)
                    .onTapGesture {
                        midi.scanAndConnect()
                    }

                    Spacer()

                    // Botón Presets Cristiana / Banco
                    Button(action: {
                        showingPresetsSheet = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "music.note.list")
                            Text("Presets")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(white: 0.18))
                        .foregroundColor(.cyan)
                        .cornerRadius(8)
                    }

                    // Botón Guardar Slot Activo
                    Button(action: {
                        store.saveActiveSlot()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Guardar \(store.activeSlot)")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.green)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                        .shadow(color: Color.green.opacity(0.3), radius: 6)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Toast de Guardado Exitoso
                if store.saveSuccessToast {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                        Text("¡Preset \(store.activeSlot) guardado físicamente en el CUBE Baby!")
                    }
                    .font(.footnote.bold())
                    .foregroundColor(.black)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 14)
                    .background(Color.green)
                    .cornerRadius(20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // MARK: - Chasis del Pedal CUBE Baby
                VStack(spacing: 16) {
                    // Header Chasis
                    HStack {
                        // Tornillo metálico
                        Circle().fill(Color(white: 0.3)).frame(width: 8, height: 8)
                        Spacer()
                        Text("M-VAVE · CUBE BABY")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(2)
                        Spacer()
                        Circle().fill(Color(white: 0.3)).frame(width: 8, height: 8)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)

                    // FILA 1 DE PERILLAS (Volumen, Cab, Reverb, Mix, Feedback)
                    HStack(spacing: 8) {
                        KnobView(
                            title: "VOLUME",
                            value: store.currentParams.volume,
                            maxValue: 127,
                            tintColor: .cyan,
                            onValueChanged: { store.updateParam(.volume, value: $0) }
                        )

                        KnobView(
                            title: "IR CAB",
                            value: store.currentParams.cabinet,
                            maxValue: 8,
                            tintColor: .green,
                            onValueChanged: { store.updateParam(.cabinet, value: $0) }
                        )
                        .onTapGesture {
                            showingCabSheet = true
                        }

                        KnobView(
                            title: "REVERB",
                            value: store.currentParams.reverb,
                            maxValue: 15,
                            tintColor: Color(red: 0.3, green: 0.8, blue: 0.9),
                            onValueChanged: { store.updateParam(.reverb, value: $0) }
                        )

                        KnobView(
                            title: "MIX",
                            value: store.currentParams.mix,
                            maxValue: 118,
                            tintColor: .cyan,
                            onValueChanged: { store.updateParam(.mix, value: $0) }
                        )

                        KnobView(
                            title: "FB",
                            value: store.currentParams.feedback,
                            maxValue: 127,
                            tintColor: .cyan,
                            onValueChanged: { store.updateParam(.feedback, value: $0) }
                        )
                    }

                    // FILA 2 DE PERILLAS (Time, Mod, Tone, Gain, Type)
                    HStack(spacing: 8) {
                        KnobView(
                            title: "TIME",
                            value: store.currentParams.time,
                            maxValue: 31,
                            tintColor: .cyan,
                            onValueChanged: { store.updateParam(.time, value: $0) }
                        )

                        KnobView(
                            title: "MOD",
                            value: store.currentParams.modulation,
                            maxValue: 15,
                            tintColor: Color(red: 0.8, green: 0.5, blue: 0.9),
                            isBipolarMod: true,
                            onValueChanged: { store.updateParam(.modulation, value: $0) }
                        )

                        KnobView(
                            title: "TONE",
                            value: store.currentParams.tone,
                            maxValue: 15,
                            tintColor: Color(red: 1.0, green: 0.4, blue: 0.5),
                            onValueChanged: { store.updateParam(.tone, value: $0) }
                        )

                        KnobView(
                            title: "GAIN",
                            value: store.currentParams.gain,
                            maxValue: 7,
                            tintColor: Color(red: 1.0, green: 0.4, blue: 0.5),
                            onValueChanged: { store.updateParam(.gain, value: $0) }
                        )

                        KnobView(
                            title: "TYPE",
                            value: store.currentParams.type,
                            maxValue: 8,
                            tintColor: Color(red: 1.0, green: 0.4, blue: 0.5),
                            onValueChanged: { store.updateParam(.type, value: $0) }
                        )
                    }

                    Divider().background(Color.white.opacity(0.1)).padding(.horizontal, 10)

                    // FOOTSWITCHES A, B, C
                    HStack(spacing: 36) {
                        FootswitchView(
                            slot: "A",
                            isSelected: store.activeSlot == "A",
                            onSelect: { store.selectSlot("A") }
                        )

                        FootswitchView(
                            slot: "B",
                            isSelected: store.activeSlot == "B",
                            onSelect: { store.selectSlot("B") }
                        )

                        FootswitchView(
                            slot: "C",
                            isSelected: store.activeSlot == "C",
                            onSelect: { store.selectSlot("C") }
                        )
                    }
                    .padding(.bottom, 8)
                }
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.16), Color(white: 0.12)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .padding(.horizontal, 12)

                // MARK: - Barra Inferior (Delay Info & Cab 8 Quick Access)
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform.path")
                            .foregroundColor(.cyan)
                        Text("Delay: \(currentDelayMs) ms")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Spacer()

                    Button(action: {
                        showingCabSheet = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundColor(.green)
                            Text(store.currentParams.cabinet == 8 ? "Cab 8 (Custom IR)" : "Cab \(store.currentParams.cabinet)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)

                Spacer()
            }
        }
        .sheet(isPresented: $showingCabSheet) {
            CabinetPickerSheet()
        }
        .sheet(isPresented: $showingPresetsSheet) {
            PresetsSheet()
        }
    }
}
