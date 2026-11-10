import AppKit
import AVFoundation
import CoreImage
import CoreML
import SwiftUI
import UniformTypeIdentifiers
import Vision

@main
struct PhoneFocusApp: App {
    @StateObject private var monitor = PhoneMonitor()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView(monitor: monitor)
                .frame(minWidth: 620, minHeight: 760)
        }
        .windowResizability(.contentSize)

        MenuBarExtra("PhoneFocus", systemImage: monitor.isMonitoring ? "iphone.radiowaves.left.and.right" : "iphone.slash") {
            Text(monitor.status)
            Divider()
            Button("Open PhoneFocus") {
                openWindow(id: "main")
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
            Button(monitor.primaryButtonTitle) {
                monitor.togglePrimary()
            }
            Button(monitor.followCodex ? "Use manual mode" : "Follow Codex activity") {
                monitor.setFollowCodex(!monitor.followCodex)
            }
            if monitor.isAlerting {
                Button("Snooze for 5 minutes") { monitor.snooze() }
            }
            Divider()
            Button("Quit PhoneFocus") { NSApplication.shared.terminate(nil) }
        }
    }
}

struct ContentView: View {
    @ObservedObject var monitor: PhoneMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(.indigo.gradient, in: RoundedRectangle(cornerRadius: 15))
                VStack(alignment: .leading, spacing: 3) {
                    Text("PhoneFocus").font(.system(size: 27, weight: .bold))
                    Text("A gentle nudge when your phone takes over")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Circle()
                    .fill(monitor.isMonitoring ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                    .accessibilityLabel(monitor.isMonitoring ? "Monitoring on" : "Monitoring off")
            }

            ZStack {
                CameraPreview(session: monitor.session)
                    .opacity(monitor.isMonitoring ? 1 : 0)
                if !monitor.isMonitoring {
                    VStack(spacing: 8) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 36))
                        Text("Camera is off")
                            .font(.headline)
                    }
                    .foregroundStyle(.secondary)
                }
                VStack {
                    Spacer()
                    HStack {
                        Label(monitor.status, systemImage: monitor.isAlerting ? "speaker.wave.3.fill" : "viewfinder")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(.regularMaterial, in: Capsule())
                        Spacer()
                    }
                    .padding(12)
                }
            }
            .frame(height: 220)
            .background(Color.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
            .clipShape(RoundedRectangle(cornerRadius: 18))

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Follow local Codex chats", isOn: Binding(
                    get: { monitor.followCodex },
                    set: { monitor.setFollowCodex($0) }
                ))
                .font(.headline)
                Text(monitor.codexStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Camera").font(.headline)
                    Spacer()
                    Button("Refresh") { monitor.refreshCameras() }
                }
                Picker("Camera", selection: Binding(
                    get: { monitor.cameraChoice },
                    set: { monitor.setCameraChoice($0) }
                )) {
                    Text("Prefer iPhone camera").tag("preferIPhone")
                    Text("System preferred").tag("system")
                    ForEach(monitor.availableCameras) { camera in
                        Text(camera.name).tag(camera.id)
                    }
                }
                .labelsHidden()
                Text(monitor.activeCameraName)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

            HStack(spacing: 14) {
                Button {
                    monitor.togglePrimary()
                } label: {
                    Label(monitor.primaryButtonTitle,
                          systemImage: (monitor.isMonitoring || (monitor.followCodex && !monitor.autoPaused)) ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if monitor.isAlerting {
                    Button("Snooze 5 minutes") { monitor.snooze() }
                        .controlSize(.large)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Alert sound").font(.headline)
                    Spacer()
                    Button("Choose audio…") { monitor.chooseAudio() }
                }
                HStack {
                    Image(systemName: "waveform")
                        .foregroundStyle(.indigo)
                    Text(monitor.audioName)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Preview") { monitor.previewAudio() }
                    if monitor.hasCustomAudio {
                        Button("Use default") { monitor.useDefaultAudio() }
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

            Text("A phone near you must stay visible for more than 5 seconds before the alert repeats. Snoozing mutes it for 5 minutes; monitoring continues. Video stays on this Mac and is never recorded. For an iPhone’s Ultra Wide lens, choose it in macOS Video Effects.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(24)
    }
}

struct CameraOption: Identifiable {
    let id: String
    let name: String
}

struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        return view
    }

    func updateNSView(_ view: PreviewView, context: Context) {
        view.previewLayer.session = session
    }
}

final class PreviewView: NSView {
    override func makeBackingLayer() -> CALayer { AVCaptureVideoPreviewLayer() }
    override var wantsUpdateLayer: Bool { true }
    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        previewLayer.videoGravity = .resizeAspect
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

struct PhoneUseTracker {
    private(set) var firstSeen: TimeInterval?
    private(set) var lastSeen: TimeInterval?
    static let triggerDuration: TimeInterval = 5
    private static let missingFrameGrace: TimeInterval = 0.85

    mutating func observe(phoneNearPerson: Bool, at time: TimeInterval) {
        if phoneNearPerson {
            if lastSeen == nil || time - lastSeen! > Self.missingFrameGrace {
                firstSeen = time
            }
            lastSeen = time
        } else if let lastSeen, time - lastSeen > Self.missingFrameGrace {
            reset()
        }
    }

    mutating func expire(at time: TimeInterval) {
        if let lastSeen, time - lastSeen > Self.missingFrameGrace { reset() }
    }

    func elapsed(at time: TimeInterval) -> TimeInterval {
        firstSeen.map { max(0, time - $0) } ?? 0
    }
    func isTriggered(at time: TimeInterval) -> Bool {
        guard let firstSeen, let lastSeen else { return false }
        return time - firstSeen > Self.triggerDuration && time - lastSeen <= Self.missingFrameGrace
    }

    mutating func reset() {
        firstSeen = nil
        lastSeen = nil
    }
}

final class PhoneMonitor: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate, NSSpeechSynthesizerDelegate {
    @Published private(set) var isMonitoring = false
    @Published private(set) var isAlerting = false
    @Published private(set) var status = "Monitoring off"
    @Published private(set) var audioName = "Default voice reminder"
    @Published private(set) var hasCustomAudio = false
    @Published private(set) var availableCameras: [CameraOption] = []
    @Published private(set) var cameraChoice = "preferIPhone"
    @Published private(set) var activeCameraName = "Camera is off"
    @Published private(set) var followCodex = true
    @Published private(set) var autoPaused = false
    @Published private(set) var codexStatus = "Waiting for a local Codex prompt"

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "PhoneFocus.capture")
    private let visionQueue = DispatchQueue(label: "PhoneFocus.vision")
    private var detector: VNCoreMLModel?
    private lazy var imageContext = CIContext(options: [.useSoftwareRenderer: true])
    private var modelInput: CVPixelBuffer?
    private var lastAnalysis: TimeInterval = 0
    private var tracker = PhoneUseTracker()
    private var snoozeUntil: TimeInterval?
    private var player: AVAudioPlayer?
    private var previewPlayer: AVAudioPlayer?
    private let speech = NSSpeechSynthesizer()
    private let previewSpeech = NSSpeechSynthesizer()
    private let reminder = "Please put your phone away and get back to what matters."
    private var tickTimer: Timer?
    private var customAudioURL: URL?
    private var configured = false
    private var captureEnabled = false // Read and written only on visionQueue.
    private var isReady = false
    private var monitoringToken = 0
    private var lastCodexPoll: TimeInterval = 0
    private var codexActive = false

    var primaryButtonTitle: String {
        if followCodex { return autoPaused ? "Resume automatic monitoring" : "Pause automatic monitoring" }
        return isMonitoring ? "Stop monitoring" : "Start monitoring"
    }

    override init() {
        super.init()
        speech.delegate = self
        followCodex = UserDefaults.standard.object(forKey: "FollowCodex") as? Bool ?? true
        cameraChoice = UserDefaults.standard.string(forKey: "CameraChoice") ?? "preferIPhone"
        refreshCameras()
        if let path = UserDefaults.standard.string(forKey: "AlertAudioPath"),
           FileManager.default.fileExists(atPath: path) {
            customAudioURL = URL(fileURLWithPath: path)
            audioName = customAudioURL!.lastPathComponent
            hasCustomAudio = true
        }
        tickTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick()
        }
        pollCodexActivity(force: true)
    }

    func togglePrimary() {
        if followCodex {
            autoPaused.toggle()
            pollCodexActivity(force: true)
        } else {
            setMonitoring(!isMonitoring)
        }
    }

    func setFollowCodex(_ on: Bool) {
        guard followCodex != on else { return }
        followCodex = on
        autoPaused = false
        UserDefaults.standard.set(on, forKey: "FollowCodex")
        setMonitoring(false)
        pollCodexActivity(force: true)
    }

    private func pollCodexActivity(force: Bool = false) {
        let now = CACurrentMediaTime()
        guard force || now - lastCodexPoll >= 0.5 else { return }
        lastCodexPoll = now
        let directory = "/private/tmp/phonefocus-codex-\(getuid())"
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? []
        let active = files.contains { file in
            guard file.hasSuffix(".flag"),
                  let attributes = try? FileManager.default.attributesOfItem(
                    atPath: directory + "/" + file),
                  let modified = attributes[.modificationDate] as? Date else { return false }
            return Date().timeIntervalSince(modified) < 60 * 60
        }
        let changed = active != codexActive
        codexActive = active
        codexStatus = autoPaused ? "Automatic monitoring paused" :
            (active ? "Codex is responding" : "Waiting for a local Codex prompt")
        guard followCodex, changed || force else { return }
        if autoPaused || !active {
            if isMonitoring { setMonitoring(false) }
            status = autoPaused ? "Automatic monitoring paused" : "Waiting for Codex"
        } else if !isMonitoring {
            setMonitoring(true)
        }
    }

    func setMonitoring(_ on: Bool) {
        if !on {
            monitoringToken += 1
            isMonitoring = false
            isReady = false
            status = "Monitoring off"
            activeCameraName = "Camera is off"
            tracker.reset()
            snoozeUntil = nil
            stopAlert()
            visionQueue.async { self.captureEnabled = false }
            sessionQueue.async { if self.session.isRunning { self.session.stopRunning() } }
            return
        }
        guard !isMonitoring else { return }
        monitoringToken += 1
        let token = monitoringToken
        isMonitoring = true
        status = "Checking camera permission…"
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: startDetectorAndCamera(token: token)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self, self.monitoringToken == token, self.isMonitoring else { return }
                    if granted { self.startDetectorAndCamera(token: token) }
                    else {
                        self.isMonitoring = false
                        self.status = "Camera access denied. Enable it in System Settings."
                    }
                }
            }
        case .denied, .restricted:
            isMonitoring = false
            status = "Camera access denied. Enable it in System Settings."
        @unknown default:
            isMonitoring = false
            status = "Camera permission is unavailable."
        }
    }

    private func startDetectorAndCamera(token: Int) {
        refreshCameras()
        status = "Loading phone detector…"
        visionQueue.async {
            do {
                if self.detector == nil { self.detector = try self.loadDetector() }
                self.captureEnabled = true
                DispatchQueue.main.async {
                    guard self.monitoringToken == token, self.isMonitoring else { return }
                    let choice = self.cameraChoice
                    self.sessionQueue.async {
                        do {
                            let name = try self.configureCapture(choice: choice)
                            if !self.session.isRunning { self.session.startRunning() }
                            DispatchQueue.main.async {
                                if self.monitoringToken == token, self.isMonitoring {
                                    self.isReady = true
                                    self.status = "Looking for a phone"
                                    self.activeCameraName = "Using \(name)"
                                }
                            }
                        } catch {
                            DispatchQueue.main.async {
                                if self.monitoringToken == token {
                                    self.isMonitoring = false
                                    self.status = "Camera error: \(error.localizedDescription)"
                                }
                            }
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    if self.monitoringToken == token {
                        self.isMonitoring = false
                        self.status = "Detector error: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func loadDetector() throws -> VNCoreMLModel {
        guard let source = Bundle.main.url(forResource: "YOLOv3FP16", withExtension: "mlmodel") else {
            throw NSError(domain: "PhoneFocus", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "The phone detection model is missing."])
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PhoneFocus", isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let cached = support.appendingPathComponent("YOLOv3FP16.mlmodelc", isDirectory: true)
        if !FileManager.default.fileExists(atPath: cached.path) {
            let compiled = try MLModel.compileModel(at: source)
            try FileManager.default.moveItem(at: compiled, to: cached)
        }
        // The Apple model can fail to load on some Macs when Core ML selects the Neural Engine.
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .cpuAndGPU
        let model = try MLModel(contentsOf: cached, configuration: configuration)
        return try VNCoreMLModel(for: model)
    }

    private func discoveredCameras() -> [AVCaptureDevice] {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video, position: .unspecified)
        let deskViewIDs = Set(discovery.devices.compactMap { $0.companionDeskViewCamera?.uniqueID })
        return discovery.devices.filter { !deskViewIDs.contains($0.uniqueID) }
    }

    func refreshCameras() {
        let cameras = discoveredCameras()
        availableCameras = cameras.map {
            CameraOption(id: $0.uniqueID,
                         name: $0.localizedName + ($0.isContinuityCamera ? " (iPhone)" : ""))
        }
        if cameraChoice != "preferIPhone", cameraChoice != "system",
           !cameras.contains(where: { $0.uniqueID == cameraChoice }) {
            cameraChoice = "preferIPhone"
            UserDefaults.standard.set(cameraChoice, forKey: "CameraChoice")
        }
        if isMonitoring, isReady { switchCamera() }
    }

    func setCameraChoice(_ choice: String) {
        guard cameraChoice != choice else { return }
        cameraChoice = choice
        UserDefaults.standard.set(choice, forKey: "CameraChoice")
        if isMonitoring, isReady { switchCamera() }
    }

    private func switchCamera() {
        let choice = cameraChoice
        let token = monitoringToken
        isReady = false
        tracker.reset()
        stopAlert()
        status = "Switching camera…"
        sessionQueue.async {
            do {
                let name = try self.configureCapture(choice: choice)
                DispatchQueue.main.async {
                    if self.monitoringToken == token, self.isMonitoring {
                        self.isReady = true
                        self.activeCameraName = "Using \(name)"
                        self.status = "Looking for a phone"
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    if self.monitoringToken == token {
                        self.isReady = true
                        self.status = "Camera error: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func configureCapture(choice: String) throws -> String {
        let cameras = discoveredCameras()
        let camera: AVCaptureDevice?
        switch choice {
        case "preferIPhone":
            camera = cameras.first(where: { $0.isContinuityCamera })
                ?? AVCaptureDevice.systemPreferredCamera
                ?? cameras.first
                ?? AVCaptureDevice.default(for: .video)
        case "system":
            camera = AVCaptureDevice.systemPreferredCamera
                ?? cameras.first
                ?? AVCaptureDevice.default(for: .video)
        default:
            camera = cameras.first(where: { $0.uniqueID == choice })
                ?? AVCaptureDevice.systemPreferredCamera
                ?? cameras.first
                ?? AVCaptureDevice.default(for: .video)
        }
        guard let camera else {
            throw NSError(domain: "PhoneFocus", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "No camera is available."])
        }
        if configured,
           let current = session.inputs.compactMap({ $0 as? AVCaptureDeviceInput }).first,
           current.device.uniqueID == camera.uniqueID {
            return camera.localizedName
        }
        let input = try AVCaptureDeviceInput(device: camera)
        session.beginConfiguration()
        session.sessionPreset = .medium
        let oldInput = session.inputs.compactMap { $0 as? AVCaptureDeviceInput }.first
        if let oldInput { session.removeInput(oldInput) }
        guard session.canAddInput(input) else {
            if let oldInput, session.canAddInput(oldInput) { session.addInput(oldInput) }
            session.commitConfiguration()
            throw NSError(domain: "PhoneFocus", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Could not configure the camera."])
        }
        session.addInput(input)
        if !configured {
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: visionQueue)
            guard session.canAddOutput(output) else {
                session.removeInput(input)
                if let oldInput, session.canAddInput(oldInput) { session.addInput(oldInput) }
                session.commitConfiguration()
                throw NSError(domain: "PhoneFocus", code: 3,
                              userInfo: [NSLocalizedDescriptionKey: "Could not configure the camera."])
            }
            session.addOutput(output)
        }
        session.commitConfiguration()
        configured = true
        return camera.localizedName
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard captureEnabled, let detector, let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let now = CACurrentMediaTime()
        guard now - lastAnalysis >= 0.25 else { return }
        lastAnalysis = now

        do {
            let prepared = try prepareModelInput(from: pixels)
            let request = VNCoreMLRequest(model: detector)
            request.imageCropAndScaleOption = .scaleFill
            try VNImageRequestHandler(cvPixelBuffer: prepared, orientation: .up).perform([request])
            let objects = (request.results as? [VNRecognizedObjectObservation]) ?? []
            let persons = objects.filter {
                $0.labels.first?.identifier.lowercased() == "person" && $0.confidence >= 0.30
            }
            // The closest person is usually the largest one in a webcam frame.
            let primaryPerson = persons.max {
                $0.boundingBox.width * $0.boundingBox.height <
                    $1.boundingBox.width * $1.boundingBox.height
            }
            let phones = objects.filter {
                let name = $0.labels.first?.identifier.lowercased() ?? ""
                return (name == "cell phone" || name == "mobile phone") && $0.confidence >= 0.28
            }
            var nearHand = false
            if primaryPerson == nil, !phones.isEmpty {
                let handRequest = VNDetectHumanHandPoseRequest()
                handRequest.maximumHandCount = 2
                try VNImageRequestHandler(cvPixelBuffer: prepared, orientation: .up)
                    .perform([handRequest])
                nearHand = (handRequest.results ?? []).contains { hand in
                    guard let joints = try? hand.recognizedPoints(.all) else { return false }
                    return phones.contains { phone in
                        let region = phone.boundingBox.insetBy(dx: -0.10, dy: -0.10)
                        return joints.values.contains { point in
                            point.confidence >= 0.3 && region.contains(point.location)
                        }
                    }
                }
            }
            let nearPerson = phones.contains { phone in
                guard let primaryPerson else { return nearHand }
                let center = CGPoint(x: phone.boundingBox.midX, y: phone.boundingBox.midY)
                return primaryPerson.boundingBox.insetBy(dx: -0.18, dy: -0.18)
                    .contains(center)
            }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isMonitoring else { return }
                self.tracker.observe(phoneNearPerson: nearPerson, at: now)
                self.tick()
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.status = "Detection error: \(error.localizedDescription)"
            }
        }
    }

    // Vision's automatic image transform can fail for non-square frames on some Macs.
    // Prepare a square, letterboxed BGRA buffer so the model receives the same input every time.
    private func prepareModelInput(from source: CVPixelBuffer) throws -> CVPixelBuffer {
        let size = 416
        if modelInput == nil {
            var buffer: CVPixelBuffer?
            let result = CVPixelBufferCreate(kCFAllocatorDefault, size, size,
                                             kCVPixelFormatType_32BGRA, nil, &buffer)
            guard result == kCVReturnSuccess, let buffer else {
                throw NSError(domain: "PhoneFocus", code: 4,
                              userInfo: [NSLocalizedDescriptionKey: "Could not allocate a detector frame."])
            }
            modelInput = buffer
        }
        guard let target = modelInput else { fatalError("Model input was not allocated") }
        let image = CIImage(cvPixelBuffer: source)
        guard let cgImage = imageContext.createCGImage(image, from: image.extent) else {
            throw NSError(domain: "PhoneFocus", code: 5,
                          userInfo: [NSLocalizedDescriptionKey: "Could not read a camera frame."])
        }
        CVPixelBufferLockBaseAddress(target, [])
        defer { CVPixelBufferUnlockBaseAddress(target, []) }
        guard let drawing = CGContext(data: CVPixelBufferGetBaseAddress(target),
                                      width: size, height: size, bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(target),
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue |
                                          CGBitmapInfo.byteOrder32Little.rawValue) else {
            throw NSError(domain: "PhoneFocus", code: 6,
                          userInfo: [NSLocalizedDescriptionKey: "Could not prepare a camera frame."])
        }
        drawing.setFillColor(CGColor(gray: 0.5, alpha: 1))
        drawing.fill(CGRect(x: 0, y: 0, width: size, height: size))
        let scale = min(CGFloat(size) / CGFloat(cgImage.width),
                        CGFloat(size) / CGFloat(cgImage.height))
        let width = CGFloat(cgImage.width) * scale
        let height = CGFloat(cgImage.height) * scale
        drawing.draw(cgImage, in: CGRect(x: (CGFloat(size) - width) / 2,
                                         y: (CGFloat(size) - height) / 2,
                                         width: width, height: height))
        return target
    }

    private func tick() {
        pollCodexActivity()
        guard isMonitoring, isReady else { return }
        let now = CACurrentMediaTime()
        tracker.expire(at: now)
        if let snoozeUntil, now < snoozeUntil {
            stopAlert()
            status = "Snoozed · \(Int(ceil(snoozeUntil - now)))s remaining"
            return
        }
        if snoozeUntil != nil { snoozeUntil = nil }
        if tracker.isTriggered(at: now) {
            startAlert()
            if isAlerting { status = "Phone in use · alert playing" }
        } else {
            stopAlert()
            if tracker.firstSeen != nil {
                status = String(format: "Phone detected · %.1f / 5 seconds", min(tracker.elapsed(at: now), 5))
            } else {
                status = "Looking for a phone"
            }
        }
    }

    func snooze() {
        guard isAlerting else { return }
        snoozeUntil = CACurrentMediaTime() + 5 * 60
        stopAlert()
        tick()
    }

    private func startAlert() {
        guard !isAlerting else { return }
        previewPlayer?.stop()
        previewSpeech.stopSpeaking()
        if let customAudioURL {
            playLoopingFile(customAudioURL)
        } else if speech.startSpeaking(reminder) {
            isAlerting = true
        } else if let chime = Bundle.main.url(forResource: "FallbackChime", withExtension: "aiff") {
            playLoopingFile(chime)
        }
    }

    private func playLoopingFile(_ url: URL) {
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1
            player?.prepareToPlay()
            isAlerting = player?.play() ?? false
        } catch {
            status = "Could not play alert: \(error.localizedDescription)"
        }
    }

    private func stopAlert() {
        guard isAlerting else { return }
        isAlerting = false
        speech.stopSpeaking()
        player?.stop()
        player = nil
    }

    func speechSynthesizer(_ sender: NSSpeechSynthesizer, didFinishSpeaking finishedSpeaking: Bool) {
        guard sender === speech, finishedSpeaking, isAlerting, customAudioURL == nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self, self.isAlerting, self.customAudioURL == nil else { return }
            if !self.speech.startSpeaking(self.reminder) {
                self.stopAlert()
                if let chime = Bundle.main.url(forResource: "FallbackChime", withExtension: "aiff") {
                    self.playLoopingFile(chime)
                }
            }
        }
    }

    func chooseAudio() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose the sound that repeats when phone use continues."
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let candidate = try AVAudioPlayer(contentsOf: url)
                candidate.prepareToPlay()
                customAudioURL = url
                audioName = url.lastPathComponent
                hasCustomAudio = true
                UserDefaults.standard.set(url.path, forKey: "AlertAudioPath")
                if isAlerting { stopAlert(); startAlert() }
            } catch {
                status = "Unsupported audio file: \(error.localizedDescription)"
            }
        }
    }

    func useDefaultAudio() {
        customAudioURL = nil
        audioName = "Default voice reminder"
        hasCustomAudio = false
        UserDefaults.standard.removeObject(forKey: "AlertAudioPath")
        if isAlerting { stopAlert(); startAlert() }
    }

    func previewAudio() {
        previewSpeech.stopSpeaking()
        if customAudioURL == nil {
            if !previewSpeech.startSpeaking(reminder),
               let chime = Bundle.main.url(forResource: "FallbackChime", withExtension: "aiff") {
                playPreviewFile(chime)
            }
            return
        }
        guard let url = customAudioURL else { return }
        playPreviewFile(url)
    }

    private func playPreviewFile(_ url: URL) {
        do {
            previewPlayer?.stop()
            previewPlayer = try AVAudioPlayer(contentsOf: url)
            previewPlayer?.numberOfLoops = 0
            previewPlayer?.play()
        } catch {
            status = "Could not preview audio: \(error.localizedDescription)"
        }
    }
}
