//
//  main.swift
//  A2UIAppKitDemo
//
//  Explicit AppKit entry point — the most reliable way to start a programmatic
//  macOS app (no storyboard, no @main ambiguity).
//

import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
