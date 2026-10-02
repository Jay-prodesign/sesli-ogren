import AVFAudio
import CryptoKit
import Flutter
import Network
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let nativeTtsChannelName = "sesliogren/r7_native_tts_capture"
  private let pathMonitor = NWPathMonitor()
  private let pathMonitorQueue = DispatchQueue(label: "r7.native.tts.network")
  private var networkSatisfied: Bool?
  private var captureSynthesizer: AVSpeechSynthesizer?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    pathMonitor.pathUpdateHandler = { [weak self] path in
      DispatchQueue.main.async {
        self?.networkSatisfied = path.status == .satisfied
      }
    }
    pathMonitor.start(queue: pathMonitorQueue)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: nativeTtsChannelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "APP_DEALLOCATED", message: "AppDelegate unavailable.", details: nil))
        return
      }

      switch call.method {
      case "listTurkishVoices":
        result(self.listTurkishVoices())
      case "getNetworkState":
        result(self.networkState())
      case "getEvidenceDirectory":
        do {
          result(try self.evidenceDirectory().path)
        } catch {
          result(FlutterError(code: "EVIDENCE_DIR_FAILED", message: error.localizedDescription, details: nil))
        }
      case "synthesize":
        guard
          let arguments = call.arguments as? [String: Any],
          let text = arguments["text"] as? String,
          let item = arguments["item"] as? String,
          let voiceId = arguments["voiceId"] as? String,
          !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          !item.isEmpty,
          !voiceId.isEmpty
        else {
          result(FlutterError(code: "BAD_ARGUMENTS", message: "text, item and voiceId are required.", details: nil))
          return
        }
        self.synthesize(text: text, item: item, voiceId: voiceId, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func listTurkishVoices() -> [[String: Any]] {
    return AVSpeechSynthesisVoice.speechVoices()
      .filter { $0.language.lowercased().hasPrefix("tr") }
      .sorted {
        if $0.quality.rawValue != $1.quality.rawValue {
          return $0.quality.rawValue > $1.quality.rawValue
        }
        return $0.name < $1.name
      }
      .map { voice in
        [
          "platform": "ios",
          "physicalDevice": true,
          "id": voice.identifier,
          "name": voice.name,
          "locale": voice.language,
          "qualityTier": qualityLabel(voice.quality),
          "qualityRaw": voice.quality.rawValue,
          "networkRequired": false,
          "ttsEngineOrPackage": "AVSpeechSynthesizer",
          "providerModelVersion": "iOS-system-voice@\(UIDevice.current.systemVersion)",
          "deviceModel": hardwareIdentifier(),
          "osVersion": "iOS \(UIDevice.current.systemVersion)",
        ]
      }
  }

  private func networkState() -> [String: Any] {
    guard let satisfied = networkSatisfied else {
      return [
        "offline": false,
        "method": "iOS NWPathMonitor satisfied-path gate",
        "detail": "Network state is not ready yet; retry after the monitor reports.",
      ]
    }

    return [
      "offline": !satisfied,
      "method": "iOS NWPathMonitor satisfied-path gate",
      "detail": satisfied
        ? "A satisfied network path is still active."
        : "No satisfied network path is active.",
    ]
  }

  private func synthesize(
    text: String,
    item: String,
    voiceId: String,
    result: @escaping FlutterResult
  ) {
    guard networkSatisfied == false else {
      result(
        FlutterError(
          code: "NETWORK_NOT_OFFLINE",
          message: "Native benchmark requires network-disabled capture. \(networkState()["detail"] ?? "")",
          details: nil
        )
      )
      return
    }

    guard captureSynthesizer == nil else {
      result(FlutterError(code: "CAPTURE_BUSY", message: "A native synthesis is already running.", details: nil))
      return
    }

    guard let voice = AVSpeechSynthesisVoice(identifier: voiceId) else {
      result(FlutterError(code: "VOICE_NOT_FOUND", message: "Voice \(voiceId) is unavailable.", details: nil))
      return
    }
    guard voice.language.lowercased().hasPrefix("tr") else {
      result(FlutterError(code: "VOICE_NOT_TURKISH", message: "Selected voice is not Turkish.", details: nil))
      return
    }

    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = voice

    let startedAt = ISO8601DateFormatter.r7Fractional.string(from: Date())
    let startedNanos = DispatchTime.now().uptimeNanoseconds
    let safeVoice = voice.identifier.replacingOccurrences(
      of: "[^A-Za-z0-9._-]",
      with: "_",
      options: .regularExpression
    )

    let outputURL: URL
    do {
      outputURL = try evidenceDirectory().appendingPathComponent(
        "\(item.uppercased())-\(safeVoice)-\(Int(Date().timeIntervalSince1970 * 1000)).caf"
      )
    } catch {
      result(FlutterError(code: "EVIDENCE_DIR_FAILED", message: error.localizedDescription, details: nil))
      return
    }

    let synthesizer = AVSpeechSynthesizer()
    captureSynthesizer = synthesizer

    var audioFile: AVAudioFile?
    var totalFrames: AVAudioFramePosition = 0
    var sampleRate: Double = 0
    var finished = false

    func finish(_ error: Error? = nil) {
      guard !finished else { return }
      finished = true
      captureSynthesizer = nil

      if let error {
        result(FlutterError(code: "SYNTHESIS_FAILED", message: error.localizedDescription, details: nil))
        return
      }

      do {
        let audioData = try Data(contentsOf: outputURL)
        let elapsedNanos = DispatchTime.now().uptimeNanoseconds - startedNanos
        let durationMs: Int
        if sampleRate > 0 {
          durationMs = max(1, Int((Double(totalFrames) / sampleRate) * 1000.0))
        } else {
          durationMs = 1
        }

        result([
          "platform": "ios",
          "deviceModel": hardwareIdentifier(),
          "osVersion": "iOS \(UIDevice.current.systemVersion)",
          "ttsEngineOrPackage": "AVSpeechSynthesizer",
          "providerModelVersion": "iOS-system-voice@\(UIDevice.current.systemVersion)",
          "voiceId": voice.identifier,
          "locale": voice.language,
          "qualityTier": qualityLabel(voice.quality),
          "networkRequirement": "unknown_not_exposed",
          "captureMethod":
            "AVSpeechSynthesizer.write(toBufferCallback:) on physical device with NWPathMonitor offline gate",
          "format": "caf/linear-pcm-native-output",
          "durationMs": durationMs,
          "generationStartedAt": startedAt,
          "fullCompletionLatencyMs": max(1, Int(elapsedNanos / 1_000_000)),
          "inputTextSha256": sha256(Data(text.utf8)),
          "inputCharacterCount": text.unicodeScalars.count,
          "inputBytes": text.lengthOfBytes(using: .utf8),
          "audioPath": outputURL.path,
          "audioSha256": sha256(audioData),
        ])
      } catch {
        result(FlutterError(code: "CAPTURE_FINALIZE_FAILED", message: error.localizedDescription, details: nil))
      }
    }

    synthesizer.write(utterance) { buffer in
      guard let pcm = buffer as? AVAudioPCMBuffer else {
        finish(NativeCaptureError.unexpectedBuffer)
        return
      }

      if pcm.frameLength == 0 {
        finish()
        return
      }

      do {
        if audioFile == nil {
          sampleRate = pcm.format.sampleRate
          audioFile = try AVAudioFile(
            forWriting: outputURL,
            settings: pcm.format.settings
          )
        }
        try audioFile?.write(from: pcm)
        totalFrames += AVAudioFramePosition(pcm.frameLength)
      } catch {
        finish(error)
      }
    }
  }

  private func evidenceDirectory() throws -> URL {
    let root = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first!
    let directory = root.appendingPathComponent("r7-native-tts", isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    return directory
  }

  private var isPhysicalDevice: Bool {\n#if targetEnvironment(simulator)\n    return false\n#else\n    return true\n#endif\n  }\n\n  private func qualityLabel(_ quality: AVSpeechSynthesisVoiceQuality) -> String {
    switch quality {
    case .premium:
      return "premium"
    case .enhanced:
      return "enhanced"
    default:
      return "default"
    }
  }

  private func hardwareIdentifier() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    let mirror = Mirror(reflecting: systemInfo.machine)
    return mirror.children.reduce(into: "") { identifier, element in
      guard let value = element.value as? Int8, value != 0 else { return }
      identifier.append(Character(UnicodeScalar(UInt8(value))))
    }
  }

  private func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }

  override func applicationWillTerminate(_ application: UIApplication) {
    pathMonitor.cancel()
    super.applicationWillTerminate(application)
  }
}

private enum NativeCaptureError: LocalizedError {
  case unexpectedBuffer

  var errorDescription: String? {
    switch self {
    case .unexpectedBuffer:
      return "AVSpeechSynthesizer returned a non-PCM buffer."
    }
  }
}

private extension ISO8601DateFormatter {
  static let r7Fractional: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()
}
