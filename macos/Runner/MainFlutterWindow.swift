import Cocoa
import FlutterMacOS

/// Repro driver for flutter/flutter#185394.
///
/// REPRO_MODE=flip (default): every 2.5 s shrink the content by 1 px and
/// restore it, synchronously back to back. Each `setContentSize` goes through
/// `FlutterView.setFrameSize` -> `ResizeSynchronizer`, which returns only after a
/// frame of the new size has been committed, so frame sizes go A -> B -> A with
/// exactly one frame at B. The restore is issued immediately after the B frame
/// is committed, while the window server still holds the previous A surface, so
/// the engine allocates a fresh A surface and, when it is presented, the B
/// surface is returned into a cache whose head is the held A surface. The cache
/// now holds two sizes; the next A frame is handed the B surface.
///
/// REPRO_MODE=fullscreen: toggle native fullscreen every 2.5 s (the trigger seen
/// in the field; sizes are monotonic during the animation, so it is far less
/// deterministic).
class MainFlutterWindow: NSWindow {
  var timer: Timer?
  var iterations = 0

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    let mode = ProcessInfo.processInfo.environment["REPRO_MODE"] ?? "flip"
    timer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
      guard let self = self else { return }
      self.iterations += 1
      if mode == "fullscreen" {
        NSLog("REPRO toggleFullScreen #%d", self.iterations)
        self.toggleFullScreen(nil)
        return
      }
      let size = self.contentView!.frame.size
      let shrunk = NSSize(width: size.width - 1, height: size.height - 1)
      NSLog("REPRO flip #%d: %.0fx%.0f -> %.0fx%.0f -> back", self.iterations,
            size.width, size.height, shrunk.width, shrunk.height)
      self.setContentSize(shrunk)
      self.setContentSize(size)
    }
  }
}
