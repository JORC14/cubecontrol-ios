import Foundation
import CoreMIDI
import Combine

public final class CubeBabyMidiDriver: ObservableObject {
    public static let shared = CubeBabyMidiDriver()

    @Published public var isConnected: Bool = false
    @Published public var deviceName: String = "Desconectado"
    @Published public var statusMessage: String = "Conecta el pedal por cable USB"

    public let responsePublisher = PassthroughSubject<CubeBabyResponse, Never>()
    public let rawSysexPublisher = PassthroughSubject<Data, Never>()

    private var midiClient = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    private var outputPort = MIDIPortRef()
    private var selectedSource: MIDIEndpointRef = 0
    private var selectedDestination: MIDIEndpointRef = 0

    private var incomingBuffer = Data()

    public init() {
        setupMidi()
    }

    private func setupMidi() {
        var status = MIDIClientCreateWithBlock("CubeControlMidiClient" as CFString, &midiClient) { [weak self] notificationPtr in
            self?.handleMidiNotification(notificationPtr)
        }
        guard status == noErr else {
            print("[CubeMIDI] Error creando MIDIClient: \(status)")
            return
        }

        status = MIDIInputPortCreateWithBlock(midiClient, "CubeControlInput" as CFString, &inputPort) { [weak self] packetListPtr, _ in
            self?.handleIncomingPackets(packetListPtr)
        }
        guard status == noErr else {
            print("[CubeMIDI] Error creando InputPort: \(status)")
            return
        }

        status = MIDIOutputPortCreate(midiClient, "CubeControlOutput" as CFString, &outputPort)
        guard status == noErr else {
            print("[CubeMIDI] Error creando OutputPort: \(status)")
            return
        }

        scanAndConnect()
    }

    public func scanAndConnect() {
        let sourceCount = MIDIGetNumberOfSources()
        let destCount = MIDIGetNumberOfDestinations()

        print("[CubeMIDI] Escaneando... Fuentes: \(sourceCount), Destinos: \(destCount)")

        var matchedSource: MIDIEndpointRef = 0
        var matchedDest: MIDIEndpointRef = 0
        var foundName = "CUBE Baby"

        // Buscar fuente
        for i in 0..<sourceCount {
            let src = MIDIGetSource(i)
            let name = getEndpointName(src)
            print("[CubeMIDI] Fuente \(i): \(name)")
            if name.localizedCaseInsensitiveContains("midi") ||
               name.localizedCaseInsensitiveContains("cube") ||
               name.localizedCaseInsensitiveContains("sinco") {
                matchedSource = src
                foundName = name
                break
            }
        }

        // Buscar destino
        for i in 0..<destCount {
            let dst = MIDIGetDestination(i)
            let name = getEndpointName(dst)
            print("[CubeMIDI] Destino \(i): \(name)")
            if name.localizedCaseInsensitiveContains("midi") ||
               name.localizedCaseInsensitiveContains("cube") ||
               name.localizedCaseInsensitiveContains("sinco") {
                matchedDest = dst
                break
            }
        }

        // Si no encontró por nombre pero hay exactamente 1 dispositivo USB conectado
        if matchedSource == 0 && sourceCount > 0 {
            matchedSource = MIDIGetSource(0)
            foundName = getEndpointName(matchedSource)
        }
        if matchedDest == 0 && destCount > 0 {
            matchedDest = MIDIGetDestination(0)
        }

        if matchedSource != 0 && matchedDest != 0 {
            connectEndpoints(source: matchedSource, destination: matchedDest, name: foundName)
        } else {
            DispatchQueue.main.async {
                self.isConnected = false
                self.deviceName = "Desconectado"
                self.statusMessage = "Conecta el pedal por USB OTG"
            }
        }
    }

    private func connectEndpoints(source: MIDIEndpointRef, destination: MIDIEndpointRef, name: String) {
        MIDIPortDisconnectSource(inputPort, selectedSource)
        selectedSource = source
        selectedDestination = destination

        let status = MIDIPortConnectSource(inputPort, source, nil)
        DispatchQueue.main.async {
            if status == noErr {
                self.isConnected = true
                self.deviceName = name
                self.statusMessage = "Conectado vía USB"
                print("[CubeMIDI] Conectado exitosamente a: \(name)")
            } else {
                self.isConnected = false
                self.statusMessage = "Error al conectar puerto USB"
            }
        }
    }

    private func getEndpointName(_ endpoint: MIDIEndpointRef) -> String {
        var prop: Unmanaged<CFString>?
        let err = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &prop)
        if err == noErr, let name = prop?.takeRetainedValue() as String? {
            return name
        }
        let err2 = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &prop)
        if err2 == noErr, let name = prop?.takeRetainedValue() as String? {
            return name
        }
        return "Dispositivo MIDI"
    }

    private func handleMidiNotification(_ ptr: UnsafePointer<MIDINotification>) {
        let msgId = ptr.pointee.messageID
        print("[CubeMIDI] Notificación de hardware MIDI: \(msgId.rawValue)")
        DispatchQueue.main.async {
            self.scanAndConnect()
        }
    }

    private func handleIncomingPackets(_ packetListPtr: UnsafePointer<MIDIPacketList>) {
        let packetList = packetListPtr.pointee
        var packet = packetList.packet

        for _ in 0..<packetList.numPackets {
            let dataLength = Int(packet.length)
            withUnsafePointer(to: &packet.data) { dataPtr in
                let rawPtr = UnsafeRawPointer(dataPtr).assumingMemoryBound(to: UInt8.self)
                let bytes = Data(bytes: rawPtr, count: dataLength)
                self.processIncomingBytes(bytes)
            }
            packet = MIDIPacketNext(&packet).pointee
        }
    }

    private func processIncomingBytes(_ bytes: Data) {
        for byte in bytes {
            if byte == 0xF0 {
                incomingBuffer = Data([0xF0])
            } else if byte == 0xF7 {
                incomingBuffer.append(0xF7)
                let fullSysex = incomingBuffer
                incomingBuffer = Data()

                rawSysexPublisher.send(fullSysex)
                if let response = CubeBabyResponse.decode(sysex: fullSysex) {
                    responsePublisher.send(response)
                }
            } else if !incomingBuffer.isEmpty {
                incomingBuffer.append(byte)
            }
        }
    }

    public func send(sysex: Data) {
        guard isConnected, selectedDestination != 0 else {
            print("[CubeMIDI] Intento de envío pero no hay pedal conectado")
            return
        }

        var packetBuffer = [UInt8](repeating: 0, count: 1024 + sysex.count)
        packetBuffer.withUnsafeMutableBytes { rawBuf in
            let packetListPtr = rawBuf.baseAddress!.assumingMemoryBound(to: MIDIPacketList.self)
            let packetPtr = MIDIPacketListInit(packetListPtr)

            sysex.withUnsafeBytes { sysexBytes in
                let bytePtr = sysexBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
                _ = MIDIPacketListAdd(packetListPtr, 1024 + sysex.count, packetPtr, 0, sysex.count, bytePtr)
            }

            let status = MIDISend(outputPort, selectedDestination, packetListPtr)
            if status != noErr {
                print("[CubeMIDI] Error enviando MIDISend: \(status)")
            }
        }
    }
}
