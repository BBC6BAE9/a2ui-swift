import SwiftUI
import MapKit
import A2UISwiftCore

/// MapKit implementation of the Rizzcharts GoogleMap component.
struct RizzchartMapView: View {
    let node: ComponentNode
    let surface: SurfaceModel

    private var dataContext: DataContext {
        DataContext(surface: surface, path: node.dataContextPath)
    }

    private func resolve(_ prop: AnyCodable?) -> AnyCodable? {
        guard let prop else { return nil }
        if let path = prop.dictionaryValue?["path"]?.stringValue {
            return surface.dataModel.get(dataContext.resolvePath(path))
        }
        return prop
    }

    private var properties: [String: AnyCodable] { node.instance.properties }

    private var centerCoord: CLLocationCoordinate2D {
        guard let data = resolve(properties["center"]),
              case .dictionary(let dict) = data,
              let lat = dict["lat"]?.numberValue,
              let lng = dict["lng"]?.numberValue else {
            return CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437)
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    private var zoomLevel: Double {
        resolve(properties["zoom"])?.numberValue ?? 11
    }

    /// Convert Google Maps zoom level (0-21) to approximate MapKit camera distance.
    private var cameraDistance: Double {
        let z = max(0, min(21, zoomLevel))
        return 40_075_000 / pow(2, z) * 1.5
    }

    private var pins: [MapPin] {
        guard let data = resolve(properties["pins"]), case .array(let items) = data else {
            return []
        }
        return items.enumerated().compactMap { (idx, item) -> MapPin? in
            guard case .dictionary(let dict) = item,
                  let lat = dict["lat"]?.numberValue,
                  let lng = dict["lng"]?.numberValue else { return nil }
            return MapPin(
                id: idx,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                name: dict["name"]?.stringValue ?? "Pin \(idx + 1)",
                description: dict["description"]?.stringValue
            )
        }
    }

    var body: some View {
        Map(initialPosition: .camera(MapCamera(
            centerCoordinate: centerCoord,
            distance: cameraDistance
        ))) {
            ForEach(pins) { pin in
                Marker(pin.name, coordinate: pin.coordinate)
            }
        }
        .frame(height: 400)
        .clipShape(RoundedRectangle(cornerRadius: 12))

        if !pins.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(pins) { pin in
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.red)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(pin.name)
                                .font(.subheadline.weight(.medium))
                            if let desc = pin.description {
                                Text(desc)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Data Model

struct MapPin: Identifiable {
    let id: Int
    let coordinate: CLLocationCoordinate2D
    let name: String
    let description: String?
}
