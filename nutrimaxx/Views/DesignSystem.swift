import SwiftUI

/// Central palette and Liquid Glass building blocks used across the app.
enum Theme {
    static let accent = Color(red: 0.20, green: 0.82, blue: 0.51)   // fresh green
    static let accentBlue = Color(red: 0.04, green: 0.52, blue: 1.0)
    static let protein = Color.purple
    static let carbs = Color(red: 0.04, green: 0.52, blue: 1.0)
    static let fat = Color.orange

    static let cardShape = RoundedRectangle(cornerRadius: 24, style: .continuous)
    static let rowShape = RoundedRectangle(cornerRadius: 18, style: .continuous)
    static let pillShape = Capsule()
}

// MARK: - Screen background

/// Dark, subtly tinted gradient so the Liquid Glass surfaces have something to
/// refract. Applied behind every screen.
struct ScreenBackground: View {
    var body: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [Theme.accent.opacity(0.18), .clear],
                center: .topLeading, startRadius: 0, endRadius: 620)
            RadialGradient(
                colors: [Theme.accentBlue.opacity(0.16), .clear],
                center: .bottomTrailing, startRadius: 0, endRadius: 640)
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Places the shared background behind the content.
    func screenBackground() -> some View {
        background(ScreenBackground())
    }
}

// MARK: - Glass surfaces

/// A padded Liquid Glass card.
struct GlassCard<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: Theme.cardShape)
    }
}

/// A Liquid Glass row used for list items (tap target friendly).
struct GlassRow<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: Theme.rowShape)
    }
}

extension View {
    /// Wrap arbitrary content as a glass card in-place.
    func glassCard(padding: CGFloat = 18) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: Theme.cardShape)
    }
}

// MARK: - Search field

/// A Liquid Glass search field.
struct GlassSearchField: View {
    @Binding var text: String
    var placeholder: String = "Search"

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .glassEffect(.regular, in: Capsule())
    }
}

// MARK: - Empty state

/// Centered glass empty-state card.
struct EmptyStateCard: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.accent)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: Theme.cardShape)
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .tracking(1.2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
    }
}

// MARK: - Buttons

/// Prominent capsule action button on Liquid Glass.
struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.glassProminent)
        .tint(Theme.accent)
    }
}

/// A circular Liquid Glass icon button (used in headers / toolbars).
struct GlassIconButton: View {
    let systemName: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.glass)
    }
}
