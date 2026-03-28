// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Testing
import Foundation
@testable import A2A
// MARK: - AgentCard JSON Tests
// Mirrors Dart `test/a2a/core/agent_card_test.dart`

@Suite("AgentCard")
struct AgentCardTests {

    @Test("can be instantiated")
    func instantiation() {
        let agentCard = AgentCard(
            protocolVersion: "0.2.9",
            name: "Test Agent",
            description: "A test agent.",
            url: "https://example.com/a2a",
            version: "1.0.0",
            capabilities: AgentCapabilities(),
            defaultInputModes: [],
            defaultOutputModes: [],
            skills: []
        )
        _ = agentCard  // confirms it exists
    }

    @Test("can be serialized and deserialized from JSON")
    func jsonRoundTrip() throws {
        let data = agentCardJson.data(using: .utf8)!
        let agentCard = try JSONDecoder().decode(AgentCard.self, from: data)

        let reEncoded = try JSONEncoder().encode(agentCard)
        let agentCard2 = try JSONDecoder().decode(AgentCard.self, from: reEncoded)

        #expect(agentCard2 == agentCard)
        #expect(agentCard.name == "GeoSpatial Route Planner Agent")
        #expect(agentCard.skills.count == 2)
    }
}

// MARK: - Fixture
// Same JSON fixture as Dart's `agent_card_test.dart`.

private let agentCardJson = """
{
  "protocolVersion": "0.2.9",
  "name": "GeoSpatial Route Planner Agent",
  "description": "Provides advanced route planning, traffic analysis, and custom map generation services. This agent can calculate optimal routes, estimate travel times considering real-time traffic, and create personalized maps with points of interest.",
  "url": "https://georoute-agent.example.com/a2a/v1",
  "preferredTransport": "JSONRPC",
  "additionalInterfaces": [
    {
      "url": "https://georoute-agent.example.com/a2a/v1",
      "transport": "JSONRPC"
    },
    {
      "url": "https://georoute-agent.example.com/a2a/grpc",
      "transport": "GRPC"
    },
    {
      "url": "https://georoute-agent.example.com/a2a/json",
      "transport": "HTTP+JSON"
    }
  ],
  "provider": {
    "organization": "Example Geo Services Inc.",
    "url": "https://www.examplegeoservices.com"
  },
  "iconUrl": "https://georoute-agent.example.com/icon.png",
  "version": "1.2.0",
  "documentationUrl": "https://docs.examplegeoservices.com/georoute-agent/api",
  "capabilities": {
    "streaming": true,
    "pushNotifications": true,
    "stateTransitionHistory": false
  },
  "securitySchemes": {
    "google": {
      "type": "openIdConnect",
      "openIdConnectUrl": "https://accounts.google.com/.well-known/openid-configuration"
    }
  },
  "security": [
    {
      "google": [
        "openid",
        "profile",
        "email"
      ]
    }
  ],
  "defaultInputModes": [
    "application/json",
    "text/plain"
  ],
  "defaultOutputModes": [
    "application/json",
    "image/png"
  ],
  "skills": [
    {
      "id": "route-optimizer-traffic",
      "name": "Traffic-Aware Route Optimizer",
      "description": "Calculates the optimal driving route between two or more locations, taking into account real-time traffic conditions, road closures, and user preferences (e.g., avoid tolls, prefer highways).",
      "tags": [
        "maps",
        "routing",
        "navigation",
        "directions",
        "traffic"
      ],
      "examples": [
        "Plan a route from '1600 Amphitheatre Parkway, Mountain View, CA' to 'San Francisco International Airport' avoiding tolls.",
        "{\\"origin\\": {\\"lat\\": 37.422, \\"lng\\": -122.084}, \\"destination\\": {\\"lat\\": 37.7749, \\"lng\\": -122.4194}, \\"preferences\\": [\\"avoid_ferries\\"]}"
      ],
      "inputModes": [
        "application/json",
        "text/plain"
      ],
      "outputModes": [
        "application/json",
        "application/vnd.geo+json",
        "text/html"
      ]
    },
    {
      "id": "custom-map-generator",
      "name": "Personalized Map Generator",
      "description": "Creates custom map images or interactive map views based on user-defined points of interest, routes, and style preferences. Can overlay data layers.",
      "tags": [
        "maps",
        "customization",
        "visualization",
        "cartography"
      ],
      "examples": [
        "Generate a map of my upcoming road trip with all planned stops highlighted.",
        "Show me a map visualizing all coffee shops within a 1-mile radius of my current location."
      ],
      "inputModes": [
        "application/json"
      ],
      "outputModes": [
        "image/png",
        "image/jpeg",
        "application/json",
        "text/html"
      ]
    }
  ],
  "supportsAuthenticatedExtendedCard": true
}
"""
