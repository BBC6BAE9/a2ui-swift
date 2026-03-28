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

// Mirrors WebCore basic_catalog/functions/basic_functions_api.ts
//
// In WebCore this file contains typed Zod schema definitions (FunctionApi objects)
// for each of the 25 built-in functions — their argument names, types, and
// return types — separate from the actual implementations in basic_functions.ts.
//
// In Swift we don't have Zod, so argument validation is done inline in
// BasicFunctions.swift. This file is kept as a structural mirror of WebCore and
// can be used in the future to hold typed argument structs or documentation
// comments per function if needed.
