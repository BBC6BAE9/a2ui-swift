//
//  DemoViewController.swift
//  A2UIUIKitDemo
//
//  Renders a real A2UI v0.9 message stream (contact_card.json) — the exact wire
//  format a server would send — through A2UIUIKit. No hand-built components: the
//  JSON drives the entire UI.
//

import UIKit
import A2UISwiftCore   // A2uiMessage / MessageProcessor / Catalog / basicCatalog
import A2UIUIKit       // A2UISurfaceHostView

final class DemoViewController: UIViewController {

    private let host = A2UISurfaceHostView()
    private let scrollView = UIScrollView()
    private var processor: MessageProcessor?

    /// Switch this to any v0.9 sample bundled with the app:
    /// "contact_card", "contact_form", "recipe", "restaurant_list", "format_functions".
    private let sampleName = "contact_card"

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "A2UI · \(sampleName).json"
        view.backgroundColor = .systemBackground
        layoutHost()
        renderFromJSON(named: sampleName)
    }

    /// Decodes a v0.9 message file and renders the resulting surface.
    private func renderFromJSON(named name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            showError("Could not find \(name).json in the app bundle")
            return
        }

        do {
            let messages = try JSONDecoder().decode([A2uiMessage].self, from: data)

            // The catalog id is whatever the createSurface message declares; reuse
            // the basic catalog's components + functions under that id.
            guard let (surfaceId, catalogId) = Self.surfaceInfo(in: messages) else {
                showError("No createSurface message found"); return
            }
            let catalog = Catalog(id: catalogId,
                                  componentNames: basicCatalog.componentNames,
                                  functions: basicCatalog.functions)

            let processor = MessageProcessor(catalogs: [catalog]) { action in
                print("▶︎ action:", action.name, action.context)
            }
            self.processor = processor

            let errors = processor.processMessages(messages)
            if !errors.isEmpty { print("⚠️ processing errors:", errors) }

            guard let surface = processor.model.getSurface(surfaceId) else {
                showError("Surface \(surfaceId) was not created"); return
            }
            host.render(surface: surface, rootComponentId: "root")
        } catch {
            showError("Decode failed: \(error)")
        }
    }

    /// Pulls the surfaceId + catalogId out of the first createSurface message.
    private static func surfaceInfo(in messages: [A2uiMessage]) -> (String, String)? {
        for message in messages {
            if case .createSurface(let payload) = message {
                return (payload.surfaceId, payload.catalogId)
            }
        }
        return nil
    }

    // MARK: - Layout

    private func layoutHost() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        host.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(host)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            host.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            host.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            host.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            host.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            host.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),
        ])
    }

    private func showError(_ message: String) {
        let label = UILabel()
        label.text = "⚠️ " + message
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
        ])
    }
}
