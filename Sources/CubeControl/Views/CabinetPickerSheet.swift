import SwiftUI
import UniformTypeIdentifiers

public struct CabinetPickerSheet: View {
    @ObservedObject var store = CubeBabyStore.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var showingFileImporter = false
    @State private var importedFileName: String = "07_Ampeg_SVT-810E.wav"

    let cabinetNames = [
        "1. Fender 1x12 Deluxe",
        "2. Marshall 4x12 1960A",
        "3. Vox 2x12 AC30",
        "4. Mesa Boogie 4x12 Recto",
        "5. Orange 2x12 PPC212",
        "6. Soldano 4x12 SLO",
        "7. Peavey 5150 Standard",
        "8. Usuario / Custom IR (Ampeg 8x10)"
    ]

    public var body: some View {
        NavigationView {
            ZStack {
                Color(white: 0.10).edgesIgnoringSafeArea(.all)

                VStack(spacing: 16) {
                    Text("Selecciona el Gabinete / IR")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.top, 10)

                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(1...8, id: \.self) { cab in
                                Button(action: {
                                    store.updateParam(.cabinet, value: cab)
                                }) {
                                    HStack {
                                        Image(systemName: store.currentParams.cabinet == cab ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(store.currentParams.cabinet == cab ? .green : .gray)
                                            .font(.title3)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(cabinetNames[cab - 1])
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(.white)
                                            if cab == 8 {
                                                Text("Slot de usuario: Ideal para IRs de bajo")
                                                    .font(.caption)
                                                    .foregroundColor(.green.opacity(0.8))
                                            }
                                        }

                                        Spacer()

                                        if cab == 8 {
                                            Button(action: {
                                                showingFileImporter = true
                                            }) {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "square.and.arrow.down")
                                                    Text("Cargar WAV")
                                                }
                                                .font(.caption.bold())
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(Color.green.opacity(0.25))
                                                .foregroundColor(.green)
                                                .cornerRadius(8)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(store.currentParams.cabinet == cab ? Color.green.opacity(0.15) : Color(white: 0.16))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(store.currentParams.cabinet == cab ? Color.green.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    Spacer()
                }
            }
            .navigationBarTitle("Gabinete / IR", displayMode: .inline)
            .navigationBarItems(trailing: Button("Cerrar") {
                presentationMode.wrappedValue.dismiss()
            }.foregroundColor(.green))
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.audio, .wav],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let firstUrl = urls.first {
                        importedFileName = firstUrl.lastPathComponent
                        store.updateParam(.cabinet, value: 8)
                        print("[CubeControl] IR cargado: \(importedFileName)")
                    }
                case .failure(let error):
                    print("[CubeControl] Error importando IR: \(error.localizedDescription)")
                }
            }
        }
    }
}
