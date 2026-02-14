import Flutter
import UIKit
import CoreBluetooth
import SFPrintSDK

public class SupvanPrinterPlugin: NSObject, FlutterPlugin {

    private var methodChannel: FlutterMethodChannel?
    private var scanEventChannel: FlutterEventChannel?
    private var connectionEventChannel: FlutterEventChannel?

    var scanEventSink: FlutterEventSink?
    var connectionEventSink: FlutterEventSink?

    /// Discovered peripherals keyed by UUID string.
    private var discoveredPeripherals: [String: CBPeripheral] = [:]
    /// Currently connected peripheral.
    private var connectedPeripheral: CBPeripheral?
    /// Timer for polling connection state after connect call.
    private var connectionPollTimer: Timer?

    // MARK: - FlutterPlugin registration

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SupvanPrinterPlugin()

        let methodChannel = FlutterMethodChannel(
            name: "com.supvan.printer/methods",
            binaryMessenger: registrar.messenger()
        )
        instance.methodChannel = methodChannel
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        let scanChannel = FlutterEventChannel(
            name: "com.supvan.printer/scan",
            binaryMessenger: registrar.messenger()
        )
        instance.scanEventChannel = scanChannel

        let scanHandler = ScanStreamHandler(plugin: instance)
        scanChannel.setStreamHandler(scanHandler)

        let connectionChannel = FlutterEventChannel(
            name: "com.supvan.printer/connection",
            binaryMessenger: registrar.messenger()
        )
        instance.connectionEventChannel = connectionChannel

        let connHandler = ConnectionStreamHandler(plugin: instance)
        connectionChannel.setStreamHandler(connHandler)
    }

    // MARK: - FlutterMethodCallHandler

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startScan":
            handleStartScan(result: result)
        case "stopScan":
            handleStopScan(result: result)
        case "connect":
            handleConnect(call: call, result: result)
        case "disconnect":
            handleDisconnect(result: result)
        case "getStatus":
            handleGetStatus(result: result)
        case "print":
            handlePrint(call: call, result: result)
        case "cancelPrint":
            SFPrintSDKUtils.shareInstance().cancelPrint()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Scan

    private func handleStartScan(result: @escaping FlutterResult) {
        discoveredPeripherals.removeAll()

        let sdk = SFPrintSDKUtils.shareInstance()

        // Re-set findDeviceBlock every time before scanning,
        // matching the pattern used in the original ObjC demo.
        sdk.findDeviceBlock = { [weak self] peripheral in
            guard let self = self else { return }
            let uuid = peripheral.identifier.uuidString
            let name = peripheral.name ?? "Unknown"

            if self.discoveredPeripherals[uuid] == nil {
                self.discoveredPeripherals[uuid] = peripheral
                DispatchQueue.main.async {
                    self.scanEventSink?([
                        "id": uuid,
                        "name": name,
                    ])
                }
            }
        }

        sdk.startScan()
        result(nil)
    }

    private func handleStopScan(result: @escaping FlutterResult) {
        SFPrintSDKUtils.shareInstance().stopScan()
        result(nil)
    }

    // MARK: - Connect

    private func handleConnect(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let deviceId = args["deviceId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "deviceId is required", details: nil))
            return
        }

        guard let peripheral = discoveredPeripherals[deviceId] else {
            result(FlutterError(code: "DEVICE_NOT_FOUND", message: "Device \(deviceId) not found. Did you scan first?", details: nil))
            return
        }

        // Stop scanning before connecting (best practice)
        SFPrintSDKUtils.shareInstance().stopScan()

        DispatchQueue.main.async {
            self.connectionEventSink?("connecting")
        }

        let sdk = SFPrintSDKUtils.shareInstance()

        // Set up connection callbacks right before connecting
        sdk.connectSuccessBlock = { [weak self] connectedPeripheral in
            guard let self = self else { return }
            NSLog("[SupvanPrinter] connectSuccessBlock fired for: %@", connectedPeripheral.name ?? "unknown")
            self.stopConnectionPolling()
            self.connectedPeripheral = connectedPeripheral
            DispatchQueue.main.async {
                self.connectionEventSink?("connected")
            }
        }

        sdk.connectFailBlock = { [weak self] in
            guard let self = self else { return }
            NSLog("[SupvanPrinter] connectFailBlock fired")
            self.stopConnectionPolling()
            self.connectedPeripheral = nil
            DispatchQueue.main.async {
                self.connectionEventSink?("disconnected")
            }
        }

        sdk.disconnectBlock = { [weak self] in
            guard let self = self else { return }
            NSLog("[SupvanPrinter] disconnectBlock fired")
            self.stopConnectionPolling()
            self.connectedPeripheral = nil
            DispatchQueue.main.async {
                self.connectionEventSink?("disconnected")
            }
        }

        // Initiate connection
        sdk.connectedBlueteeth(peripheral)

        // The original demo polls peripheral.state after a short delay
        // because the SDK callbacks may not always fire reliably.
        // We poll every 0.5s for up to 10s as a fallback.
        startConnectionPolling(peripheral: peripheral)

        result(true)
    }

    // MARK: - Connection Polling (fallback)

    private func startConnectionPolling(peripheral: CBPeripheral) {
        stopConnectionPolling()

        var elapsed: TimeInterval = 0
        let interval: TimeInterval = 0.5
        let timeout: TimeInterval = 10.0

        connectionPollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            elapsed += interval

            // Check if peripheral is now connected
            if peripheral.state == .connected || SFPrintSDKUtils.shareInstance().getDeviceStatus() {
                NSLog("[SupvanPrinter] Poll: device connected (elapsed: %.1fs)", elapsed)
                timer.invalidate()
                self.connectionPollTimer = nil
                self.connectedPeripheral = peripheral
                DispatchQueue.main.async {
                    self.connectionEventSink?("connected")
                }
                return
            }

            // Check for failure states
            if peripheral.state == .disconnected || peripheral.state == .disconnecting {
                NSLog("[SupvanPrinter] Poll: device disconnected/failed (elapsed: %.1fs, state: %d)", elapsed, peripheral.state.rawValue)
                timer.invalidate()
                self.connectionPollTimer = nil
                self.connectedPeripheral = nil
                DispatchQueue.main.async {
                    self.connectionEventSink?("disconnected")
                }
                return
            }

            // Timeout
            if elapsed >= timeout {
                NSLog("[SupvanPrinter] Poll: connection timeout after %.1fs", elapsed)
                timer.invalidate()
                self.connectionPollTimer = nil
                self.connectedPeripheral = nil
                DispatchQueue.main.async {
                    self.connectionEventSink?("disconnected")
                }
                return
            }

            NSLog("[SupvanPrinter] Poll: waiting... (elapsed: %.1fs, state: %d)", elapsed, peripheral.state.rawValue)
        }
    }

    private func stopConnectionPolling() {
        connectionPollTimer?.invalidate()
        connectionPollTimer = nil
    }

    // MARK: - Disconnect

    private func handleDisconnect(result: @escaping FlutterResult) {
        stopConnectionPolling()

        guard let peripheral = connectedPeripheral else {
            result(false)
            return
        }

        DispatchQueue.main.async {
            self.connectionEventSink?("disconnecting")
        }

        SFPrintSDKUtils.shareInstance().disConnectedBlueteeth(peripheral)
        connectedPeripheral = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.connectionEventSink?("disconnected")
        }

        result(true)
    }

    // MARK: - Status

    private func handleGetStatus(result: @escaping FlutterResult) {
        let connected = SFPrintSDKUtils.shareInstance().getDeviceStatus()
        // iOS SDK only returns connected/not-connected as status.
        // Map to: 0 = ready (connected), -1 = unknown (not connected)
        result(connected ? 0 : -1)
    }

    // MARK: - Print

    private func handlePrint(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Print arguments required", details: nil))
            return
        }

        guard SFPrintSDKUtils.shareInstance().getDeviceStatus() else {
            result(FlutterError(code: "NOT_CONNECTED", message: "Printer not connected", details: nil))
            return
        }

        let labelWidth = args["labelWidth"] as? Int ?? 40
        let labelHeight = args["labelHeight"] as? Int ?? 30
        let copies = args["copies"] as? Int ?? 1
        let density = args["density"] as? Int ?? 3
        let rotate = args["rotate"] as? Int ?? 0
        let horizontalOffset = args["horizontalOffset"] as? Int ?? 0
        let verticalOffset = args["verticalOffset"] as? Int ?? 0
        let paperType = args["paperType"] as? Int ?? 1
        let oneByOne = args["oneByOne"] as? Bool ?? true

        let setModel = SFPrintSetModel()
        setModel.isAuto = true
        setModel.width = Int32(labelWidth)
        setModel.length = Int32(labelHeight)
        // `copy` is an NSObject method in Swift, so use setValue:forKey:
        setModel.setValue(Int32(copies), forKey: "copy")
        setModel.deepness = Int32(density)
        // iOS SDK ratio: 1=0deg, 2=90deg, 3=180deg, 4=270deg
        // Dart rotate: 0=0deg, 1=90deg, 2=180deg, 3=270deg
        setModel.ratio = Int32(rotate + 1)
        setModel.left = Int32(horizontalOffset)
        setModel.top = Int32(verticalOffset)
        setModel.materialType = Int32(paperType)
        setModel.oneByone = Int32(oneByOne ? 1 : 0)

        // Build draw objects from pages
        var drawModels: [SFPrintDrawobjectModel] = []

        if let pages = args["pages"] as? [[String: Any]] {
            for page in pages {
                if let items = page["items"] as? [[String: Any]] {
                    for item in items {
                        let drawModel = SFPrintDrawobjectModel()

                        let format = item["format"] as? String ?? "TEXT"
                        let x = item["x"] as? Double ?? 0
                        let y = item["y"] as? Double ?? 0
                        let width = item["width"] as? Double ?? 10
                        let height = item["height"] as? Double ?? 5
                        let content = item["content"] as? String ?? ""
                        let fontSize = item["fontSize"] as? Int ?? 3
                        let fontStyle = item["fontStyle"] as? Int ?? 0
                        let fontName = item["fontName"] as? String ?? "HarmonyOS_Sans_SC"
                        let antiColor = item["antiColor"] as? Bool ?? false

                        drawModel.x = x
                        drawModel.y = y
                        drawModel.width = width
                        drawModel.height = height
                        drawModel.content = content
                        drawModel.fontSize = Int32(fontSize)
                        drawModel.fontStyle = Int32(fontStyle)
                        drawModel.fontName = fontName.isEmpty ? "HarmonyOS_Sans_SC" : fontName
                        drawModel.textColor = NSNumber(value: antiColor ? 1 : 0)
                        drawModel.format = format
                        drawModel.verAlignmentType = 0
                        drawModel.autoReturn = true

                        // Handle image type
                        if format == "IMAGE" {
                            if let imageBytes = item["imageBytes"] as? FlutterStandardTypedData {
                                if let image = UIImage(data: imageBytes.data) {
                                    drawModel.localImage = image
                                }
                            }
                        }

                        drawModels.append(drawModel)
                    }
                }
            }
        }

        setModel.printImgModels = drawModels

        SFPrintSDKUtils.shareInstance().doPrint(withPrint: setModel) { isSuccess, error, printNum, allLength in
            DispatchQueue.main.async {
                if isSuccess {
                    result(true)
                } else {
                    result(FlutterError(code: "PRINT_FAILED", message: error, details: nil))
                }
            }
        }
    }
}

// MARK: - Stream handler for scan events

private class ScanStreamHandler: NSObject, FlutterStreamHandler {
    weak var plugin: SupvanPrinterPlugin?

    init(plugin: SupvanPrinterPlugin) {
        self.plugin = plugin
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        plugin?.scanEventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        plugin?.scanEventSink = nil
        return nil
    }
}

// MARK: - Stream handler for connection events

private class ConnectionStreamHandler: NSObject, FlutterStreamHandler {
    weak var plugin: SupvanPrinterPlugin?

    init(plugin: SupvanPrinterPlugin) {
        self.plugin = plugin
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        plugin?.connectionEventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        plugin?.connectionEventSink = nil
        return nil
    }
}
