import Foundation
import SwiftUI
import Combine

public struct SlotParams: Codable, Equatable {
    public var slot: String
    public var type: Int
    public var gain: Int
    public var tone: Int
    public var reverb: Int
    public var feedback: Int
    public var volume: Int
    public var time: Int
    public var mix: Int
    public var modulation: Int
    public var cabinet: Int
    public var irSection: Int
    public var delaySection: Int
    public var toneSection: Int

    public init(
        slot: String = "A",
        type: Int = 1,
        gain: Int = 3,
        tone: Int = 5,
        reverb: Int = 2,
        feedback: Int = 0,
        volume: Int = 100,
        time: Int = 16,
        mix: Int = 0,
        modulation: Int = 8,
        cabinet: Int = 8,
        irSection: Int = 1,
        delaySection: Int = 0,
        toneSection: Int = 1
    ) {
        self.slot = slot
        self.type = type
        self.gain = gain
        self.tone = tone
        self.reverb = reverb
        self.feedback = feedback
        self.volume = volume
        self.time = time
        self.mix = mix
        self.modulation = modulation
        self.cabinet = cabinet
        self.irSection = irSection
        self.delaySection = delaySection
        self.toneSection = toneSection
    }

    public static func fromBytes(slot: String, bytes: [UInt8]) -> SlotParams {
        guard bytes.count >= 13 else { return SlotParams(slot: slot) }
        return SlotParams(
            slot: slot,
            type: Int(bytes[0]),
            gain: Int(bytes[1]),
            tone: Int(bytes[2]),
            reverb: Int(bytes[3]),
            feedback: Int(bytes[4]),
            volume: Int(bytes[5]),
            time: Int(bytes[6]),
            mix: Int(bytes[7]),
            modulation: Int(bytes[8]),
            cabinet: Int(bytes[9]),
            irSection: Int(bytes[10]),
            delaySection: Int(bytes[11]),
            toneSection: Int(bytes[12])
        )
    }

    public func toBytes() -> [UInt8] {
        return [
            UInt8(type),
            UInt8(gain),
            UInt8(tone),
            UInt8(reverb),
            UInt8(feedback),
            UInt8(volume),
            UInt8(time),
            UInt8(mix),
            UInt8(modulation),
            UInt8(cabinet),
            UInt8(irSection),
            UInt8(delaySection),
            UInt8(toneSection),
            0, 0, 0 // 16 bytes padding
        ]
    }
}

public final class CubeBabyStore: ObservableObject {
    public static let shared = CubeBabyStore()

    @Published public var activeSlot: String = "B" // A, B, C
    @Published public var slotA: SlotParams = SlotParams(slot: "A")
    @Published public var slotB: SlotParams = SlotParams(slot: "B")
    @Published public var slotC: SlotParams = SlotParams(slot: "C")

    @Published public var currentParams: SlotParams = SlotParams(slot: "B")
    @Published public var isSyncing: Bool = false
    @Published public var saveSuccessToast: Bool = false

    private let midi = CubeBabyMidiDriver.shared
    private var cancellables = Set<AnyCancellable>()

    public init() {
        midi.responsePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] response in
                self?.handlePedalResponse(response)
            }
            .store(in: &cancellables)

        midi.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                if connected {
                    self?.readBankFromPedal()
                }
            }
            .store(in: &cancellables)
    }

    public var currentSlotIndex: Int {
        switch activeSlot {
        case "A": return 0
        case "B": return 1
        case "C": return 2
        default: return 0
        }
    }

    public func selectSlot(_ slot: String) {
        guard slot != activeSlot else { return }
        activeSlot = slot
        switch slot {
        case "A": currentParams = slotA
        case "B": currentParams = slotB
        case "C": currentParams = slotC
        default: break
        }

        // Apply slot params to live RAM
        applyCurrentParamsToLive()
    }

    public func updateParam(_ param: LiveParam, value: Int) {
        switch param {
        case .type: currentParams.type = value
        case .gain: currentParams.gain = value
        case .tone: currentParams.tone = value
        case .reverb: currentParams.reverb = value
        case .feedback: currentParams.feedback = value
        case .volume: currentParams.volume = value
        case .time: currentParams.time = value
        case .mix: currentParams.mix = value
        case .modulation: currentParams.modulation = value
        case .cabinet: currentParams.cabinet = value
        case .irSection: currentParams.irSection = value
        case .delaySection: currentParams.delaySection = value
        case .toneSection: currentParams.toneSection = value
        }

        // Push live to pedal RAM immediately
        let req = CubeBabyRequestBuilder.buildLiveParamWrite(
            slotIndex: currentSlotIndex,
            param: param,
            value: value
        )
        midi.send(sysex: req)
    }

    public func applyCurrentParamsToLive() {
        for param in LiveParam.allCases {
            let val: Int
            switch param {
            case .type: val = currentParams.type
            case .gain: val = currentParams.gain
            case .tone: val = currentParams.tone
            case .reverb: val = currentParams.reverb
            case .feedback: val = currentParams.feedback
            case .volume: val = currentParams.volume
            case .time: val = currentParams.time
            case .mix: val = currentParams.mix
            case .modulation: val = currentParams.modulation
            case .cabinet: val = currentParams.cabinet
            case .irSection: val = currentParams.irSection
            case .delaySection: val = currentParams.delaySection
            case .toneSection: val = currentParams.toneSection
            }
            let req = CubeBabyRequestBuilder.buildLiveParamWrite(
                slotIndex: currentSlotIndex,
                param: param,
                value: val
            )
            midi.send(sysex: req)
        }
    }

    public func saveActiveSlot() {
        switch activeSlot {
        case "A": slotA = currentParams
        case "B": slotB = currentParams
        case "C": slotC = currentParams
        default: break
        }

        // Build full 48-byte bank image
        var bankData = Data()
        bankData.append(contentsOf: slotA.toBytes())
        bankData.append(contentsOf: slotB.toBytes())
        bankData.append(contentsOf: slotC.toBytes())

        let req = CubeBabyRequestBuilder.buildMemoryWriteRequest(
            memory: CubeBabyConstants.bankMemory,
            address: CubeBabyConstants.bankAddress,
            data: bankData
        )
        midi.send(sysex: req)

        saveSuccessToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.saveSuccessToast = false
        }
    }

    public func readBankFromPedal() {
        isSyncing = true
        let req = CubeBabyRequestBuilder.buildMemoryReadRequest(
            memory: CubeBabyConstants.bankMemory,
            address: CubeBabyConstants.bankAddress,
            length: CubeBabyConstants.bankLength
        )
        midi.send(sysex: req)
    }

    private func handlePedalResponse(_ response: CubeBabyResponse) {
        if response.messageType == CubeBabyConstants.msgMemoryRead {
            // Memory read response: offset 0..7 is header, payload starts at 8
            if response.content.count >= 8 + CubeBabyConstants.bankLength {
                let bankBytes = [UInt8](response.content.subdata(in: 8..<(8 + CubeBabyConstants.bankLength)))
                let slotABytes = Array(bankBytes[0..<16])
                let slotBBytes = Array(bankBytes[16..<32])
                let slotCBytes = Array(bankBytes[32..<48])

                self.slotA = SlotParams.fromBytes(slot: "A", bytes: slotABytes)
                self.slotB = SlotParams.fromBytes(slot: "B", bytes: slotBBytes)
                self.slotC = SlotParams.fromBytes(slot: "C", bytes: slotCBytes)

                switch activeSlot {
                case "A": currentParams = slotA
                case "B": currentParams = slotB
                case "C": currentParams = slotC
                default: break
                }
                isSyncing = false
                print("[CubeStore] Banco completo leído exitosamente desde el CUBE Baby")
            }
        }
    }

    public func loadWorshipPresets() {
        // Preset A: Clean Worship / Adoración
        slotA = SlotParams(
            slot: "A",
            type: 2,
            gain: 3,
            tone: 5,
            reverb: 2,
            feedback: 0,
            volume: 105,
            time: 0,
            mix: 0,
            modulation: 8, // OFF
            cabinet: 8,
            irSection: 1,
            delaySection: 0,
            toneSection: 1
        )

        // Preset B: Coros Dinámicos / Júbilo / Rock Cristiano
        slotB = SlotParams(
            slot: "B",
            type: 4,
            gain: 5,
            tone: 6,
            reverb: 0,
            feedback: 0,
            volume: 110,
            time: 0,
            mix: 0,
            modulation: 8, // OFF
            cabinet: 8,
            irSection: 1,
            delaySection: 0,
            toneSection: 1
        )

        // Preset C: Ambient / Melódico / Oración
        slotC = SlotParams(
            slot: "C",
            type: 1,
            gain: 2,
            tone: 6,
            reverb: 5,
            feedback: 35,
            volume: 100,
            time: 16,
            mix: 45,
            modulation: 2, // Chorus sutil
            cabinet: 8,
            irSection: 1,
            delaySection: 1,
            toneSection: 1
        )

        switch activeSlot {
        case "A": currentParams = slotA
        case "B": currentParams = slotB
        case "C": currentParams = slotC
        default: break
        }

        saveActiveSlot()
    }
}
