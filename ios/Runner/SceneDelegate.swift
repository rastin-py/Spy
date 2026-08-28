import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  /// The snapshot is taken around the moment the scene resigns active, so the
  /// cover has to go on here rather than in `sceneDidEnterBackground` - by then
  /// the picture has already been taken.
  override func sceneWillResignActive(_ scene: UIScene) {
    super.sceneWillResignActive(scene)
    SecureScreen.shared.coverIfArmed(in: (scene as? UIWindowScene)?.keyWindow)
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    SecureScreen.shared.uncover()
  }
}
