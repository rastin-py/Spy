import AVFoundation
import Flutter
import UIKit

/// Everything Spy asks of the phone, in one place.
///
/// No third-party native code: the app promises it never touches the network,
/// and owning this handful of calls is the cheapest way to keep that honest.
final class SecureScreen {
    static let shared = SecureScreen()

    private var isArmed = false
    private var cover: UIView?
    private var tick: AVAudioPlayer?
    private var bell: AVAudioPlayer?
    private var sessionReady = false

    private init() {}

    // MARK: - The app-switcher snapshot

    /// iOS has no `FLAG_SECURE`. What it does have is a snapshot taken the
    /// moment the scene resigns active - which is exactly when somebody has
    /// pulled down Control Centre or taken a screenshot while a card is open.
    /// So the window gets an opaque cover before that snapshot is taken.
    ///
    /// Armed on Handoff and Reveal only. Everywhere else the app is perfectly
    /// screenshottable, which is the point.
    func setSecure(_ secure: Bool) {
        isArmed = secure
        if !secure { uncover() }
    }

    func coverIfArmed(in window: UIWindow?) {
        guard isArmed, cover == nil, let window else { return }
        // The same near-black as the handoff screen, in both themes - a
        // bone-white cover in a dim room is a flashbulb in six faces.
        let view = UIView(frame: window.bounds)
        view.backgroundColor = UIColor(red: 5 / 255, green: 7 / 255, blue: 10 / 255, alpha: 1)
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(view)
        cover = view
    }

    func uncover() {
        cover?.removeFromSuperview()
        cover = nil
    }

    // MARK: - Audio

    /// Ambient and mixing with others: the tick respects the ringer switch and
    /// leaves the user's music alone.
    private func prepareSession() {
        guard !sessionReady else { return }
        sessionReady = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func player(forAsset asset: String, looping: Bool) -> AVAudioPlayer? {
        // Flutter assets live inside the app bundle under flutter_assets/.
        guard let path = Bundle.main.path(forResource: "flutter_assets/\(asset)", ofType: nil),
              let player = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
        else {
            // A missing sample is not worth a broken round.
            return nil
        }
        player.numberOfLoops = looping ? -1 : 0
        player.volume = 0.55
        player.prepareToPlay()
        return player
    }

    func startTicking() {
        prepareSession()
        if tick == nil { tick = player(forAsset: "assets/audio/tick.wav", looping: true) }
        tick?.play()
    }

    func stopTicking() {
        tick?.stop()
        tick?.currentTime = 0
    }

    /// One strike at zero. Never repeated.
    func strikeBell() {
        prepareSession()
        if bell == nil { bell = player(forAsset: "assets/audio/bell.wav", looping: false) }
        bell?.currentTime = 0
        bell?.play()
    }

    // MARK: - Channel

    func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "spy/platform", binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else { return result(nil) }
            let args = call.arguments as? [String: Any]

            switch call.method {
            case "setSecure":
                self.setSecure(args?["secure"] as? Bool ?? false)
                result(nil)

            case "isMuted":
                // There is no public API for the ringer switch. Rather than
                // guess, iOS says nothing and the notice stays off there.
                result(nil)

            case "setKeepAwake":
                UIApplication.shared.isIdleTimerDisabled = args?["awake"] as? Bool ?? false
                result(nil)

            case "storageDirectory":
                // Application Support is not created for you, unlike Documents.
                let fm = FileManager.default
                if let url = fm.urls(for: .applicationSupportDirectory,
                                     in: .userDomainMask).first {
                    try? fm.createDirectory(at: url, withIntermediateDirectories: true)
                    result(url.path)
                } else {
                    result(nil)
                }

            case "openUrl":
                // Handed to the system, never opened in-app. Spy does not
                // install anything and does not embed a browser.
                guard let raw = args?["url"] as? String,
                      let url = URL(string: raw),
                      UIApplication.shared.canOpenURL(url) else {
                    result(false)
                    return
                }
                UIApplication.shared.open(url, options: [:]) { opened in
                    result(opened)
                }

            case "startTicking":
                self.startTicking()
                result(nil)

            case "stopTicking":
                self.stopTicking()
                result(nil)

            case "strikeBell":
                self.strikeBell()
                result(nil)

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}
