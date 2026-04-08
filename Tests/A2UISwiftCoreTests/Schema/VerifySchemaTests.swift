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

// Mirrors WebCore schema/verify-schema.test.ts
//
// WebCore's verify-schema test uses `zod-to-json-schema` to convert Zod schema
// definitions (A2uiMessageSchema, CreateSurfaceMessageSchema, etc.) into JSON
// Schema objects, then performs a structural diff against the official JSON
// specification files on disk (specification/v0_9/json/*.json). It verifies
// that every field name and type in the Zod schema matches the specification.
//
// This test has no Swift equivalent for the following reasons:
//
// 1. No Zod / zod-to-json-schema in Swift:
//    Swift uses Codable (Decodable/Encodable) for schema definition. There is no
//    runtime schema-to-JSON-Schema conversion library in Swift, so there is no
//    programmatic way to extract a JSON Schema from Swift types.
//
// 2. Different validation strategy:
//    Swift's Codable is validated at compile time by the type system. The
//    equivalent assurance that Swift types match the specification is provided
//    by the round-trip decode/encode tests in ClientToServerTests.swift and
//    manual code review — not by a runtime schema diff.
//
// This file exists solely to maintain file-level parity with WebCore.

@testable import A2UISwiftCore