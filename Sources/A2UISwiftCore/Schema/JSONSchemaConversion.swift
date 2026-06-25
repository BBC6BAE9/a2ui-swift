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

import JSONSchema
import OrderedJSON

extension AnyCodable {
    init(jsonValue: JSONValue) {
        switch jsonValue {
        case .string(let value):
            self = .string(value)
        case .number(let value):
            self = .number(value)
        case .integer(let value):
            self = .number(Double(value))
        case .object(let value):
            self = .dictionary(value.reduce(into: [:]) { result, pair in
                result[pair.key] = AnyCodable(jsonValue: pair.value)
            })
        case .array(let value):
            self = .array(value.map { AnyCodable(jsonValue: $0) })
        case .boolean(let value):
            self = .bool(value)
        case .null:
            self = .null
        }
    }
}

extension Schema {
    var anyCodableSchema: AnyCodable {
        AnyCodable(jsonValue: jsonValue)
    }
}
