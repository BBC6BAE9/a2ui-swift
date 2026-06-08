//
//  ViewController.swift
//  A2UIAppKitDemo
//
//  Renders a real A2UI v0.9 message stream through A2UIAppKit (macOS).
//

import Cocoa
import A2UISwiftCore   // A2uiMessage / MessageProcessor / Catalog / basicCatalog
import A2UIAppKit      // A2UISurfaceHostView

final class ViewController: NSViewController {

    /// Switch to any bundled sample: "contact_card", "contact_form", "recipe".
    private let sampleName = "kitchen_sink"

    private let host = A2UISurfaceHostView()
    private var processor: MessageProcessor?

    override func loadView() {
        // A flipped container so child content lays out from the top-left.
        view = FlippedView(frame: NSRect(x: 0, y: 0, width: 440, height: 720))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(host)
        host.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            host.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            host.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            // bottom is <= so the host sizes to its content rather than stretching.
            host.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -16),
        ])
        renderFromJSON(named: sampleName)
    }

    private func renderFromJSON(named name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            showError("Could not find \(name).json in the app bundle"); return
        }
        do {
            let messages = try JSONDecoder().decode([A2uiMessage].self, from: data)
            guard let (surfaceId, catalogId) = Self.surfaceInfo(in: messages) else {
                showError("No createSurface message"); return
            }
            let catalog = Catalog(id: catalogId,
                                  componentNames: basicCatalog.componentNames,
                                  functions: basicCatalog.functions)
            let processor = MessageProcessor(catalogs: [catalog]) { action in
                print("▶︎ action:", action.name, action.context)
            }
            self.processor = processor
            _ = processor.processMessages(messages)
            guard let surface = processor.model.getSurface(surfaceId) else {
                showError("Surface \(surfaceId) not created"); return
            }
            host.render(surface: surface, rootComponentId: "root")
            view.layoutSubtreeIfNeeded()
            logToFile("✅ rendered \(name).json — host subviews=\(host.subviews.count), host.frame=\(host.frame)")
        } catch {
            showError("Decode failed: \(error)")
        }
    }

    private func logToFile(_ message: String) {
        let line = message + "\n"
        try? line.write(toFile: "/tmp/a2ui_appkit_run.log", atomically: true, encoding: .utf8)
    }

    private static func surfaceInfo(in messages: [A2uiMessage]) -> (String, String)? {
        for message in messages {
            if case .createSurface(let payload) = message {
                return (payload.surfaceId, payload.catalogId)
            }
        }
        return nil
    }

    private func showError(_ message: String) {
        let label = NSTextField(labelWithString: "⚠️ " + message)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.topAnchor.constraint(equalTo: view.topAnchor, constant: 40),
        ])
    }
}

/// Top-origin NSView so content lays out from the top.
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
