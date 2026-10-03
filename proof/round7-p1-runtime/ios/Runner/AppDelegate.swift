import AVFAudio
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, AVSpeechSynthesizerDelegate {
  private let speechChannelName = "sesliogren/native_speech"
  private let speechSynthesizer = AVSpeechSynthesizer()
  private var speechChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    speechSynthesizer.delegate = self
    let channel = FlutterMethodChannel(
      name: speechChannelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    speechChannel = channel

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "APP_UNAVAILABLE", message: "AppDelegate is unavailable.", details: nil))
        return
      }

      switch call.method {
      case "speak":
        guard
          let arguments = call.arguments as? [String: Any],
          let text = arguments["text"] as? String,
          !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
          result(FlutterError(code: "BAD_ARGUMENTS", message: "A non-empty text value is required.", details: nil))
          return
        }
        self.speak(text: text, result: result)

      case "stop":
        self.speechSynthesizer.stopSpeaking(at: .immediate)
        self.emitSpeaking(false, reason: "stopped")
        result(nil)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func speak(text: String, result: FlutterResult) {
    guard let voice = bestTurkishVoice() else {
      result(FlutterError(code: "TURKISH_VOICE_UNAVAILABLE", message: "No Turkish system voice is available.", details: nil))
      return
    }

    if speechSynthesizer.isSpeaking {
      speechSynthesizer.stopSpeaking(at: .immediate)
    }

    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = voice
    speechSynthesizer.speak(utterance)
    result(nil)
  }

  private func bestTurkishVoice() -> AVSpeechSynthesisVoice? {
    return AVSpeechSynthesisVoice.speechVoices()
      .filter { $0.language.lowercased().hasPrefix("tr") }
      .sorted {
        if $0.quality.rawValue != $1.quality.rawValue {
          return $0.quality.rawValue > $1.quality.rawValue
        }
        return $0.name < $1.name
      }
      .first
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
    emitSpeaking(true, reason: "started")
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    emitSpeaking(false, reason: "completed")
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
    emitSpeaking(false, reason: "cancelled")
  }

  private func emitSpeaking(_ speaking: Bool, reason: String) {
    DispatchQueue.main.async { [weak self] in
      self?.speechChannel?.invokeMethod(
        "speechState",
        arguments: [
          "speaking": speaking,
          "reason": reason,
        ]
      )
    }
  }
}
