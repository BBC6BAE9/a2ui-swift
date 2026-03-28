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
@testable import A2A
@Suite("A2UIV09_A2A Tests")
struct A2UIV09_A2ATests {

    @Test("A2ATransportError provides localised descriptions")
    func transportErrorDescriptions() {
        let error = A2ATransportError.network(message: "timeout")
        #expect(error.localizedDescription.contains("timeout"))
    }

    @Test("SseParser can be instantiated")
    func sseParserInit() {
        let parser = SseParser()
        _ = parser // Just verifying the type is accessible from this module.
    }
}
