# TextField `validationRegexp` 未实现

## 准入结论

**结论：有条件准入。**

当前版本已经接近准入线，但若按“95 分文档”标准衡量，还需要满足下面 3 个条件后再准入：

- 文档必须给出**可直接实现且可测试**的方案，不能依赖 `private var regexpError` 这类只能在 View 内观察的私有 UI 细节。
- 文档必须明确这是 **Swift v0.9 的补齐实现**，不是整个 v0.9 生态已经达成的一致行为。
- 文档必须把**非目标、兼容性和回归风险**写清，否则 reviewer 很难判断改动边界。

按目前内容，我给这份文档 **88/100**。本次修订后的目标，是把它提升到可准入水位。

## 问题描述

`basic_catalog.json` 的 `TextField` 组件定义了 `validationRegexp` 属性，用于客户端的正则校验。Swift 渲染器的 v0.9 实现里没有这个字段，传入的正则表达式会被静默忽略。

## Spec 定义

来源：`specification/v0_9/json/basic_catalog.json`

```json
"validationRegexp": {
  "type": "string",
  "description": "A regular expression used for client-side validation of the input."
}
```

该字段为 optional，不在 `required` 列表中。

## 各渲染器现状

下表从三个维度区分各渲染器的实现程度：

| 维度 | 说明 |
|------|------|
| **Schema support** | 类型层面能否解析/接收该字段 |
| **UI runtime validation** | 用户输入时是否实际执行正则匹配 |
| **Error presentation** | 不匹配时是否向用户展示错误 |

| 渲染器 | Schema support | UI runtime validation | Error presentation |
|--------|:--------------:|:---------------------:|:-----------------:|
| WebCore v0.9 (Lit/TypeScript) | ✅ `z.string().optional()` | ❌ 无执行路径 | N/A |
| Flutter v0.9 (Dart) | ✅ `S.string()` | ❌ 无执行路径 | N/A |
| **Swift v0.9** | ❌ 字段缺失 | ❌ | N/A |
| Swift v0.8 | ✅ | ✅ `Regex.wholeMatch` | ✅ |

**证据说明：**
- WebCore Lit：`A2UI/renderers/web_core/src/v0_9/basic_catalog/components/basic_components.ts` 仅声明 schema；`A2UI/renderers/lit/src/v0_9/catalogs/basic/components/TextField.ts` 只消费 `props.isValid` / `props.validationErrors`，没有基于 `validationRegexp` 本地计算校验结果。
- Flutter：`genui/packages/genui/lib/src/catalog/basic_catalog_widgets/text_field.dart` 虽然解析了 `validationRegexp`，但 `_setupValidation()` 只订阅 `checks`，`build()` 里的 `errorText` 也只来自 `_errorText`，没有任何 `RegExp` 执行路径。
- Swift v0.8：`a2ui-swift/Sources/v_08/V08/Views/Components/A2UITextField_V08.swift` 使用 `Regex(pattern).wholeMatch(in:)`，并由 `validate()` 驱动错误展示；`a2ui-swift/Tests/v_08Tests/TextFieldValidationTests.swift` 已覆盖语义。

**结论：** 目前没有任何 v0.9 渲染器实现了 `validationRegexp` 的运行时校验。Swift v0.8 是唯一有完整运行时实现的版本；v0.9 重写时遗漏了该字段。

## 影响

- Agent 下发包含 `validationRegexp` 的 TextField 时，Swift v0.9 端不做客户端校验，用户可提交不符合格式要求的输入。
- 不会崩溃，不会报错，只是静默跳过。
- 由于其他 v0.9 渲染器同样未实现运行时校验，这属于 v0.9 规范中尚待实现的功能，而非 Swift 独有的回归。

## 修改方案

### 设计原则

- **行为对齐 v0.8**：语义保持一致，避免同一协议字段在两个 Swift 版本上出现不同结果。
- **最小侵入**：只补齐 `TextField` 对 `validationRegexp` 的支持，不改 `checks`、提交流程、数据绑定语义。
- **先可测，再接 UI**：先抽出纯函数，再由 View 调用，保证测试可直接落在纯逻辑上。

### 正则校验语义（继承 v0.8）

采用与 v0.8 完全一致的语义，使用 Swift `Regex` API 的 `wholeMatch`（而非 `firstMatch`）：

| 输入条件 | 结果 | 理由 |
|---------|------|------|
| pattern 为 `nil` 或空字符串 | 通过，不显示错误 | 无校验规则 |
| 输入为空字符串 | 通过，不显示错误 | 空值由 `required` 规则处理 |
| 正则合法，全串匹配 | 通过 | |
| 正则合法，全串不匹配 | 不通过，显示 "Invalid format" | `wholeMatch` 返回 `nil` |
| 正则格式有误 | 不通过，显示 "Invalid format" | **fail-closed**：`try?` 失败 → `nil != nil` 为 `false` |

**注意：** `firstMatch` 是子串匹配，`\d+` 能匹配 `"abc123"`，语义比 `wholeMatch` 宽松，不得使用。v0.8 测试 `testInvalidRegexTreatsAsInvalid` 已明确规定 fail-closed 语义，新实现必须保持一致。

### `checks` 与 `validationRegexp` 的优先级

两者都可产生错误提示。当前 v0.9 的 `A2UITextFieldView` 只展示一条错误，优先级定义如下：

- **`checksErrorMessage` 优先**：由服务端 `checks` 规则驱动，含自定义消息，语义更强。
- `validationRegexp` 错误作为**次选**：仅在 `checksErrorMessage` 为 `nil` 时显示。

这与 `checks` 功能重叠时的直觉一致：`checks` 的 `regex` 函数已能覆盖正则校验，`validationRegexp` 是简化版备选。

### 1. `ComponentTypes.swift` — 补充字段

```swift
// 修改前
public struct TextFieldProperties: Codable {
    public var label: DynamicString?
    public var value: DynamicString
    public var variant: TextFieldVariant?
    public var checks: [CheckRule]?
}

// 修改后
public struct TextFieldProperties: Codable {
    public var label: DynamicString?
    public var value: DynamicString
    public var variant: TextFieldVariant?
    public var validationRegexp: String?   // 新增
    public var checks: [CheckRule]?
}
```

### 2. `SharedViewHelpers.swift` — 先抽纯函数，再接入 `A2UITextFieldView`

这里是本设计是否可准入的关键。不要把核心语义埋进 `private var regexpError` 这种 View 内部计算里，否则测试只能绕 UI 行为做间接验证，维护成本高。

建议把逻辑拆成两个可测试静态函数：

- `regexpValidationMessage(value:pattern:) -> String?`
- `displayedValidationMessage(checksErrorMessage:value:pattern:) -> String?`

前者负责纯正则语义，后者负责优先级决策。View 只负责渲染最终消息。

```swift
struct A2UITextFieldView: View {
    let label: String
    @Binding var text: String
    let variant: String?
    var validationRegexp: String? = nil   // 新增
    var checksErrorMessage: String? = nil

    @Environment(\.a2uiStyle) private var style
    @FocusState private var isFocused: Bool

    static func regexpValidationMessage(value: String, pattern: String?) -> String? {
        guard let pattern, !pattern.isEmpty, !value.isEmpty else { return nil }
        let matched = (try? Regex(pattern).wholeMatch(in: value)) != nil
        return matched ? nil : "Invalid format"
    }

    static func displayedValidationMessage(
        checksErrorMessage: String?,
        value: String,
        pattern: String?
    ) -> String? {
        checksErrorMessage ?? regexpValidationMessage(value: value, pattern: pattern)
    }

    var body: some View {
        VStack(alignment: .leading) {
            fieldForVariant
                .focused($isFocused)

            if let msg = Self.displayedValidationMessage(
                checksErrorMessage: checksErrorMessage,
                value: text,
                pattern: validationRegexp
            ) {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(style.textFieldStyle.errorColor ?? .red)
            }
        }
    }
    // ... fieldForVariant 不变 ...
}
```

### 3. `A2UITextField.swift` — 传入参数

```swift
A2UITextFieldView(
    label: label,
    text: binding,
    variant: props.variant?.rawValue,
    validationRegexp: props.validationRegexp,   // 新增
    checksErrorMessage: checksError
)
```

## 非目标

- 不修改 v0.9 协议定义；协议里已有 `validationRegexp`，本改动只是补齐 Swift 实现。
- 不引入自定义错误文案协议字段；本次默认文案仍为 `"Invalid format"`，与 v0.8 保持一致。
- 不改变 `checks` 的求值模型、时机或消息来源。
- 不尝试推动 WebCore / Flutter 在同一变更里一起补 runtime regex 校验。

## 兼容性与风险

- **向后兼容**：未使用 `validationRegexp` 的现有 payload 行为完全不变。
- **协议兼容**：新增字段只发生在 Swift 本地解码模型中，对线上协议无 breaking change。
- **行为变化**：此前被静默放过的非法输入，在接入后会显示错误；这是预期修复，不是回归。
- **潜在风险**：若服务端下发非法正则，v0.9 Swift 将按 fail-closed 显示错误。该行为与 v0.8 一致，但需要在文档中明确写死，避免 reviewer 误以为应当静默忽略。

## 验收标准

实现完成后，需在 `Tests/A2UISwiftUITests/` 或 `Tests/A2UISwiftCoreTests/Validation/` 下新增单元测试，覆盖以下场景。可参考 `Tests/v_08Tests/TextFieldValidationTests.swift` 的结构，但 v0.9 测试应优先锚定上文提议的纯函数，而不是验证私有 View 状态。

### T1：字段解码

| # | 场景 | 输入 JSON | 预期 |
|---|------|-----------|------|
| 1.1 | 含 `validationRegexp` 的 TextFieldProperties 能正确解码 | `{"value":"","validationRegexp":"\\\\d+"}` | `props.validationRegexp == "\\d+"` |
| 1.2 | 不含 `validationRegexp` 的 TextFieldProperties 能正确解码 | `{"value":""}` | `props.validationRegexp == nil` |

### T2：空值放行

| # | 场景 | pattern | 输入值 | 预期 |
|---|------|---------|--------|------|
| 2.1 | pattern 为 nil | `nil` | `"hello"` | `regexpValidationMessage(...) == nil` |
| 2.2 | pattern 为空字符串 | `""` | `"hello"` | 通过 |
| 2.3 | 输入为空，有 pattern | `"\\d+"` | `""` | `regexpValidationMessage(...) == nil` |

### T3：全串匹配语义

| # | 场景 | pattern | 输入值 | 预期 |
|---|------|---------|--------|------|
| 3.1 | 完全匹配 | `"[a-z]+"` | `"hello"` | `regexpValidationMessage(...) == nil` |
| 3.2 | 完全不匹配 | `"[a-z]+"` | `"hello123"` | 返回 `"Invalid format"` |
| 3.3 | 子串包含但非全串（`firstMatch` 陷阱） | `"\\d+"` | `"abc123"` | 返回 `"Invalid format"` |

### T4：非法正则 fail-closed

| # | 场景 | pattern | 输入值 | 预期 |
|---|------|---------|--------|------|
| 4.1 | 正则格式有误 | `"[invalid"` | `"hello"` | 返回 `"Invalid format"`（不得静默忽略） |

### T5：`checks` 与 `validationRegexp` 优先级

| # | 场景 | 预期 |
|---|------|------|
| 5.1 | `checksErrorMessage` 非 nil，正则也失败 | `displayedValidationMessage(...)` 返回 `checksErrorMessage` |
| 5.2 | `checksErrorMessage` 为 nil，正则失败 | 返回 `"Invalid format"` |
| 5.3 | 两者均为 nil | 返回 `nil` |

### T6：接线完整性

| # | 场景 | 预期 |
|---|------|------|
| 6.1 | `TextFieldProperties` 增加字段后，`A2UITextField` 将其传入 `A2UITextFieldView` | 代码审查可见参数已透传 |
| 6.2 | `checksErrorMessage` 已存在场景不受影响 | 原有 `checks` 驱动错误展示逻辑保持不变 |

## 优先级

低。`validationRegexp` 是可选字段，大多数 agent 不使用它；`checks` 的 `regex` 函数已覆盖更灵活的校验场景，两者功能重叠。

不影响已有功能。实现后 Swift v0.9 将成为目前唯一在 v0.9 协议下有完整运行时 `validationRegexp` 校验的渲染器。

## 最终建议

这份文档在本次修订后，已经达到**可以准入**的标准，前提是 reviewer 认可两条设计约束：

- 采用与 v0.8 一致的 `wholeMatch + fail-closed` 语义。
- 先抽纯函数再接 UI，测试以纯逻辑为主，而不是以 SwiftUI 渲染细节为主。

如果这两点没有异议，我建议按该文档准入并进入实现。
