//
//  AppDelegate.swift
//  A2UIAppKitDemo
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

    private var window: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Become a normal, focusable app BEFORE showing the window.
        NSApp.setActivationPolicy(.regular)

        let vc = ViewController()
        window = NSWindow(contentViewController: vc)
        window.setContentSize(NSSize(width: 440, height: 720))
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.title = "A2UI · AppKit Demo"
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
