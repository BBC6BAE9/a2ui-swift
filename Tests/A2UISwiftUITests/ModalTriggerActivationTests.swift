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

import A2UISwiftCore
import Foundation
import Testing

@testable import A2UISwiftUI

// Regression coverage for https://github.com/BBC6BAE9/a2ui-swift/issues/76:
// a Modal whose trigger Button carries a functionCall action never opened,
// because Modal inferred trigger activation from `a2uiActionHandler`, which
// fires only for event actions.
//
// These tests exercise the same dispatch function the SwiftUI Button invokes
// on tap (`a2uiHandleButtonAction`): `onTriggerActivated` must fire for BOTH
// Action kinds, while `actionHandler` keeps its host contract (resolved
// server events only).

@MainActor
@Suite("Button trigger activation (Modal open path)")
struct ModalTriggerActivationTests {

    private func makeSurface() -> SurfaceModel {
        SurfaceModel(id: "test", catalog: basicCatalog)
    }

    @Test("functionCall action fires onTriggerActivated (issue #76)")
    func functionCallFiresTriggerActivation() {
        let surface = makeSurface()
        let dc = DataContext(surface: surface, path: "/")
        var activated = false
        var hostActions: [ResolvedAction] = []

        a2uiHandleButtonAction(
            .functionCall(FunctionCall(
                call: "required",
                args: ["input": .string("x")],
                returnType: nil
            )),
            componentId: "openBtn",
            dataContext: dc,
            surface: surface,
            actionHandler: { hostActions.append($0) },
            onTriggerActivated: { activated = true }
        )

        #expect(activated, "functionCall trigger must report activation so Modal can present")
        // Host contract unchanged: no synthesized ResolvedAction for functionCalls.
        #expect(hostActions.isEmpty)
    }

    @Test("unknown function still fires onTriggerActivated")
    func unknownFunctionStillFiresTriggerActivation() {
        let surface = makeSurface()
        let dc = DataContext(surface: surface, path: "/")
        var activated = false

        a2uiHandleButtonAction(
            .functionCall(FunctionCall(call: "noSuchFunction", args: [:], returnType: nil)),
            componentId: "openBtn",
            dataContext: dc,
            surface: surface,
            actionHandler: nil,
            onTriggerActivated: { activated = true }
        )

        #expect(activated, "activation must not be gated on the function resolving")
    }

    @Test("event action fires onTriggerActivated and still notifies actionHandler")
    func eventFiresBothTriggerActivationAndActionHandler() {
        let surface = makeSurface()
        let dc = DataContext(surface: surface, path: "/")
        var activated = false
        var hostActions: [ResolvedAction] = []

        a2uiHandleButtonAction(
            .event(name: "open", context: nil),
            componentId: "openBtn",
            dataContext: dc,
            surface: surface,
            actionHandler: { hostActions.append($0) },
            onTriggerActivated: { activated = true }
        )

        #expect(activated)
        #expect(hostActions.count == 1)
        #expect(hostActions.first?.name == "open")
        #expect(hostActions.first?.sourceComponentId == "openBtn")
    }
}
