import AppKit
import SwiftUI

@MainActor
final class WindowController {
    private var window: NSWindow?
    private var delegate: WindowCloseDelegate?

    var isOpen: Bool {
        window != nil
    }

    func show(
        title: String,
        size: NSSize = NSSize(width: 600, height: 500),
        content: @escaping () -> some View
    ) {
        close()

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = title
        window.contentView = NSHostingView(rootView: content())
        window.center()

        let delegate = WindowCloseDelegate { [weak self] in
            self?.tearDown()
        }
        window.delegate = delegate
        self.delegate = delegate

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }

    func close() {
        tearDown()
    }

    private func tearDown() {
        window?.delegate = nil
        window?.contentView = nil
        window?.close()
        window = nil
        delegate = nil
    }
}

private final class WindowCloseDelegate: NSObject, NSWindowDelegate {
    private var onClose: (@MainActor () -> Void)?

    init(onClose: @escaping @MainActor () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_: Notification) {
        let closure = onClose
        onClose = nil
        if let closure {
            MainActor.assumeIsolated { closure() }
        }
    }
}
