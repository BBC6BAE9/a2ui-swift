# Generic View Dispatch — Zero AnyView Architecture

## 问题

当前 `A2UIComponentView` 使用 `AnyView` 来处理用户自定义组件：

```swift
// 旧方案：闭包存储 + 类型擦除，AnyView 泄露到公共 API
var registry: [String: (CatalogItemContext) -> AnyView]
```

`AnyView` 会破坏 SwiftUI 的 diff 算法，导致不必要的重建。

---

## 根本原因

`AnyView` 出现的原因只有一个：**想在运行时把不同类型的 View 放进同一个容器（字典/数组）存储**。

解法是：**不存储，只传递**。

把 `catalog` 作为泛型参数从顶层一路往下穿透 View 树，编译期类型始终已知，不需要擦除。

---

## 核心设计

```
不存储，只传递

A2UISurfaceView<Catalog>
    ↓ catalog 泛型穿透
A2UIComponentView<Catalog>
    ↓ catalog 泛型穿透
A2UIColumn<Catalog> / A2UIRow<Catalog> / A2UICard<Catalog> / ...
    ↓ catalog 泛型穿透
A2UIComponentView<Catalog>（递归）
    ↓ catalog 泛型穿透
A2UICustom<Catalog>          ← 在叶子直接调用 catalog.build(...)
```

---

## 实现

### 1. `CustomComponentCatalog` — 协议定义

```swift
// 框架定义协议（CustomComponentCatalog.swift）
public protocol CustomComponentCatalog {
    associatedtype Output: View   // 编译器从 @ViewBuilder 自动推断，无需手写

    @ViewBuilder @MainActor
    func build(typeName: String, node: ComponentNode, surface: SurfaceModel) -> Output
}

// 无自定义组件时的默认实现
public struct EmptyCustomCatalog: CustomComponentCatalog {
    public func build(typeName: String, node: ComponentNode, surface: SurfaceModel) -> some View {
        EmptyView()
    }
}
```

### 2. `A2UISurfaceView` — 泛型入口

```swift
public struct A2UISurfaceView<Catalog: CustomComponentCatalog>: View {
    let viewModel: SurfaceViewModel
    let catalog: Catalog

    public var body: some View {
        if let rootNode = viewModel.componentTree {
            ScrollView {
                A2UIComponentView(node: rootNode, surface: viewModel.surface, catalog: catalog)
                    .padding()
            }
        }
    }
}

// 无自定义组件时的便捷初始化
extension A2UISurfaceView where Catalog == EmptyCustomCatalog {
    public init(viewModel: SurfaceViewModel, onAction: ...) {
        self.init(viewModel: viewModel, catalog: EmptyCustomCatalog(), onAction: onAction)
    }
}
```

### 3. `A2UIComponentView` — 泛型分发

```swift
public struct A2UIComponentView<Catalog: CustomComponentCatalog>: View {
    let node: ComponentNode
    let surface: SurfaceModel
    let catalog: Catalog

    var body: some View {
        switch node.type {
        case .custom:
            // 自定义组件：直接传给 catalog，编译期类型已知，无 AnyView
            A2UICustom(node: node, surface: surface, catalog: catalog)

        // 内置组件：容器组件继续传递 catalog，叶子组件不需要
        case .Column:  A2UIColumn(node: node, surface: surface, catalog: catalog)
        case .Row:     A2UIRow(node: node, surface: surface, catalog: catalog)
        case .Text:    A2UIText(node: node, surface: surface)      // 叶子，无需泛型
        // ...
        }
    }
}
```

### 4. `A2UICustom` — 叶子调用 catalog

```swift
struct A2UICustom<Catalog: CustomComponentCatalog>: View {
    let node: ComponentNode
    let surface: SurfaceModel
    let catalog: Catalog

    var body: some View {
        let _ = node.instance  // 建立 @Observable 追踪
        if case .custom(let typeName) = node.type {
            let built = catalog.build(typeName: typeName, node: node, surface: surface)
            if built is EmptyView {
                // catalog 不认识此类型 → 降级渲染子节点
                VStack { ForEach(node.children) { A2UIComponentView(..., catalog: catalog) } }
            } else {
                built  // 直接返回，无 AnyView
            }
        }
    }
}
```

### 5. 容器组件 — catalog 往下传

```swift
struct A2UIColumn<Catalog: CustomComponentCatalog>: View {
    let node: ComponentNode
    let surface: SurfaceModel
    let catalog: Catalog

    var body: some View {
        VStack {
            ForEach(node.children) { child in
                A2UIComponentView(node: child, surface: surface, catalog: catalog)
            }
        }
    }
}
// A2UIRow, A2UICard, A2UIList, A2UITabs, A2UIModal, A2UIButton 同理
```

### 6. 叶子组件 — 不需要 catalog

```swift
// 叶子组件不渲染子节点，无需泛型
struct A2UIText: View {
    let node: ComponentNode
    let surface: SurfaceModel
    var body: some View { ... }
}
```

---

## 用户 API

### Swift 调用

```swift
// 有自定义组件
struct AppCatalog: CustomComponentCatalog {
    @ViewBuilder
    func build(typeName: String, node: ComponentNode, surface: SurfaceModel) -> some View {
        switch typeName {
        case "Chart":    MyChartView(node: node, surface: surface)
        case "Carousel": MyCarouselView(node: node, surface: surface)
        default:         EmptyView()
        }
    }
}

let catalog = AppCatalog()
A2UISurfaceView(viewModel: vm, catalog: catalog)

// 无自定义组件
A2UISurfaceView(viewModel: vm)
```

### Flutter 等价调用

```dart
final catalog = AppCatalog();
A2UISurfaceView(surface: surface, catalog: catalog)
```

**用户调用侧形式完全一致。**

编译器在调用处静态推断 `Catalog` 的具体类型，不需要任何类型擦除：

```
A2UISurfaceView<AppCatalog>
    A2UIComponentView<AppCatalog>
        A2UIColumn<AppCatalog>
            A2UIComponentView<AppCatalog>
                A2UICustom<AppCatalog>   ← catalog.build() 直接调用，类型已知
```

---

## 与旧方案对比

| | 旧方案（AnyView 闭包） | 新方案（CustomComponentCatalog 协议） |
|---|---|---|
| 内置组件 | `enum` + `@ViewBuilder switch` | 不变 |
| 用户自定义 API | `AnyView` 泄露到公共 API | `@ViewBuilder` 协议，用户侧无 `AnyView` |
| 内部存储 | `[String: (ctx) -> AnyView]` 字典 | 不存储，泛型穿透传递 |
| SwiftUI diff | `AnyView` 破坏 identity | 静态类型，diff 正常工作 |
| 编译器穷举检查 | ✅ | ✅ 不变 |
| 新增内置组件 | 3 处改动 | 3 处改动，不变 |
| 是否需要改框架 | 是（修改 registry） | 否（实现协议即可） |
| 命名类型 / 可测试 | ❌ 匿名闭包 | ✅ 具名 struct，可 mock |
| Flutter 调用形式一致 | ❌ | ✅ |

---

## 为什么 Protocol 而不是闭包

闭包方案（文档旧版）：

```swift
// 匿名，无法独立测试，无法复用，无法跨模块注入
A2UISurfaceView(viewModel: vm) { typeName, node, surface in
    switch typeName { ... }
}
```

Protocol 方案（当前实现）：

```swift
// 具名类型，可测试，可复用，可注入
let catalog = AppCatalog()
A2UISurfaceView(viewModel: vm, catalog: catalog)
```

两者的**类型系统机制完全相同**（PAT + 泛型穿透），但 Protocol 形式满足了谷歌工程师建议 #2 的架构语义：
- ✅ 有独立的 Catalog 抽象
- ✅ 开发者实现协议，不改框架核心
- ✅ 调用形式与 Flutter 一致

---

## 关键原则

**不存储，只传递。**

`AnyView` 出现的根本原因是试图把异构类型存进字典。`CustomComponentCatalog` 协议让 catalog 作为泛型参数在 View 树中向下传递，编译期类型始终确定，`AnyView` 自然消失。

`AnyCustomComponentCatalog`（类型擦除包装器）故意**没有**提供——一旦引入，为了存进 environment 就必须回到 `AnyView`，与本方案目标相悖。
