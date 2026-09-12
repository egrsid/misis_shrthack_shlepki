import AVFoundation
import Foundation
import Speech

/// Turns speech into text for the support chat.
///
/// The recognised text is never sent by itself — it lands in the chat's input
/// field for the client to read and fix first. That matters here specifically:
/// speech-to-text mangles exactly the values the triage rules ask for (a serial
/// number becomes "эс эн 44 81"), and a plausible-looking wrong serial reaching a
/// slot is the worst outcome this project has.
@MainActor
final class SpeechDictation: ObservableObject {
    /// Text recognised so far in the current session.
    @Published private(set) var transcript = ""
    @Published private(set) var isRecording = false
    @Published var errorMessage: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ru_RU"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var timeLimit: Task<Void, Never>?

    /// A recognition task is cut off by the system after about a minute; stopping
    /// first keeps the UI honest instead of looking frozen.
    private let maxDuration: Duration = .seconds(55)

    var isSupported: Bool {
        recognizer != nil
    }

    // MARK: Control

    func toggle() async {
        if isRecording {
            stop()
        } else {
            await start()
        }
    }

    func start() async {
        guard !isRecording else { return }
        errorMessage = nil
        transcript = ""

        guard let recognizer else {
            errorMessage = "Распознавание русской речи недоступно на этом устройстве"
            return
        }
        guard await requestPermissions() else { return }
        guard recognizer.isAvailable else {
            errorMessage = "Распознавание речи сейчас недоступно. Попробуйте позже или наберите текст"
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Prefer on-device recognition where the language pack allows it: nothing
        // leaves the phone, and it keeps working without a network.
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        self.request = request

        do {
            try configureSession()
            try startEngine(feeding: request)
        } catch {
            stop()
            errorMessage = "Не удалось включить микрофон: \(error.localizedDescription)"
            return
        }

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            // Only Sendable values cross back to the main actor: the result object
            // itself stays on the callback's thread.
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let failed = error != nil

            Task { @MainActor [weak self] in
                guard let self else { return }
                if let text { self.transcript = text }
                if isFinal || failed { self.stop() }
            }
        }

        isRecording = true
        timeLimit = Task { [weak self] in
            try? await Task.sleep(for: self?.maxDuration ?? .seconds(55))
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.stop() }
        }
    }

    func stop() {
        timeLimit?.cancel()
        timeLimit = nil

        if engine.isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        request?.endAudio()
        task?.finish()
        request = nil
        task = nil
        isRecording = false

        deactivateSession()
    }

    // MARK: Plumbing

    private func startEngine(feeding request: SFSpeechAudioBufferRecognitionRequest) throws {
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        // The tap runs on an audio thread; it only appends buffers, nothing else.
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        engine.prepare()
        try engine.start()
    }

    private func requestPermissions() async -> Bool {
        let speechGranted = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speechGranted else {
            errorMessage = "Разрешите распознавание речи в настройках, чтобы говорить вместо набора"
            return false
        }

        let micGranted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        guard micGranted else {
            errorMessage = "Разрешите доступ к микрофону в настройках, чтобы говорить вместо набора"
            return false
        }
        return true
    }

    // AVAudioSession is iOS-only; the rest of this file also type-checks on macOS.
    private func configureSession() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
    }

    private func deactivateSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }
}
