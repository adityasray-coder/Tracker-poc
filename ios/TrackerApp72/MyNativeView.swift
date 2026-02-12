/**
 * SwiftUI view that fires a callback when it appears, used with UIHostingController.
 */

import SwiftUI
import UIKit

/// SwiftUI view that calls `onAppear` when it appears on screen.
struct MyNativeSwiftUIView: View {
  var onAppear: () -> Void

  var body: some View {
    Color.clear
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .onAppear(perform: onAppear)
  }
}

/// Bridge: creates a UIView that hosts the SwiftUI view and calls the block when .onAppear fires.
@objc(MyNativeViewBridge)
public class MyNativeViewBridge: NSObject {
  /// Attaches the SwiftUI view to the container and sets the onAppear callback.
  @objc public static func attachSwiftUI(to containerView: UIView, onAppearBlock: @escaping () -> Void) {
    let swiftUIView = MyNativeSwiftUIView(onAppear: onAppearBlock)
    let hosting = UIHostingController(rootView: swiftUIView)
    hosting.view.backgroundColor = .clear
    hosting.view.translatesAutoresizingMaskIntoConstraints = false
    hosting.view.isUserInteractionEnabled = false

    containerView.addSubview(hosting.view)
    NSLayoutConstraint.activate([
      hosting.view.topAnchor.constraint(equalTo: containerView.topAnchor),
      hosting.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
      hosting.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
      hosting.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
    ])
    objc_setAssociatedObject(
      containerView,
      &AssociatedKeys.hosting,
      hosting,
      .OBJC_ASSOCIATION_RETAIN_NONATOMIC
    )
  }
}

private enum AssociatedKeys {
  static var hosting = "MyNativeViewHosting"
}
