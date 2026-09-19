#if DEBUG
    import PulseUI
    import SwiftUI
    import UIKit

    public extension UIDevice {
        static let deviceDidShakeNotification = Notification.Name("UIDeviceDidShakeNotification")
    }

    extension UIWindow {
        override open func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
            super.motionEnded(motion, with: event)
            if motion == .motionShake {
                NotificationCenter.default.post(name: UIDevice.deviceDidShakeNotification, object: nil)
            }
        }
    }

    public struct ShakeGestureModifier: ViewModifier {
        @State private var isConsolePresented = false

        public init() {}

        public func body(content: Content) -> some View {
            content
                .onReceive(NotificationCenter.default.publisher(for: UIDevice.deviceDidShakeNotification)) { _ in
                    guard !isConsolePresented else { return }
                    isConsolePresented = true
                }
                .sheet(isPresented: $isConsolePresented) {
                    NavigationView {
                        ConsoleView()
                    }
                }
        }
    }

    public extension View {
        func onShakePresentConsole() -> some View {
            modifier(ShakeGestureModifier())
        }
    }
#endif
