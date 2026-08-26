import SwiftUI

// MARK: - Skeletons

struct SkeletonView: View {
    var cornerRadius: CGFloat = Theme.Radius.standard

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 1.5) / 1.5
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.quaternary.opacity(0.5))
                .overlay(
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [.clear, .primary.opacity(0.08), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 0.6)
                        .offset(x: (geo.size.width * 1.6) * phase - geo.size.width * 0.6)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

struct SkeletonCardView: View {
    var size: CGFloat = Theme.Layout.cardSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SkeletonView().frame(width: size, height: size)
            SkeletonView(cornerRadius: 4).frame(width: size * 0.8, height: 12)
            SkeletonView(cornerRadius: 4).frame(width: size * 0.5, height: 10)
        }
    }
}

struct SkeletonShelf: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SkeletonView(cornerRadius: 4).frame(width: 120, height: 20)
            HStack(spacing: 16) {
                ForEach(0..<6, id: \.self) { _ in
                    SkeletonCardView()
                }
            }
        }
    }
}

// MARK: - Staggered entrance

private enum AnimationCache {
    nonisolated(unsafe) static var animated = Set<String>()

    static func hasAnimated(_ key: String) -> Bool { animated.contains(key) }

    static func markAnimated(_ key: String) {
        if animated.count > 600 { animated.removeAll() }
        animated.insert(key)
    }
}

struct StaggeredAppearanceModifier: ViewModifier {
    let index: Int
    var itemID: String

    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 16)
            .onAppear {
                if Platform.isReduceMotionEnabled
                    || AnimationCache.hasAnimated(itemID) {
                    isVisible = true
                    return
                }
                withAnimation(AppAnimation.snappy.delay(AppAnimation.stagger(for: index))) {
                    isVisible = true
                }
                AnimationCache.markAnimated(itemID)
            }
    }
}

extension View {
    func staggeredAppearance(index: Int, id: String) -> some View {
        modifier(StaggeredAppearanceModifier(index: index, itemID: id))
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: LocalizedStringKey
    var subtitle: String?
    var action: (() -> Void)?

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            if let action {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(title)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .offset(x: isHovering ? 2 : 0)
                    }
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(AppAnimation.quick) { isHovering = hovering }
                }
            } else {
                Text(title)
                    .font(.title2.weight(.semibold))
            }
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

// MARK: - Badges

struct PlayCountBadge: View {
    let count: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "play.fill")
                .font(.system(size: 8, weight: .bold))
            Text(Formatters.playCount(count))
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 3.5)
        .background(.black.opacity(0.35), in: Capsule())
        .background(.ultraThinMaterial.opacity(0.6), in: Capsule())
    }
}

struct VIPBadge: View {
    var body: some View {
        Text("VIP")
            .font(.system(size: 8.5, weight: .bold))
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Theme.accent.opacity(0.8), lineWidth: 1)
            )
    }
}

struct QualityTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .overlay(
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .stroke(Theme.accent.opacity(0.7), lineWidth: 1)
            )
    }
}

// MARK: - Hover play overlay

struct PlayOverlayButton: View {
    var visible: Bool
    var size: CGFloat = 40
    let action: () -> Void

    var body: some View {
        #if os(macOS)
        Button(action: action) {
            Image(systemName: "play.fill")
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Theme.accent.opacity(0.92), in: Circle())
                .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
        }
        .buttonStyle(.pressable)
        .opacity(visible ? 1 : 0)
        .scaleEffect(visible ? 1 : 0.7)
        .animation(AppAnimation.spring, value: visible)
        #else
        EmptyView()
        #endif
    }
}

// MARK: - Marquee

/// Scrolls text horizontally when it overflows, with faded edges.
struct MarqueeText: View {
    let text: String
    var font: Font = .system(size: 13, weight: .medium)

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var animating = false

    private var needsMarquee: Bool { textWidth > containerWidth + 1 }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 32) {
                marqueeLabel
                if needsMarquee {
                    marqueeLabel
                }
            }
            .offset(x: offset)
            .frame(maxHeight: .infinity, alignment: .leading)
            .onAppear { containerWidth = geo.size.width }
            .onChange(of: geo.size.width) { newValue in containerWidth = newValue }
        }
        .clipped()
        .mask(edgeFadeMask)
        .onChange(of: text) { _ in
            restart()
        }
        .onChange(of: needsMarquee) { _ in
            restart()
        }
        .background(
            Text(text)
                .font(font)
                .fixedSize()
                .hidden()
                .background(
                    GeometryReader { geo in
                        Color.clear.onAppear { textWidth = geo.size.width }
                            .onChange(of: geo.size.width) { newValue in textWidth = newValue }
                    }
                )
        )
    }

    private var marqueeLabel: some View {
        Text(text)
            .font(font)
            .lineLimit(1)
            .fixedSize()
    }

    private var edgeFadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: animating ? .clear : .black, location: 0),
                .init(color: .black, location: animating ? 0.06 : 0),
                .init(color: .black, location: needsMarquee ? 0.94 : 1),
                .init(color: needsMarquee ? .clear : .black, location: 1),
            ],
            startPoint: .leading, endPoint: .trailing
        )
    }

    private func restart() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            offset = 0
            animating = false
        }
        guard needsMarquee, !Platform.isReduceMotionEnabled else { return }
        let distance = textWidth + 32
        let duration = Double(distance) / 24
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            guard needsMarquee else { return }
            animating = true
            withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                offset = -distance
            }
        }
    }
}
