// Copyright 2025 GenUI Authors.

import XCTest
import Foundation
@testable import Primitives
final class ExampleTests: XCTestCase {

    func testRunExample() throws {
        var output = ""

        func log(_ object: Any) {
            output += "\(object)\n"
        }

        log("--- GenAI Primitives Example ---")

        // 1. Define a Tool
        let getWeatherTool = ToolDefinition(
            name: "get_weather",
            description: "Get the current weather for a location",
            inputSchema: [
                "type": "object",
                "properties": [
                    "location": [
                        "type": "string",
                        "description": "The city and state, e.g. San Francisco, CA",
                    ] as [String: Any],
                    "unit": [
                        "type": "string",
                        "description": "The unit of temperature",
                        "enum": ["celsius", "fahrenheit"],
                    ] as [String: Any],
                ] as [String: Any],
                "required": ["location"],
            ]
        )

        log("\n[Tool Definition]")
        let toolJson = getWeatherTool.toJson()
        let toolData = try JSONSerialization.data(
            withJSONObject: toolJson,
            options: [.prettyPrinted, .sortedKeys]
        )
        log(String(data: toolData, encoding: .utf8)!)

        // 2. Create a conversation history
        var history: [ChatMessage] = [
            ChatMessage.system(
                "You are a helpful weather assistant. "
                + "Use the get_weather tool when needed."
            ),
            ChatMessage.user("What is the weather in London?"),
        ]

        log("\n[Initial Conversation]")
        for msg in history {
            log("\(msg.role.rawValue): \(msg.text)")
        }

        // 3. Simulate Model Response with Tool Call
        let modelResponse = ChatMessage.model(
            "",
            parts: [
                .text("Thinking: User wants weather for London..."),
                ToolPart.call(
                    callId: "call_123",
                    toolName: "get_weather",
                    arguments: ["location": .string("London"), "unit": .string("celsius")]
                ),
            ]
        )
        history.append(modelResponse)

        log("\n[Model Response with Tool Call]")
        if modelResponse.hasToolCalls {
            for call in modelResponse.toolCalls {
                // Format arguments like Flutter: {location: London, unit: celsius}
                let argsStr: String
                if let args = call.arguments {
                    let pairs = args.sorted(by: { $0.key < $1.key })
                        .map { "\($0.key): \($0.value.description)" }
                    argsStr = "{\(pairs.joined(separator: ", "))}"
                } else {
                    argsStr = "{}"
                }
                log("Tool Call: \(call.toolName)(\(argsStr))")
            }
        }

        // 4. Simulate Tool Execution & Result
        let toolResultMsg = ChatMessage.user(
            "",
            parts: [
                ToolPart.result(
                    callId: "call_123",
                    toolName: "get_weather",
                    result: .object(["temperature": .int(15), "condition": .string("Cloudy")])
                ),
            ]
        )
        history.append(toolResultMsg)

        log("\n[Tool Result]")
        if let firstResult = toolResultMsg.toolResults.first,
           let resultVal = firstResult.result {
            // Format like Flutter: {temperature: 15, condition: Cloudy}
            log("Result: \(resultVal)")
        }

        // 5. Simulate Final Model Response with Data
        let finalResponse = ChatMessage.model(
            "Here is a chart of the weather trend:",
            parts: [
                .data(DataPartContent(
                    bytes: Data([0x89, 0x50, 0x4E, 0x47]),
                    mimeType: "image/png",
                    name: "weather_chart.png"
                )),
            ]
        )
        history.append(finalResponse)

        log("\n[Final Model Response with Data]")
        log("Text: \(finalResponse.text)")
        for part in finalResponse.parts {
            if case .data(let dataPart) = part {
                log("Attachment: \(dataPart.name ?? "unnamed") (\(dataPart.mimeType), \(dataPart.bytes.count) bytes)")
            }
        }

        // 6. Demonstrate JSON serialization of the whole history
        log("\n[Full History JSON]")
        let historyJson = history.map { $0.toJson() }
        let historyData = try JSONSerialization.data(
            withJSONObject: historyJson,
            options: [.prettyPrinted, .sortedKeys]
        )
        log(String(data: historyData, encoding: .utf8)!)

        // Verify the output matches expected
        XCTAssertEqual(output, _expectedOutput)
    }
}

private let _expectedOutput = """
--- GenAI Primitives Example ---

[Tool Definition]
{
  "description" : "Get the current weather for a location",
  "inputSchema" : {
    "properties" : {
      "location" : {
        "description" : "The city and state, e.g. San Francisco, CA",
        "type" : "string"
      },
      "unit" : {
        "description" : "The unit of temperature",
        "enum" : [
          "celsius",
          "fahrenheit"
        ],
        "type" : "string"
      }
    },
    "required" : [
      "location"
    ],
    "type" : "object"
  },
  "name" : "get_weather"
}

[Initial Conversation]
system: You are a helpful weather assistant. Use the get_weather tool when needed.
user: What is the weather in London?

[Model Response with Tool Call]
Tool Call: get_weather({location: London, unit: celsius})

[Tool Result]
Result: {condition: Cloudy, temperature: 15}

[Final Model Response with Data]
Text: Here is a chart of the weather trend:
Attachment: weather_chart.png (image/png, 4 bytes)

[Full History JSON]
[
  {
    "metadata" : {

    },
    "parts" : [
      {
        "content" : "You are a helpful weather assistant. Use the get_weather tool when needed.",
        "type" : "Text"
      }
    ],
    "role" : "system"
  },
  {
    "metadata" : {

    },
    "parts" : [
      {
        "content" : "What is the weather in London?",
        "type" : "Text"
      }
    ],
    "role" : "user"
  },
  {
    "metadata" : {

    },
    "parts" : [
      {
        "content" : "Thinking: User wants weather for London...",
        "type" : "Text"
      },
      {
        "content" : {
          "arguments" : {
            "location" : "London",
            "unit" : "celsius"
          },
          "id" : "call_123",
          "name" : "get_weather"
        },
        "type" : "Tool"
      }
    ],
    "role" : "model"
  },
  {
    "metadata" : {

    },
    "parts" : [
      {
        "content" : {
          "id" : "call_123",
          "name" : "get_weather",
          "result" : {
            "condition" : "Cloudy",
            "temperature" : 15
          }
        },
        "type" : "Tool"
      }
    ],
    "role" : "user"
  },
  {
    "metadata" : {

    },
    "parts" : [
      {
        "content" : "Here is a chart of the weather trend:",
        "type" : "Text"
      },
      {
        "content" : {
          "bytes" : "data:image\\/png;base64,iVBORw==",
          "mimeType" : "image\\/png",
          "name" : "weather_chart.png"
        },
        "type" : "Data"
      }
    ],
    "role" : "model"
  }
]

"""
