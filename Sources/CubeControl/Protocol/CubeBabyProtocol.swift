import Foundation

// MARK: - Constants & Memory Addresses
public enum CubeBabyConstants {
    public static let magic0: UInt8 = 0x00
    public static let magic1: UInt8 = 0x59

    public static let msgAck: UInt8 = 0x00
    public static let msgIdentity: UInt8 = 0x11
    public static let msgErase: UInt8 = 0x21
    public static let msgMemoryWrite: UInt8 = 0x22
    public static let msgMemoryRead: UInt8 = 0x23
    public static let msgRegisterWrite: UInt8 = 0x24

    public static let bankMemory: UInt8 = 5
    public static let bankAddress: UInt32 = 0x0000_0000
    public static let bankLength: Int = 48
    public static let slotLength: Int = 16

    public static let liveParamBaseAddress: UInt32 = 0x8000_0000
    public static let liveParamMaxOffset: Int = 0x2C

    public static let irLiveMemory: UInt8 = 0x04
    public static let irLiveFlagAddress: UInt32 = 0x0000_0764
    public static let irLiveDataAddress: UInt32 = 0x0000_0768
    public static let irRomMemory: UInt8 = 0x00
    public static let irRomUploadAddress: UInt32 = 0x0007_0000
    public static let irRomChunkSize: Int = 128
    public static let irRomPayloadLength: Int = 2056
    public static let irRomSlotStride: Int = 0x1000
}

// MARK: - Parameter Names & Offsets
public enum LiveParam: String, CaseIterable, Identifiable {
    case type
    case gain
    case tone
    case reverb
    case feedback
    case volume
    case time
    case mix
    case modulation
    case cabinet
    case irSection
    case delaySection
    case toneSection

    public var id: String { rawValue }

    public var offset: Int {
        switch self {
        case .type: return 0
        case .gain: return 1
        case .tone: return 2
        case .reverb: return 3
        case .feedback: return 4
        case .volume: return 5
        case .time: return 6
        case .mix: return 7
        case .modulation: return 8
        case .cabinet: return 9
        case .irSection: return 10
        case .delaySection: return 11
        case .toneSection: return 12
        }
    }

    public var maxValue: Int {
        switch self {
        case .type: return 8
        case .gain: return 7
        case .tone: return 15
        case .reverb: return 15
        case .feedback: return 127
        case .volume: return 127
        case .time: return 31
        case .mix: return 118
        case .modulation: return 15
        case .cabinet: return 8
        case .irSection: return 1
        case .delaySection: return 1
        case .toneSection: return 1
        }
    }

    public var displayName: String {
        switch self {
        case .type: return "TYPE"
        case .gain: return "GAIN"
        case .tone: return "TONE"
        case .reverb: return "REVERB"
        case .feedback: return "FB"
        case .volume: return "VOLUME"
        case .time: return "TIME"
        case .mix: return "MIX"
        case .modulation: return "MOD"
        case .cabinet: return "CAB"
        case .irSection: return "IR ON"
        case .delaySection: return "DLY ON"
        case .toneSection: return "TONE ON"
        }
    }
}

// MARK: - 7-bit Encoding and Decoding
public enum SevenBitCodec {
    public static func encode(_ source: Data) -> Data {
        var destination = [UInt8]()
        var bitCount = 0
        var accumulator: UInt32 = 0

        for byte in source {
            accumulator = (accumulator | (UInt32(byte) << (bitCount & 0x1F)))
            bitCount += 1

            while true {
                destination.append(UInt8(accumulator & 0x7F))
                accumulator >>= 7
                if bitCount < 7 { break }
                bitCount -= 7
            }
        }

        if accumulator > 0 {
            destination.append(UInt8(accumulator & 0x7F))
        }

        let paddedLength = Int(ceil(Double(source.count * 8) / 7.0))
        while destination.count < paddedLength {
            destination.append(0)
        }

        return Data(destination)
    }

    public static func decode(_ source: Data) -> Data {
        var destination = [UInt8]()
        var bitCount = 0
        var lastValue: UInt8 = 0

        for byte in source {
            let mask: UInt32 = bitCount == 0 ? 0 : (0xFFFF_FFFF >> (32 - bitCount))
            let accumulator = UInt32(byte) & mask
            if bitCount > 0 {
                let combined = (lastValue & 0x7F) | UInt8((accumulator << (8 - bitCount)) & 0xFF)
                destination.append(combined)
            }
            lastValue = UInt8(UInt32(byte) >> bitCount)
            bitCount = (bitCount + 1) % 8
        }

        if lastValue > 0 {
            destination.append(lastValue)
        }

        return Data(destination)
    }
}

// MARK: - Checksum and Helpers
public enum Checksum {
    public static func calculate(_ content: Data) -> UInt8 {
        var sum: UInt32 = 0
        for byte in content {
            sum = (sum + UInt32(byte)) & 0xFF
        }
        return UInt8((~sum) & 0xFF)
    }
}

// MARK: - Request Builder
public enum CubeBabyRequestBuilder {
    private static func writeUint24LE(_ value: Int) -> [UInt8] {
        return [
            UInt8(value & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8((value >> 16) & 0xFF)
        ]
    }

    private static func writeUint32LE(_ value: UInt32) -> [UInt8] {
        return [
            UInt8(value & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 24) & 0xFF)
        ]
    }

    public static func encodeEnvelope(messageType: UInt8, content: Data) -> Data {
        var clear = [UInt8]()
        clear.append(CubeBabyConstants.magic0)
        clear.append(CubeBabyConstants.magic1)
        clear.append(messageType)
        clear.append(contentsOf: writeUint24LE(content.count))
        clear.append(contentsOf: content)
        clear.append(Checksum.calculate(content))

        let encoded = SevenBitCodec.encode(Data(clear))
        var sysex = Data([0xF0])
        sysex.append(encoded)
        sysex.append(0xF7)
        return sysex
    }

    public static func buildIdentityRequest() -> Data {
        return encodeEnvelope(messageType: CubeBabyConstants.msgIdentity, content: Data())
    }

    public static func buildMemoryReadRequest(memory: UInt8, address: UInt32, length: Int) -> Data {
        var content = [UInt8]()
        content.append(memory)
        content.append(contentsOf: writeUint32LE(address))
        content.append(contentsOf: writeUint24LE(length))
        return encodeEnvelope(messageType: CubeBabyConstants.msgMemoryRead, content: Data(content))
    }

    public static func buildMemoryWriteRequest(memory: UInt8, address: UInt32, data: Data) -> Data {
        var content = [UInt8]()
        content.append(memory)
        content.append(contentsOf: writeUint32LE(address))
        content.append(contentsOf: writeUint24LE(data.count))
        content.append(contentsOf: data)
        return encodeEnvelope(messageType: CubeBabyConstants.msgMemoryWrite, content: Data(content))
    }

    public static func buildLiveParamWrite(slotIndex: Int, param: LiveParam, value: Int) -> Data {
        let clamped = max(0, min(param.maxValue, value))
        let address = CubeBabyConstants.liveParamBaseAddress + UInt32(slotIndex * 16 + param.offset)
        return buildMemoryWriteRequest(
            memory: CubeBabyConstants.bankMemory,
            address: address,
            data: Data([UInt8(clamped)])
        )
    }

    public static func buildSelectCabinet(cabinet: Int) -> Data {
        let clamped = max(0, min(8, cabinet))
        let address = CubeBabyConstants.liveParamBaseAddress + UInt32(LiveParam.cabinet.offset)
        return buildMemoryWriteRequest(
            memory: CubeBabyConstants.bankMemory,
            address: address,
            data: Data([UInt8(clamped)])
        )
    }
}

// MARK: - Response Decoder
public struct CubeBabyResponse {
    public let messageType: UInt8
    public let declaredLength: Int
    public let content: Data
    public let isValidChecksum: Bool

    public static func decode(sysex: Data) -> CubeBabyResponse? {
        guard sysex.count >= 3, sysex.first == 0xF0, sysex.last == 0xF7 else {
            return nil
        }

        let encodedPayload = sysex.subdata(in: 1..<(sysex.count - 1))
        let clear = SevenBitCodec.decode(encodedPayload)

        guard clear.count >= 7 else { return nil }
        guard clear[0] == CubeBabyConstants.magic0, clear[1] == CubeBabyConstants.magic1 else {
            return nil
        }

        let messageType = clear[2]
        let declaredLength = Int(clear[3]) | (Int(clear[4]) << 8) | (Int(clear[5]) << 16)
        let expectedLength = 7 + declaredLength
        guard clear.count >= expectedLength else { return nil }

        let content = clear.subdata(in: 6..<(6 + declaredLength))
        let checksum = clear[6 + declaredLength]
        let calculated = Checksum.calculate(content)

        return CubeBabyResponse(
            messageType: messageType,
            declaredLength: declaredLength,
            content: content,
            isValidChecksum: checksum == calculated
        )
    }
}
