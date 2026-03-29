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
// In Swift / SwiftUI this responsibility is handled natively by the @Observable
// macro and SwiftUI's automatic dependency tracking. When a View reads a value
// from an @Observable object (e.g. PathSlot.value or DataStore), SwiftUI
// automatically invalidates and re-renders only that view when the value changes —
// no explicit binder or subscription management is needed.
//
// This file is kept as a structural mirror of WebCore. No implementation is
// required on the Swift side.
