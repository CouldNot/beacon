import SwiftUI
import AppKit

// MARK: - Design system
//
// Central place for the shared visual language of the redesign: corner-radius
// and spacing scales, the primary accent gradient, and the translucent "glass
// card" surface used across every pane and sheet.
//
// The window background itself stays native (standard macOS material behind the
// SwiftUI content); these tokens only style the elements *inside* it. Everything
// resolves against the environment `colorScheme` so light and dark both look
// right without duplicated call sites.

enum DS {

    // MARK: Corner radii

    /// Corner-radius scale used throughout the UI. Names describe intent, not
    /// exact usage, so callers pick by role rather than hard-coding numbers.
    enum Radius {
        /// Small chips, inline badges, latency pills.
        static let chip: CGFloat = 6
        /// Compact controls and list-row insets.
        static let control: CGFloat = 8
        /// Default for rows and small cards.
        static let row: CGFloat = 9
        /// Grouped setting sections and medium cards.
        static let card: CGFloat = 11
        /// Prominent cards (status banner, sheet bodies).
        static let panel: CGFloat = 13
        /// Large containers and sheet outer frames.
        static let sheet: CGFloat = 18
    }

    // MARK: Spacing

    /// Spacing scale for padding and stack gaps. Keeps rhythm consistent.
    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 28
    }

    // MARK: Accent gradient

    /// Blue → purple accent used for primary/prominent actions and highlights.
    /// Mirrors the mockup's `linear-gradient(140deg, #74ADEF, #A98FE6)`.
    static let accentStart = Color(red: 0x74 / 255, green: 0xAD / 255, blue: 0xEF / 255)
    static let accentEnd   = Color(red: 0xA9 / 255, green: 0x8F / 255, blue: 0xE6 / 255)

    static let accentGradient = LinearGradient(
        colors: [accentStart, accentEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Solid mid-point of the accent gradient, for tints where a gradient can't
    /// be used (e.g. `.tint()` on system controls).
    static let accent = Color(red: 0x8F / 255, green: 0x9E / 255, blue: 0xEA / 255)
}

// MARK: - Glass card surface

extension View {
    /// The shared translucent "glass card" surface: a material fill clipped to a
    /// rounded rectangle, a hairline border, an inset top highlight, and a soft
    /// drop shadow. This is the single source of truth for card chrome so every
    /// pane, row, and sheet reads as the same physical material.
    ///
    /// - Parameters:
    ///   - radius: corner radius (default `DS.Radius.card`).
    ///   - material: the background material (default `.regularMaterial`).
    ///   - elevated: when true uses a stronger shadow for floating surfaces
    ///     (sheets, popovers); when false a subtle shadow for inline cards.
    func glassCard(
        radius: CGFloat = DS.Radius.card,
        material: Material = .regularMaterial,
        elevated: Bool = false
    ) -> some View {
        modifier(GlassCard(radius: radius, material: material, elevated: elevated))
    }
}

private struct GlassCard: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    let radius: CGFloat
    let material: Material
    let elevated: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .background(material, in: shape)
            .overlay {
                // Hairline border with a brighter inset highlight along the top
                // edge, matching the mockup's `inset 0 1px 0 rgba(255,255,255,…)`.
                shape.strokeBorder(borderGradient, lineWidth: 0.5)
            }
            .clipShape(shape)
            .shadow(
                color: .black.opacity(shadowOpacity),
                radius: elevated ? 18 : 6,
                x: 0,
                y: elevated ? 8 : 2
            )
    }

    private var borderGradient: LinearGradient {
        let top = Color.white.opacity(scheme == .dark ? 0.22 : 0.55)
        let hairline = Color.primary.opacity(scheme == .dark ? 0.16 : 0.10)
        return LinearGradient(
            colors: [top, hairline],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var shadowOpacity: Double {
        if elevated { return scheme == .dark ? 0.45 : 0.20 }
        return scheme == .dark ? 0.30 : 0.10
    }
}

// MARK: - Numeric / monospace styling

extension View {
    /// SF Mono styling for latency values, ports, byte counts, and log text, so
    /// numbers align and read as "data". Digits are monospaced even when the
    /// concrete font falls back on older systems.
    func monoNumeric(
        _ style: Font.TextStyle = .caption,
        weight: Font.Weight = .regular
    ) -> some View {
        font(.system(style, design: .monospaced).weight(weight))
            .monospacedDigit()
    }
}

// MARK: - Primary (accent-gradient) button

extension View {
    /// A prominent primary action rendered with the accent gradient. Use for the
    /// single most important button on a surface (Connect, Add Server, Save).
    /// Falls back gracefully by simply tinting on all supported systems.
    func accentGradientButton() -> some View {
        buttonStyle(AccentGradientButtonStyle())
    }
}

// MARK: - Behind-window vibrancy

/// A native `NSVisualEffectView` using behind-window blending, so the content
/// area samples the desktop wallpaper and reads as Liquid Glass - the same
/// vibrancy the sidebar gets for free. No custom gradients; this is the standard
/// macOS material.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blending
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blending
    }
}

/// Configures the hosting window for the seamless-glass shell: non-opaque with
/// a clear background so the vibrancy shows through, and a transparent
/// full-size titlebar so the single material runs to the very top edge with
/// only the traffic lights floating over it (Reeder-style).
struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { ConfiguringView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    /// Applies the window styling whenever the view lands in a window, so the
    /// settings survive window recreation (e.g. reopening from the menu bar).
    /// The traffic lights are left at their native position - the sidebar
    /// `List` reserves the titlebar space automatically.
    private final class ConfiguringView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)

            // Give the window a transparent unified toolbar. Even empty, this
            // makes the titlebar taller so the traffic lights sit lower and
            // more inset - the native source of Reeder's top breathing room -
            // without drawing any visible chrome over the shared material.
            let toolbar = NSToolbar()
            toolbar.showsBaselineSeparator = false
            window.toolbar = toolbar
            window.toolbarStyle = .unified

            // The tall titlebar's chrome hit-tests across the entire strip,
            // swallowing every click meant for the SwiftUI header underneath
            // (sidebar toggle, refresh, search). Install the pass-through so
            // only real titlebar controls keep their clicks.
            Self.installTitlebarPassThrough
        }

        /// There is no supported way to opt titlebar chrome out of hit
        /// testing, so give `NSTitlebarContainerView` a `hitTest` override
        /// that claims clicks only when they land on a real control (the
        /// traffic lights) and returns nil otherwise, letting the event fall
        /// through to the SwiftUI content that draws the floating header
        /// pills. The container is the theme frame's direct subview, so it -
        /// not the inner `NSTitlebarView` - is what must return nil for the
        /// frame to move on to the content view. If AppKit ever renames the
        /// class this simply does nothing and the strip stays inert rather
        /// than breaking.
        private static let installTitlebarPassThrough: Void = {
            let selector = #selector(NSView.hitTest(_:))
            guard let chromeClass = NSClassFromString("NSTitlebarContainerView"),
                  let method = class_getInstanceMethod(chromeClass, selector)
            else { return }

            typealias HitTest = @convention(c) (NSView, Selector, NSPoint) -> NSView?
            let inherited = unsafeBitCast(method_getImplementation(method), to: HitTest.self)

            let replacement: @convention(block) (NSView, NSPoint) -> NSView? = { view, point in
                guard let hit = inherited(view, selector, point) else { return nil }
                // hitTest is only ever called on the main thread.
                return MainActor.assumeIsolated {
                    var candidate: NSView? = hit
                    while let current = candidate, current !== view {
                        if current is NSControl { return hit }
                        candidate = current.superview
                    }
                    return nil
                }
            }
            let imp = imp_implementationWithBlock(replacement)
            // NSTitlebarContainerView inherits hitTest from NSView, so ADD an
            // override to the container class alone. Never replace the
            // inherited method in place - that would patch NSView.hitTest for
            // every view in the app. (`inherited` keeps calling the NSView
            // implementation, which is exactly the super behaviour the
            // override wants.)
            if !class_addMethod(chromeClass, selector, imp,
                                method_getTypeEncoding(method)) {
                // The class has its own hitTest (future macOS): patch that
                // one directly; `inherited` is then its own implementation.
                method_setImplementation(method, imp)
            }
        }()
    }
}

// MARK: - Primary (accent-gradient) button

private struct AccentGradientButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, DS.Space.lg)
            .padding(.vertical, DS.Space.sm)
            .background {
                Capsule(style: .continuous)
                    .fill(DS.accentGradient)
                    .overlay {
                        // Inset top highlight for the glassy sheen.
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5)
                    }
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
