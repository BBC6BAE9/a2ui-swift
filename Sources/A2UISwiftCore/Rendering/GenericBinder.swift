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

// Mirrors WebCore rendering/generic-binder.ts
//
// In WebCore, GenericBinder is a class that bridges DataContext to component
// properties by subscribing to Preact Signals and reactively updating DOM
// attributes whenever the underlying data changes.
//
// In Swift, this responsibility is split across two paths depending on the UI framework:
//
// SwiftUI (implicit binding)
// ─────────────────────────
// DataContext.resolve*() reads PathSlot.value, which is marked @Observable.
// SwiftUI's automatic dependency tracking registers the PathSlot as a dependency
// of the current View body and re-renders only that view when the value changes.
// No explicit subscription or disposal is needed.
// See: DataContext.resolveDynamicValue(_:), DataContext+SwiftUI.swift
//
// UIKit / AppKit (explicit subscription)
// ───────────────────────────────────────
// DataContext.subscribe*() returns a DataSubscription<V> token that holds the
// current value and an unsubscribe() method. Tokens are collected in a
// DataSubscriptions bag and cancelled together (e.g. in prepareForReuse).
// See: DataContext.subscribeDynamicValue(_:onChange:), DataSubscriptions.swift
//
// This file is kept as a structural mirror of WebCore. No implementation is
// required on the Swift side.
