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

import SwiftUI
import A2UI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        CatalogPage()
                    } label: {
                        Label("Component Gallery", systemImage: "square.grid.2x2")
                    }

                    NavigationLink {
                        ActionDemoPage(
                            filename: "action_context",
                            title: "Action Context",
                            subtitle: "Path-bound data in action payload",
                            info: "When a Button is tapped, the renderer reads values from the data model using the paths defined in action.context, then packages them into a resolved action payload to send back to the agent. Edit the fields and tap Send to see the resolved result."
                        )
                    } label: {
                        Label("Action Context", systemImage: "arrow.up.message")
                    }

                    NavigationLink {
                        ActionDemoPage(
                            filename: "format_functions",
                            title: "Format Functions",
                            subtitle: "formatDate in action context",
                            info: "Action context values can use function calls like formatDate to transform data before sending. Compare rawDate (the original ISO string from the data model) with formatted (processed by formatDate) in the resolved action."
                        )
                    } label: {
                        Label("Format Functions", systemImage: "calendar.badge.clock")
                    }
                    NavigationLink {
                        StyleOverridePage()
                    } label: {
                        Label("Style Override", systemImage: "paintbrush")
                    }

                    NavigationLink {
                        CustomComponentPage()
                    } label: {
                        Label("Custom Component", systemImage: "star.square.on.square")
                    }

                    NavigationLink {
                        IncrementalUpdatePage()
                    } label: {
                        Label("Incremental Update", systemImage: "arrow.triangle.2.circlepath")
                    }

                    NavigationLink {
                        RizzchartsPage()
                    } label: {
                        Label("Rizzcharts", systemImage: "chart.pie")
                    }
                } header: {
                    Text("Native Static Demos")
                } footer: {
                    Text("Run entirely on-device with static JSON. No agent connection required.")
                }

                Section {
                    NavigationLink {
                        LiveAgentPage(
                            agentURL: URL(string: "http://localhost:10005")!,
                            initialQuery: "START_GALLERY"
                        )
                    } label: {
                        Label("Component Gallery", systemImage: "antenna.radiowaves.left.and.right")
                    }
                } header: {
                    Text("Live Agent — Gallery")
                } footer: {
                    Text("Hardcoded gallery with per-surface demo cards.")
                }

                Section {
                    NavigationLink {
                        AgentChatPage(
                            title: "Contact Lookup",
                            agentURL: URL(string: "http://localhost:10003")!,
                            initialQuery: "Find Alex Jordan in Marketing"
                        )
                    } label: {
                        Label("Contact Lookup", systemImage: "person.crop.rectangle")
                    }

                    NavigationLink {
                        AgentCardPage(
                            title: "Restaurant Finder",
                            agentURL: URL(string: "http://localhost:10002")!,
                            initialQuery: "Find me Chinese restaurants in New York"
                        )
                    } label: {
                        Label("Restaurant Finder", systemImage: "fork.knife")
                    }

                    NavigationLink {
                        AgentChatPage(
                            title: "Rizzcharts",
                            agentURL: URL(string: "http://localhost:10004")!,
                            initialQuery: "Show my sales breakdown by product category for Q3",
                            customRenderer: rizzchartsRenderer
                        )
                    } label: {
                        Label("Rizzcharts", systemImage: "chart.pie")
                    }
                } header: {
                    Text("Live Agent")
                } footer: {
                    Text("Connect to live agents running on localhost.")
                }

                Section("Samples") {
                    ForEach(SampleDemo.allCases.filter {
                        $0 != .actionContext && $0 != .formatFunctions && $0 != .incrementalUpdate
                    }) { demo in
                        NavigationLink {
                            SampleDetailPage(demo: demo)
                        } label: {
                            Label(demo.rawValue, systemImage: demo.icon)
                        }
                    }
                }
            }
            .navigationTitle("A2UI Demo")
        }
    }
}

#Preview {
    ContentView()
}
