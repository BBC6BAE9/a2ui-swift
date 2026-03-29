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

@testable import A2UISwiftCore
import Testing

@Suite("SurfaceGroupModel")
struct SurfaceGroupModelTests {

    @Test("adds surface")
    func addsSurface() {
        let model = SurfaceGroupModel()
        let surface = SurfaceModel(id: "s1")
        model.addSurface(surface)

        #expect(model.getSurface("s1") != nil)
        #expect(model.getSurface("s1") === surface)
    }

    @Test("ignores duplicate surface addition")
    func ignoresDuplicateSurface() {
        let model = SurfaceGroupModel()
        let s1 = SurfaceModel(id: "s1")
        let s2 = SurfaceModel(id: "s1")  // Same ID
        model.addSurface(s1)
        model.addSurface(s2)

        // Should still hold the first one
        #expect(model.getSurface("s1") === s1)
    }

    @Test("deletes surface")
    func deletesSurface() {
        let model = SurfaceGroupModel()
        let surface = SurfaceModel(id: "s1")
        model.addSurface(surface)
        #expect(model.getSurface("s1") != nil)

        model.deleteSurface("s1")
        #expect(model.getSurface("s1") == nil)
    }

    @Test("notifies lifecycle listeners")
    func notifiesLifecycleListeners() {
        let model = SurfaceGroupModel()
        var created: SurfaceModel?
        var deletedId: String?

        model.onSurfaceCreated.subscribe { created = $0 }
        model.onSurfaceDeleted.subscribe { deletedId = $0 }

        let surface = SurfaceModel(id: "s1")
        model.addSurface(surface)
        #expect(created != nil)
        #expect(created?.id == "s1")

        model.deleteSurface("s1")
        #expect(deletedId == "s1")
    }

    @Test("propagates actions from surfaces")
    func propagatesActions() {
        let model = SurfaceGroupModel()
        var receivedAction: A2uiClientAction?
        model.onAction.subscribe { receivedAction = $0 }

        let surface = SurfaceModel(id: "s1")
        model.addSurface(surface)

        surface.dispatchAction(name: "test", sourceComponentId: "c1")

        #expect(receivedAction?.name == "test")
        #expect(receivedAction?.surfaceId == "s1")
        #expect(receivedAction?.sourceComponentId == "c1")
    }

    @Test("stops propagating actions after deletion")
    func stopsPropagatingAfterDeletion() {
        let model = SurfaceGroupModel()
        var callCount = 0
        model.onAction.subscribe { _ in callCount += 1 }

        let surface = SurfaceModel(id: "s1")
        model.addSurface(surface)
        model.deleteSurface("s1")

        surface.dispatchAction(name: "test", sourceComponentId: "c1")
        #expect(callCount == 0)
    }

    @Test("exposes surfacesMap")
    func surfacesMap() {
        let model = SurfaceGroupModel()
        let surface = SurfaceModel(id: "s1")
        model.addSurface(surface)

        let map = model.surfacesMap
        #expect(map.count == 1)
        #expect(map["s1"] === surface)
    }

    @Test("disposes correctly")
    func disposeTriggersDeletedForAll() {
        let model = SurfaceGroupModel()
        let s1 = SurfaceModel(id: "s1")
        let s2 = SurfaceModel(id: "s2")
        model.addSurface(s1)
        model.addSurface(s2)

        var deletedCount = 0
        model.onSurfaceDeleted.subscribe { _ in deletedCount += 1 }

        model.dispose()

        #expect(deletedCount == 2)
        #expect(model.surfacesMap.isEmpty)
    }
}
