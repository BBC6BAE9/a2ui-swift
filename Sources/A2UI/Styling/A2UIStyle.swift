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

import SwiftUI

/// Global style context parsed from `beginRendering.styles`.
///
/// Override the default text appearance per variant using the view modifier:
///
/// ```swift
/// A2UIRendererView(manager: manager)
///     .a2uiTextStyle(for: .h1, font: .system(size: 48), weight: .black)
///     .a2uiTextStyle(for: .caption, font: .caption2, color: .gray)
/// ```
///
/// Or set the full style at once:
///
/// ```swift
/// A2UIRendererView(manager: manager)
///     .environment(\.a2uiStyle, A2UIStyle(primaryColor: .blue))
/// ```
public struct A2UIStyle: Equatable, Sendable {
    public var primaryColor: Color
    public var fontFamily: String?
    /// Per-variant overrides for Text component appearance.
    /// Prefer using the `.a2uiTextStyle(for:...)` view modifier over setting
    /// this directly.
    public var textStyles: [String: TextStyle]

    /// Appearance overrides for the Card component.
    public var cardStyle: CardStyle

    /// Per-variant overrides for Button component appearance.
    /// When a variant has an override, the framework switches to custom drawing
    /// instead of the default system ButtonStyle. When no override is set,
    /// the system ButtonStyle is used.
    public var buttonStyles: [String: ButtonVariantStyle]

    /// Appearance overrides for the TextField component.
    public var textFieldStyle: TextFieldComponentStyle

    /// Appearance overrides for the CheckBox component.
    public var checkBoxStyle: CheckBoxComponentStyle

    /// Appearance overrides for the MultipleChoice component.
    public var multipleChoiceStyle: MultipleChoiceComponentStyle

    /// Appearance overrides for the Slider component.
    public var sliderStyle: SliderComponentStyle

    /// Appearance overrides for the DateTimeInput component.
    public var dateTimeInputStyle: DateTimeInputComponentStyle

    /// Appearance overrides for the Tabs component.
    public var tabsStyle: TabsComponentStyle

    /// Appearance overrides for the Modal component.
    public var modalStyle: ModalComponentStyle

    /// Appearance overrides for the Video component.
    public var videoStyle: VideoComponentStyle

    /// Appearance overrides for the AudioPlayer component.
    public var audioPlayerStyle: AudioPlayerComponentStyle

    public init(
        primaryColor: Color = .accentColor,
        fontFamily: String? = nil,
        textStyles: [String: TextStyle] = [:],
        iconOverrides: [String: String] = [:],
        imageStyles: [String: ImageStyle] = [:],
        cardStyle: CardStyle = .init(),
        buttonStyles: [String: ButtonVariantStyle] = [:],
        textFieldStyle: TextFieldComponentStyle = .init(),
        checkBoxStyle: CheckBoxComponentStyle = .init(),
        multipleChoiceStyle: MultipleChoiceComponentStyle = .init(),
        sliderStyle: SliderComponentStyle = .init(),
        dateTimeInputStyle: DateTimeInputComponentStyle = .init(),
        tabsStyle: TabsComponentStyle = .init(),
        modalStyle: ModalComponentStyle = .init(),
        videoStyle: VideoComponentStyle = .init(),
        audioPlayerStyle: AudioPlayerComponentStyle = .init()
    ) {
        self.primaryColor = primaryColor
        self.fontFamily = fontFamily
        self.textStyles = textStyles
        self.iconOverrides = iconOverrides
        self.imageStyles = imageStyles
        self.cardStyle = cardStyle
        self.buttonStyles = buttonStyles
        self.textFieldStyle = textFieldStyle
        self.checkBoxStyle = checkBoxStyle
        self.multipleChoiceStyle = multipleChoiceStyle
        self.sliderStyle = sliderStyle
        self.dateTimeInputStyle = dateTimeInputStyle
        self.tabsStyle = tabsStyle
        self.modalStyle = modalStyle
        self.videoStyle = videoStyle
        self.audioPlayerStyle = audioPlayerStyle
    }

    /// Build from the raw `[String: String]` dictionary provided by `beginRendering`.
    public init(from styles: [String: String]) {
        if let hex = styles["primaryColor"] {
            self.primaryColor = Color(hex: hex)
        } else {
            self.primaryColor = .accentColor
        }
        self.fontFamily = styles["font"]
        self.textStyles = [:]
        self.iconOverrides = [:]
        self.imageStyles = [:]
        self.cardStyle = .init()
        self.buttonStyles = [:]
        self.checkBoxStyle = .init()
        self.multipleChoiceStyle = .init()
        self.textFieldStyle = .init()
        self.sliderStyle = .init()
        self.dateTimeInputStyle = .init()
        self.tabsStyle = .init()
        self.modalStyle = .init()
        self.videoStyle = .init()
        self.audioPlayerStyle = .init()
    }

    /// The seven text variants defined by the A2UI protocol.
    public enum TextVariant: String, CaseIterable, Sendable {
        case h1, h2, h3, h4, h5, body, caption
    }

    /// Appearance overrides for a single text variant.
    public struct TextStyle: Equatable, Sendable {
        public var font: Font?
        public var weight: Font.Weight?
        public var color: Color?

        public init(
            font: Font? = nil,
            weight: Font.Weight? = nil,
            color: Color? = nil
        ) {
            self.font = font
            self.weight = weight
            self.color = color
        }
    }

    // MARK: - Icon Styling

    /// Per-icon SF Symbol overrides. Keys are `IconName.rawValue` strings.
    /// Prefer using the `.a2uiIcon(_:systemName:)` view modifier over setting
    /// this directly.
    public var iconOverrides: [String: String]

    /// The 59 standard icon names defined by the A2UI basic catalog,
    /// with their default SF Symbol mappings.
    public enum IconName: String, CaseIterable, Sendable {
        case accountCircle
        case add
        case arrowBack
        case arrowForward
        case attachFile
        case calendarToday
        case call
        case camera
        case check
        case close
        case delete
        case download
        case edit
        case event
        case error
        case fastForward
        case favorite
        case favoriteOff
        case folder
        case help
        case home
        case info
        case locationOn
        case lock
        case lockOpen
        case mail
        case menu
        case moreVert
        case moreHoriz
        case notificationsOff
        case notifications
        case pause
        case payment
        case person
        case phone
        case photo
        case play
        case print
        case refresh
        case rewind
        case search
        case send
        case settings
        case share
        case shoppingCart
        case skipNext
        case skipPrevious
        case star
        case starHalf
        case starOff
        case stop
        case upload
        case visibility
        case visibilityOff
        case volumeDown
        case volumeMute
        case volumeOff
        case volumeUp
        case warning

        /// The default SF Symbol name for this icon.
        public var defaultSystemName: String {
            switch self {
            case .accountCircle:    return "person.circle"
            case .add:              return "plus"
            case .arrowBack:        return "chevron.left"
            case .arrowForward:     return "chevron.right"
            case .attachFile:       return "paperclip"
            case .calendarToday:    return "calendar"
            case .call:             return "phone"
            case .camera:           return "camera"
            case .check:            return "checkmark"
            case .close:            return "xmark"
            case .delete:           return "trash"
            case .download:         return "arrow.down.circle"
            case .edit:             return "pencil"
            case .event:            return "calendar.badge.clock"
            case .error:            return "exclamationmark.circle"
            case .fastForward:      return "forward"
            case .favorite:         return "heart.fill"
            case .favoriteOff:      return "heart"
            case .folder:           return "folder"
            case .help:             return "questionmark.circle"
            case .home:             return "house"
            case .info:             return "info.circle"
            case .locationOn:       return "mappin.and.ellipse"
            case .lock:             return "lock"
            case .lockOpen:         return "lock.open"
            case .mail:             return "envelope"
            case .menu:             return "line.3.horizontal"
            case .moreVert:         return "ellipsis"
            case .moreHoriz:        return "ellipsis"
            case .notificationsOff: return "bell.slash"
            case .notifications:    return "bell"
            case .pause:            return "pause"
            case .payment:          return "creditcard"
            case .person:           return "person"
            case .phone:            return "phone"
            case .photo:            return "photo"
            case .play:             return "play"
            case .print:            return "printer"
            case .refresh:          return "arrow.clockwise"
            case .rewind:           return "backward"
            case .search:           return "magnifyingglass"
            case .send:             return "paperplane"
            case .settings:         return "gearshape"
            case .share:            return "square.and.arrow.up"
            case .shoppingCart:     return "cart"
            case .skipNext:         return "forward.end"
            case .skipPrevious:     return "backward.end"
            case .star:             return "star.fill"
            case .starHalf:         return "star.leadinghalf.filled"
            case .starOff:          return "star"
            case .stop:             return "stop"
            case .upload:           return "arrow.up.circle"
            case .visibility:       return "eye"
            case .visibilityOff:    return "eye.slash"
            case .volumeDown:       return "speaker.wave.1"
            case .volumeMute:       return "speaker"
            case .volumeOff:        return "speaker.slash"
            case .volumeUp:         return "speaker.wave.3"
            case .warning:          return "exclamationmark.triangle"
            }
        }
    }

    /// Resolves the SF Symbol name for a given A2UI icon name string.
    public func sfSymbolName(for iconName: String) -> String {
        if let override = iconOverrides[iconName] {
            return override
        }
        if let known = IconName(rawValue: iconName) {
            return known.defaultSystemName
        }
        return "questionmark.diamond"
    }

    // MARK: - Image Styling

    /// Per-variant overrides for Image component appearance.
    /// Prefer using the `.a2uiImageStyle(for:...)` view modifier over setting
    /// this directly.
    public var imageStyles: [String: ImageStyle]

    /// The six image variants defined by the A2UI protocol.
    public enum ImageVariant: String, CaseIterable, Sendable {
        case icon, avatar, smallFeature, mediumFeature, largeFeature, header
    }

    /// Appearance overrides for a single image variant.
    public struct ImageStyle: Equatable, Sendable {
        public var width: CGFloat?
        public var height: CGFloat?
        public var cornerRadius: CGFloat?

        public init(
            width: CGFloat? = nil,
            height: CGFloat? = nil,
            cornerRadius: CGFloat? = nil
        ) {
            self.width = width
            self.height = height
            self.cornerRadius = cornerRadius
        }
    }

    // MARK: - Card Styling

    /// Appearance overrides for the Card container.
    ///
    /// All properties are optional. When `nil`, the Card uses system defaults:
    /// - `padding`: system `.padding()` (no explicit value — lets SwiftUI decide)
    /// - `cornerRadius`: system-appropriate continuous corner radius
    /// - `shadow*`: system-appropriate subtle shadow
    /// - `backgroundColor`: system `.background` ShapeStyle
    ///
    /// Set explicit values only when you need to override.
    public struct CardStyle: Equatable, Sendable {
        public var padding: CGFloat?
        public var cornerRadius: CGFloat?
        public var shadowRadius: CGFloat?
        public var shadowColor: Color?
        public var shadowY: CGFloat?
        public var backgroundColor: Color?

        public init(
            padding: CGFloat? = nil,
            cornerRadius: CGFloat? = nil,
            shadowRadius: CGFloat? = nil,
            shadowColor: Color? = nil,
            shadowY: CGFloat? = nil,
            backgroundColor: Color? = nil
        ) {
            self.padding = padding
            self.cornerRadius = cornerRadius
            self.shadowRadius = shadowRadius
            self.shadowColor = shadowColor
            self.shadowY = shadowY
            self.backgroundColor = backgroundColor
        }
    }

    // MARK: - TextField Styling

    /// Appearance overrides for the TextField component.
    /// All properties optional — `nil` means use system defaults.
    public struct TextFieldComponentStyle: Equatable, Sendable {
        /// Minimum height for `longText` (TextEditor). Nil → system default.
        public var longTextMinHeight: CGFloat?
        /// Background for `longText`. Nil → system `.fill.quaternary`.
        public var longTextBackgroundColor: Color?
        /// Error message color. Nil → system `.red`.
        public var errorColor: Color?

        public init(
            longTextMinHeight: CGFloat? = nil,
            longTextBackgroundColor: Color? = nil,
            errorColor: Color? = nil
        ) {
            self.longTextMinHeight = longTextMinHeight
            self.longTextBackgroundColor = longTextBackgroundColor
            self.errorColor = errorColor
        }
    }

    // MARK: - CheckBox Styling

    /// Appearance overrides for the CheckBox (Toggle) component.
    public struct CheckBoxComponentStyle: Equatable, Sendable {
        public var tintColor: Color?
        public var labelFont: Font?
        public var labelColor: Color?

        public init(
            tintColor: Color? = nil,
            labelFont: Font? = nil,
            labelColor: Color? = nil
        ) {
            self.tintColor = tintColor
            self.labelFont = labelFont
            self.labelColor = labelColor
        }
    }

    // MARK: - MultipleChoice Styling

    /// Appearance overrides for the MultipleChoice component.
    /// All properties optional — `nil` means use system defaults.
    public struct MultipleChoiceComponentStyle: Equatable, Sendable {
        /// Font for the description label above the choices.
        public var descriptionFont: Font?
        /// Color for the description label.
        public var descriptionColor: Color?
        /// Tint color for selected chips and checkmarks.
        public var tintColor: Color?

        public init(
            descriptionFont: Font? = nil,
            descriptionColor: Color? = nil,
            tintColor: Color? = nil
        ) {
            self.descriptionFont = descriptionFont
            self.descriptionColor = descriptionColor
            self.tintColor = tintColor
        }
    }

    // MARK: - Tabs Styling

    /// Appearance overrides for the Tabs component.
    public struct TabsComponentStyle: Equatable, Sendable {
        /// Color of the selected tab text and indicator.
        public var selectedColor: Color?
        /// Color of unselected tab text.
        public var unselectedColor: Color?
        /// Font for tab titles.
        public var titleFont: Font?

        public init(
            selectedColor: Color? = nil,
            unselectedColor: Color? = nil,
            titleFont: Font? = nil
        ) {
            self.selectedColor = selectedColor
            self.unselectedColor = unselectedColor
            self.titleFont = titleFont
        }
    }

    // MARK: - Modal Styling

    /// Appearance overrides for the Modal component.
    public struct ModalComponentStyle: Equatable, Sendable {
        /// Whether to show the close button inside the modal. `nil` = show (system default).
        public var showCloseButton: Bool?
        /// Padding around the modal content.
        public var contentPadding: CGFloat?

        public init(
            showCloseButton: Bool? = nil,
            contentPadding: CGFloat? = nil
        ) {
            self.showCloseButton = showCloseButton
            self.contentPadding = contentPadding
        }
    }

    // MARK: - Video Styling

    /// Appearance overrides for the Video component.
    public struct VideoComponentStyle: Equatable, Sendable {
        /// Corner radius for the video player.
        public var cornerRadius: CGFloat?

        public init(cornerRadius: CGFloat? = nil) {
            self.cornerRadius = cornerRadius
        }
    }

    // MARK: - AudioPlayer Styling

    /// Appearance overrides for the AudioPlayer component.
    public struct AudioPlayerComponentStyle: Equatable, Sendable {
        /// Tint color for the play button and progress slider.
        public var tintColor: Color?
        /// Font for the description label.
        public var labelFont: Font?
        /// Corner radius for the container.
        public var cornerRadius: CGFloat?

        public init(
            tintColor: Color? = nil,
            labelFont: Font? = nil,
            cornerRadius: CGFloat? = nil
        ) {
            self.tintColor = tintColor
            self.labelFont = labelFont
            self.cornerRadius = cornerRadius
        }
    }

    // MARK: - DateTimeInput Styling

    /// Appearance overrides for the DateTimeInput component.
    public struct DateTimeInputComponentStyle: Equatable, Sendable {
        /// Tint color for the date picker.
        public var tintColor: Color?
        /// Font for the label text.
        public var labelFont: Font?
        /// Color for the label text.
        public var labelColor: Color?

        public init(
            tintColor: Color? = nil,
            labelFont: Font? = nil,
            labelColor: Color? = nil
        ) {
            self.tintColor = tintColor
            self.labelFont = labelFont
            self.labelColor = labelColor
        }
    }

    // MARK: - Slider Styling

    /// Appearance overrides for the Slider component.
    public struct SliderComponentStyle: Equatable, Sendable {
        public var tintColor: Color?
        public var labelFont: Font?
        public var labelColor: Color?
        public var valueFont: Font?
        public var valueColor: Color?
        public var valueFormatter: @Sendable (Double) -> String

        public init(
            tintColor: Color? = nil,
            labelFont: Font? = nil,
            labelColor: Color? = nil,
            valueFont: Font? = nil,
            valueColor: Color? = nil,
            valueFormatter: @escaping @Sendable (Double) -> String = {
                $0.truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f", $0)
                    : String(format: "%.1f", $0)
            }
        ) {
            self.tintColor = tintColor
            self.labelFont = labelFont
            self.labelColor = labelColor
            self.valueFont = valueFont
            self.valueColor = valueColor
            self.valueFormatter = valueFormatter
        }

        public static func == (lhs: SliderComponentStyle, rhs: SliderComponentStyle) -> Bool {
            lhs.tintColor == rhs.tintColor
            && lhs.labelFont == rhs.labelFont
            && lhs.labelColor == rhs.labelColor
            && lhs.valueFont == rhs.valueFont
            && lhs.valueColor == rhs.valueColor
        }
    }

    // MARK: - Button Styling

    /// The three button variants defined by the A2UI protocol.
    public enum ButtonVariant: String, CaseIterable, Sendable {
        case primary
        case borderless
        /// The default style when no variant is specified.
        case `default`
    }

    /// Appearance overrides for a single button variant.
    public struct ButtonVariantStyle: Equatable, Sendable {
        public var foregroundColor: Color?
        public var backgroundColor: Color?
        public var cornerRadius: CGFloat?
        public var horizontalPadding: CGFloat?
        public var verticalPadding: CGFloat?

        public init(
            foregroundColor: Color? = nil,
            backgroundColor: Color? = nil,
            cornerRadius: CGFloat? = nil,
            horizontalPadding: CGFloat? = nil,
            verticalPadding: CGFloat? = nil
        ) {
            self.foregroundColor = foregroundColor
            self.backgroundColor = backgroundColor
            self.cornerRadius = cornerRadius
            self.horizontalPadding = horizontalPadding
            self.verticalPadding = verticalPadding
        }
    }
}

// MARK: - Client Error

/// Describes a client-side error that should be reported back to the agent.
public struct A2UIClientError: Error, Sendable {
    public enum Kind: String, Sendable {
        case unknownComponent
        case dataBindingFailed
        case decodingFailed
        case other
    }

    public let kind: Kind
    public let message: String
    public let componentId: String?
    public let surfaceId: String?

    public init(
        kind: Kind,
        message: String,
        componentId: String? = nil,
        surfaceId: String? = nil
    ) {
        self.kind = kind
        self.message = message
        self.componentId = componentId
        self.surfaceId = surfaceId
    }
}

// MARK: - SwiftUI Environment

private struct A2UIStyleKey: EnvironmentKey {
    static let defaultValue = A2UIStyle()
}

private struct A2UIActionHandlerKey: EnvironmentKey {
    static let defaultValue: ((ResolvedAction) -> Void)? = nil
}

extension EnvironmentValues {
    public var a2uiStyle: A2UIStyle {
        get { self[A2UIStyleKey.self] }
        set { self[A2UIStyleKey.self] = newValue }
    }

    public var a2uiActionHandler: ((ResolvedAction) -> Void)? {
        get { self[A2UIActionHandlerKey.self] }
        set { self[A2UIActionHandlerKey.self] = newValue }
    }
}

// MARK: - View Modifier API

extension View {
    /// Override the appearance of a specific A2UI text variant.
    ///
    /// ```swift
    /// A2UIRendererView(manager: manager)
    ///     .a2uiTextStyle(for: .h1, font: .system(size: 48), weight: .black)
    ///     .a2uiTextStyle(for: .caption, font: .caption2, color: .gray)
    /// ```
    ///
    /// Only the properties you specify are overridden; the rest fall back to
    /// built-in defaults. Multiple calls compose naturally — each one adds or
    /// replaces the override for that variant.
    public func a2uiTextStyle(
        for variant: A2UIStyle.TextVariant,
        font: Font? = nil,
        weight: Font.Weight? = nil,
        color: Color? = nil
    ) -> some View {
        self.transformEnvironment(\.a2uiStyle) { style in
            var existing = style.textStyles[variant.rawValue] ?? .init()
            if let font { existing.font = font }
            if let weight { existing.weight = weight }
            if let color { existing.color = color }
            style.textStyles[variant.rawValue] = existing
        }
    }

    /// Override the SF Symbol used for a specific A2UI icon name.
    ///
    /// ```swift
    /// A2UIRendererView(manager: manager)
    ///     .a2uiIcon(.home, systemName: "house.fill")
    ///     .a2uiIcon(.search, systemName: "doc.text.magnifyingglass")
    /// ```
    ///
    /// You can also pass a raw icon name string for any custom icon names
    /// not in the standard A2UI catalog:
    ///
    /// ```swift
    /// .a2uiIcon("customIcon", systemName: "star.circle")
    /// ```
    public func a2uiIcon(
        _ icon: A2UIStyle.IconName,
        systemName: String
    ) -> some View {
        a2uiIcon(icon.rawValue, systemName: systemName)
    }

    /// Override the SF Symbol used for a raw A2UI icon name string.
    public func a2uiIcon(
        _ iconName: String,
        systemName: String
    ) -> some View {
        self.transformEnvironment(\.a2uiStyle) { style in
            style.iconOverrides[iconName] = systemName
        }
    }

    /// Override the appearance of a specific A2UI button variant.
    ///
    /// ```swift
    /// A2UIRendererView(manager: manager)
    ///     .a2uiButtonStyle(for: .primary, backgroundColor: .blue, cornerRadius: 12)
    ///     .a2uiButtonStyle(for: .borderless, foregroundColor: .red)
    ///     .a2uiButtonStyle(for: .default, backgroundColor: .gray.opacity(0.2))
    /// ```
    ///
    /// Only the properties you specify are overridden; the rest fall back to
    /// built-in defaults. Multiple calls compose naturally.
    public func a2uiButtonStyle(
        for variant: A2UIStyle.ButtonVariant,
        foregroundColor: Color? = nil,
        backgroundColor: Color? = nil,
        cornerRadius: CGFloat? = nil,
        horizontalPadding: CGFloat? = nil,
        verticalPadding: CGFloat? = nil
    ) -> some View {
        self.transformEnvironment(\.a2uiStyle) { style in
            var existing = style.buttonStyles[variant.rawValue] ?? .init()
            if let foregroundColor { existing.foregroundColor = foregroundColor }
            if let backgroundColor { existing.backgroundColor = backgroundColor }
            if let cornerRadius { existing.cornerRadius = cornerRadius }
            if let horizontalPadding { existing.horizontalPadding = horizontalPadding }
            if let verticalPadding { existing.verticalPadding = verticalPadding }
            style.buttonStyles[variant.rawValue] = existing
        }
    }

    /// Override the appearance of the A2UI TextField component.
    ///
    /// ```swift
    /// A2UIRendererView(manager: manager)
    ///     .a2uiTextFieldStyle(longTextMinHeight: 150, errorColor: .orange)
    /// ```
    public func a2uiTextFieldStyle(
        longTextMinHeight: CGFloat? = nil,
        longTextBackgroundColor: Color? = nil,
        errorColor: Color? = nil
    ) -> some View {
        self.transformEnvironment(\.a2uiStyle) { style in
            if let longTextMinHeight { style.textFieldStyle.longTextMinHeight = longTextMinHeight }
            if let longTextBackgroundColor { style.textFieldStyle.longTextBackgroundColor = longTextBackgroundColor }
            if let errorColor { style.textFieldStyle.errorColor = errorColor }
        }
    }

    /// Override the appearance of the A2UI CheckBox (Toggle) component.
    ///
    /// ```swift
    /// A2UIRendererView(manager: manager)
    ///     .a2uiCheckBoxStyle(tintColor: .green, labelFont: .headline)
    /// ```
    public func a2uiCheckBoxStyle(
        tintColor: Color? = nil,
        labelFont: Font? = nil,
        labelColor: Color? = nil
    ) -> some View {
        self.transformEnvironment(\.a2uiStyle) { style in
            if let tintColor { style.checkBoxStyle.tintColor = tintColor }
            if let labelFont { style.checkBoxStyle.labelFont = labelFont }
            if let labelColor { style.checkBoxStyle.labelColor = labelColor }
        }
    }

    /// Override the appearance of the A2UI MultipleChoice component.
    ///
    /// ```swift
    /// A2UIRendererView(manager: manager)
    ///     .a2uiMultipleChoiceStyle(tintColor: .purple, descriptionFont: .headline)
    /// ```
    public func a2uiMultipleChoiceStyle(
        descriptionFont: Font? = nil,
        descriptionColor: Color? = nil,
        tintColor: Color? = nil
    ) -> some View {
        self.transformEnvironment(\.a2uiStyle) { style in
            if let descriptionFont { style.multipleChoiceStyle.descriptionFont = descriptionFont }
            if let descriptionColor { style.multipleChoiceStyle.descriptionColor = descriptionColor }
            if let tintColor { style.multipleChoiceStyle.tintColor = tintColor }
        }
    }

    /// Override the appearance of the A2UI Slider component.
    ///
    /// ```swift
    /// A2UIRendererView(manager: manager)
    ///     .a2uiSliderStyle(tintColor: .orange, valueFormatter: { "\(Int($0))%" })
    /// ```
    public func a2uiSliderStyle(
        tintColor: Color? = nil,
        labelFont: Font? = nil,
        labelColor: Color? = nil,
        valueFont: Font? = nil,
        valueColor: Color? = nil,
        valueFormatter: (@Sendable (Double) -> String)? = nil
    ) -> some View {
        self.transformEnvironment(\.a2uiStyle) { style in
            if let tintColor { style.sliderStyle.tintColor = tintColor }
            if let labelFont { style.sliderStyle.labelFont = labelFont }
            if let labelColor { style.sliderStyle.labelColor = labelColor }
            if let valueFont { style.sliderStyle.valueFont = valueFont }
            if let valueColor { style.sliderStyle.valueColor = valueColor }
            if let valueFormatter { style.sliderStyle.valueFormatter = valueFormatter }
        }
    }

    /// Override the appearance of the A2UI DateTimeInput component.
    ///
    /// ```swift
    /// A2UIRendererView(manager: manager)
    ///     .a2uiDateTimeInputStyle(tintColor: .blue, labelFont: .headline)
    /// ```
    public func a2uiDateTimeInputStyle(
        tintColor: Color? = nil,
        labelFont: Font? = nil,
        labelColor: Color? = nil
    ) -> some View {
        self.transformEnvironment(\.a2uiStyle) { style in
            if let tintColor { style.dateTimeInputStyle.tintColor = tintColor }
            if let labelFont { style.dateTimeInputStyle.labelFont = labelFont }
            if let labelColor { style.dateTimeInputStyle.labelColor = labelColor }
        }
    }

    /// Override the appearance of the A2UI Tabs component.
    ///
    /// ```swift
    /// A2UIRendererView(manager: manager)
    ///     .a2uiTabsStyle(selectedColor: .blue, titleFont: .headline)
    /// ```
    public func a2uiTabsStyle(
        selectedColor: Color? = nil,
        unselectedColor: Color? = nil,
        titleFont: Font? = nil
    ) -> some View {
        self.transformEnvironment(\.a2uiStyle) { style in
            if let selectedColor { style.tabsStyle.selectedColor = selectedColor }
            if let unselectedColor { style.tabsStyle.unselectedColor = unselectedColor }
            if let titleFont { style.tabsStyle.titleFont = titleFont }
        }
    }

    /// Override the appearance of the A2UI Modal component.
    ///
    /// ```swift
    /// A2UIRendererView(manager: manager)
    ///     .a2uiModalStyle(showCloseButton: true, contentPadding: 20)
    /// ```
    public func a2uiModalStyle(
        showCloseButton: Bool? = nil,
        contentPadding: CGFloat? = nil
    ) -> some View {
        self.transformEnvironment(\.a2uiStyle) { style in
            if let showCloseButton { style.modalStyle.showCloseButton = showCloseButton }
            if let contentPadding { style.modalStyle.contentPadding = contentPadding }
        }
    }

    /// Override the appearance of the A2UI Video component.
    ///
    /// ```swift
    /// A2UIRendererView(manager: manager)
    ///     .a2uiVideoStyle(cornerRadius: 12)
    /// ```
    public func a2uiVideoStyle(
        cornerRadius: CGFloat? = nil
    ) -> some View {
        self.transformEnvironment(\.a2uiStyle) { style in
            if let cornerRadius { style.videoStyle.cornerRadius = cornerRadius }
        }
    }

    /// Override the appearance of the A2UI AudioPlayer component.
    ///
    /// ```swift
    /// A2UIRendererView(manager: manager)
    ///     .a2uiAudioPlayerStyle(tintColor: .purple, cornerRadius: 12)
    /// ```
    public func a2uiAudioPlayerStyle(
        tintColor: Color? = nil,
        labelFont: Font? = nil,
        cornerRadius: CGFloat? = nil
    ) -> some View {
        self.transformEnvironment(\.a2uiStyle) { style in
            if let tintColor { style.audioPlayerStyle.tintColor = tintColor }
            if let labelFont { style.audioPlayerStyle.labelFont = labelFont }
            if let cornerRadius { style.audioPlayerStyle.cornerRadius = cornerRadius }
        }
    }

    /// Override the appearance of the A2UI Card container.
    ///
    /// ```swift
    /// A2UIRendererView(manager: manager)
    ///     .a2uiCardStyle(cornerRadius: 16, shadowRadius: 8)
    /// ```
    ///
    /// Only the properties you specify are overridden; the rest fall back to
    /// built-in defaults.
    public func a2uiCardStyle(
        padding: CGFloat? = nil,
        cornerRadius: CGFloat? = nil,
        shadowRadius: CGFloat? = nil,
        shadowColor: Color? = nil,
        shadowY: CGFloat? = nil,
        backgroundColor: Color? = nil
    ) -> some View {
        self.transformEnvironment(\.a2uiStyle) { style in
            if let padding { style.cardStyle.padding = padding }
            if let cornerRadius { style.cardStyle.cornerRadius = cornerRadius }
            if let shadowRadius { style.cardStyle.shadowRadius = shadowRadius }
            if let shadowColor { style.cardStyle.shadowColor = shadowColor }
            if let shadowY { style.cardStyle.shadowY = shadowY }
            if let backgroundColor { style.cardStyle.backgroundColor = backgroundColor }
        }
    }

    /// Override the appearance of a specific A2UI image variant.
    ///
    /// ```swift
    /// A2UIRendererView(manager: manager)
    ///     .a2uiImageStyle(for: .avatar, width: 48, height: 48, cornerRadius: 24)
    ///     .a2uiImageStyle(for: .header, height: 300)
    /// ```
    ///
    /// Only the properties you specify are overridden; the rest fall back to
    /// built-in defaults. Multiple calls compose naturally.
    public func a2uiImageStyle(
        for variant: A2UIStyle.ImageVariant,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        cornerRadius: CGFloat? = nil
    ) -> some View {
        self.transformEnvironment(\.a2uiStyle) { style in
            var existing = style.imageStyles[variant.rawValue] ?? .init()
            if let width { existing.width = width }
            if let height { existing.height = height }
            if let cornerRadius { existing.cornerRadius = cornerRadius }
            style.imageStyles[variant.rawValue] = existing
        }
    }
}

// MARK: - Color Hex Initializer

extension Color {
    /// Create a `Color` from a hex string like `#FF5722` or `FF5722`.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        guard cleaned.count == 6,
              let value = UInt64(cleaned, radix: 16) else {
            self = .accentColor
            return
        }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

}
