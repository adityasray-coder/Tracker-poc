/**
 * SwiftUI view that fires a callback when it appears, used with UIHostingController.
 */

import SwiftUI
import UIKit

/// A lightweight SwiftUI "sensor" view.
/// It uses a transparent background (Color.clear) to occupy space without 
/// affecting the UI, primarily to leverage the SwiftUI `onAppear` lifecycle hook.
struct MyNativeSwiftUIView: View {
  /// The callback closure executed when the view enters the SwiftUI hierarchy.
  var onAppear: () -> Void

  var body: some View {
    Color.clear
      // Expand to fill the entire container provided by the UIKit parent.
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      // Trigger the provided logic when this view becomes active/visible.
      .onAppear(perform: onAppear)
  }
}

/// Objective-C compatible bridge to allow UIKit components (like MyNativeView)
/// to host SwiftUI content and receive lifecycle events.
@objc(MyNativeViewBridge)
public class MyNativeViewBridge: NSObject {
  
  /// Attaches the SwiftUI view to a UIKit container and sets the onAppear callback.
  /// - Parameters:
  ///   - containerView: The UIKit view that will host the SwiftUI content.
  ///   - onAppearBlock: The logic to run when SwiftUI signals the view has appeared.
  @objc public static func attachSwiftUI(to containerView: UIView, onAppearBlock: @escaping () -> Void) {
    
    // 1. Initialize the SwiftUI View with the provided callback logic.
    let swiftUIView = MyNativeSwiftUIView(onAppear: onAppearBlock)
    
    // 2. Wrap the SwiftUI View in a UIHostingController.
    // UIHostingController is the standard bridge for putting SwiftUI inside UIKit.
    let hosting = UIHostingController(rootView: swiftUIView)
    
    // 3. Configure the Hosting View appearance.
    hosting.view.backgroundColor = .clear
    hosting.view.translatesAutoresizingMaskIntoConstraints = false
    
    // 4. Disable user interaction so this "sensor" layer doesn't 
    // intercept touches intended for underlying UIKit elements.
    hosting.view.isUserInteractionEnabled = false

    // 5. Add the hosting view as a subview and pin it to all four edges.
    containerView.addSubview(hosting.view)
    NSLayoutConstraint.activate([
      hosting.view.topAnchor.constraint(equalTo: containerView.topAnchor),
      hosting.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
      hosting.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
      hosting.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
    ])
    
    // 6. Memory Management: Retain the Hosting Controller.
    // Because UIHostingController is not automatically retained by its view, 
    // we use Objective-C 'Associated Objects' to link the controller's lifetime 
    // to the containerView's lifetime. This prevents it from being deallocated immediately.
    objc_setAssociatedObject(
      containerView,
      &AssociatedKeys.hosting,
      hosting,
      .OBJC_ASSOCIATION_RETAIN_NONATOMIC
    )
  }
}

/// Private keys used for Objective-C associated objects.
private enum AssociatedKeys {
  static var hosting = "MyNativeViewHosting"
}