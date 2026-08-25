import SwiftUI

/// Immersive full-window now-playing page: artwork-tinted gradient backdrop,
/// large artwork on the left, big synced lyrics on the right.
struct NowPlayingView: View {
    @Environment(PlayerService.self) private var player
    @Environment(AccountStore.self) private var account
    @Environment(SettingsManager.self) private var settings

    @State private var artworkImage: PlatformImage?
    @State private var colors: ArtworkColors = .fallback
    @State private var activeIndex: Int?
    @State private var isUserScrolling = false
    @State private var resumeTask: Task<Void, Never>?
    @State private var showLyricsOnMobile = false

    var body: some View {
        GeometryReader { geo in
            let isCompact = geo.size.width < 720
            ZStack {
                backdrop

                if isCompact {
                    compactLayout(size: geo.size)
                } else {
                    regularLayout(size: geo.size)
                }
            }
            .overlay(alignment: .topLeading) {
                Button {
                    close()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.pressable)
                .padding(.top, 16)
                .padding(.leading, 20)
            }
            .overlay(alignment: .topTrailing) {
                if isCompact {
                    Button {
                        withAnimation(AppAnimation.standard) {
                            showLyricsOnMobile.toggle()
                        }
                    } label: {
                        Image(systemName: showLyricsOnMobile ? "music.note" : "quote.bubble")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(showLyricsOnMobile ? Theme.accent : .white.opacity(0.85))
                            .frame(width: 36, height: 36)
                            .background(.white.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.pressable)
                    .padding(.top, 16)
                    .padding(.trailing, 20)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task(id: player.currentTrack?.id) {
            await loadArtwork()
        }
        #if os(macOS)
        .onExitCommand {
            close()
        }
        #endif
    }

    private var hasLyricsColumn: Bool {
        if let lyrics = player.lyrics, !lyrics.isEmpty { return true }
        return player.lyrics == nil // still loading — keep layout stable
    }

    private func close() {
        player.showNowPlaying = false
    }

    // MARK: - Backdrop

    private var backdrop: some View {
        ZStack {
            LinearGradient(
                colors: [colors.primary, colors.secondary],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [.white.opacity(0.12), .clear],
                center: .topLeading, startRadius: 0, endRadius: 700
            )
            LinearGradient(
                colors: [.clear, .black.opacity(0.35)],
                startPoint: .top, endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.8), value: colors)
    }

    private func loadArtwork() async {
        guard let urlString = player.currentTrack?.album.picUrl,
              let url = urlString.resizedImageURL(768) else {
            artworkImage = nil
            colors = .fallback
            return
        }
        if let image = await ImageCache.shared.image(for: url) {
            artworkImage = image
            colors = ArtworkPalette.extract(from: image, cacheKey: urlString)
        }
    }

    // MARK: - Layouts

    private func regularLayout(size: CGSize) -> some View {
        // Everything below the artwork needs ~300pt; shrink the artwork on
        // short displays (iPhone landscape) instead of clipping it.
        let artworkSize = max(120, min(340, size.width * 0.32, size.height - 300))
        return HStack(spacing: 0) {
            leftColumn(artworkSize: artworkSize)
                .frame(maxWidth: .infinity)
            if hasLyricsColumn {
                lyricsColumn
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 48)
        .padding(.vertical, size.height < 500 ? 24 : 40)
    }

    private func compactLayout(size: CGSize) -> some View {
        let artworkDim = min(size.width - 64, size.height * 0.38, 300)
        return VStack(spacing: 20) {
            Spacer().frame(height: 44)
            if showLyricsOnMobile {
                lyricsColumn
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
            } else {
                VStack(spacing: 20) {
                    artworkView(size: artworkDim)
                    trackMetaView
                    MiniLyricsView {
                        withAnimation(AppAnimation.standard) {
                            showLyricsOnMobile = true
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .transition(.opacity)
            }
            VStack(spacing: 12) {
                NowPlayingScrubber()
                    .padding(.horizontal, 24)
                controls
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Views

    private func artworkView(size: CGFloat) -> some View {
        Group {
            if let artworkImage {
                Image(platformImage: artworkImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(.white.opacity(0.06))
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(.white.opacity(0.3))
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.45), radius: 36, y: 18)
        .scaleEffect(player.isPlaying ? 1 : 0.95)
        .animation(AppAnimation.bouncy, value: player.isPlaying)
    }

    private var trackMetaView: some View {
        VStack(spacing: 5) {
            HStack(spacing: 8) {
                Text(player.currentTrack?.name ?? "")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if player.currentTrack?.fee == 1 {
                    VIPBadge()
                }
            }
            Text("\(player.currentTrack?.artistNames ?? "") — \(player.currentTrack?.album.name ?? "")")
                .font(.system(size: 13.5))
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)
        }
        .frame(maxWidth: 400)
    }

    private func leftColumn(artworkSize: CGFloat) -> some View {
        VStack(spacing: 26) {
            Spacer()

            artworkView(size: artworkSize)
            trackMetaView

            VStack(spacing: 14) {
                NowPlayingScrubber()
                    .frame(maxWidth: 380)
                controls
            }

            Spacer()
        }
        .padding(.trailing, hasLyricsColumn ? 30 : 0)
    }

    private var controls: some View {
        HStack(spacing: 22) {
            if let track = player.currentTrack {
                let liked = account.isLiked(track.id)
                circleButton(
                    icon: liked ? "heart.fill" : "heart",
                    size: 15, tint: liked ? Theme.accent : nil
                ) {
                    Task { await account.toggleLike(trackID: track.id) }
                }
            }

            if player.isFMMode {
                circleButton(icon: "trash", size: 14) {
                    player.fmTrash()
                }
            } else {
                circleButton(
                    icon: "shuffle", size: 14,
                    tint: player.shuffleEnabled ? Theme.accent : nil
                ) {
                    player.toggleShuffle()
                }
                circleButton(icon: "backward.fill", size: 16) {
                    player.previous()
                }
            }

            Button {
                player.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 58, height: 58)
                        .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(.black.opacity(0.85))
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .buttonStyle(.pressable)

            circleButton(icon: "forward.fill", size: 16) {
                player.next()
            }

            if player.isFMMode {
                Image(systemName: "wave.3.right.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 40, height: 40)
            } else {
                circleButton(
                    icon: player.repeatMode == .one ? "repeat.1" : "repeat",
                    size: 14,
                    tint: player.repeatMode != .off ? Theme.accent : nil
                ) {
                    player.cycleRepeatMode()
                }
            }
        }
    }

    private func circleButton(icon: String, size: CGFloat,
                              tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(tint ?? .white.opacity(0.8))
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.1), in: Circle())
        }
        .buttonStyle(.pressable)
    }

    // MARK: - Lyrics column

    @ViewBuilder
    private var lyricsColumn: some View {
        if let lyrics = player.lyrics, !lyrics.isEmpty {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 26) {
                        Color.clear.frame(height: 200)
                        ForEach(lyrics.lines) { line in
                            bigLyricLine(line, isActive: line.id == activeIndex)
                                .id(line.id)
                        }
                        Color.clear.frame(height: 240)
                    }
                    .padding(.horizontal, 24)
                }
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.12),
                            .init(color: .black, location: 0.85),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .onChange(of: player.progress) {
                    let index = lyrics.activeIndex(at: player.progress + 0.2)
                    guard index != activeIndex else { return }
                    activeIndex = index
                    guard !isUserScrolling, let index else { return }
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) {
                        proxy.scrollTo(index, anchor: .center)
                    }
                }
                .onChange(of: player.currentTrack?.id) {
                    activeIndex = nil
                }
                .simultaneousGesture(
                    DragGesture().onChanged { _ in
                        isUserScrolling = true
                        resumeTask?.cancel()
                        resumeTask = Task {
                            try? await Task.sleep(for: .seconds(3))
                            guard !Task.isCancelled else { return }
                            isUserScrolling = false
                        }
                    }
                )
            }
        } else if player.lyrics?.isInstrumental == true {
            VStack(spacing: 10) {
                Image(systemName: "music.quarternote.3")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.white.opacity(0.4))
                Text("纯音乐，请欣赏")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ProgressView()
                .controlSize(.small)
                .tint(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func bigLyricLine(_ line: LyricLine, isActive: Bool) -> some View {
        Button {
            player.seek(to: line.time)
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(line.text.isEmpty ? "♪" : line.text)
                    .font(.system(size: isActive ? 26 : 20, weight: isActive ? .bold : .semibold))
                    .foregroundStyle(.white.opacity(isActive ? 1 : 0.45))
                if settings.showLyricsTranslation, let translation = line.translation {
                    Text(translation)
                        .font(.system(size: isActive ? 16 : 14, weight: .medium))
                        .foregroundStyle(.white.opacity(isActive ? 0.7 : 0.35))
                }
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .blur(radius: isActive ? 0 : 0.6)
            .scaleEffect(isActive ? 1.02 : 1, anchor: .leading)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isActive)
    }
}

// MARK: - Scrubber (white-on-dark variant)

struct NowPlayingScrubber: View {
    @Environment(PlayerService.self) private var player

    @State private var isHovering = false
    @State private var isDragging = false
    @State private var dragProgress: Double = 0

    private var fraction: Double {
        guard player.duration > 0 else { return 0 }
        let value = isDragging ? dragProgress : player.progress
        return min(max(value / player.duration, 0), 1)
    }

    var body: some View {
        VStack(spacing: 5) {
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.25))
                        .frame(height: 4)
                    Capsule()
                        .fill(.white)
                        .frame(width: max(4, width * fraction), height: 4)
                    Circle()
                        .fill(.white)
                        .frame(width: thumbDiameter, height: thumbDiameter)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .offset(x: width * fraction - thumbDiameter / 2)
                        .opacity(isHovering || isDragging ? 1 : 0)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard player.duration > 0 else { return }
                            isDragging = true
                            player.isScrubbing = true
                            dragProgress = min(max(value.location.x / width, 0), 1) * player.duration
                        }
                        .onEnded { _ in
                            player.seek(to: dragProgress)
                            isDragging = false
                            player.isScrubbing = false
                        }
                )
            }
            .frame(height: 14)
            .onHover { hovering in
                withAnimation(AppAnimation.quick) { isHovering = hovering }
            }

            HStack {
                Text(Formatters.duration(isDragging ? dragProgress : player.progress))
                Spacer()
                Text(Formatters.duration(player.duration))
            }
            .font(.system(size: 10.5).monospacedDigit())
            .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var thumbDiameter: CGFloat {
        isDragging ? 13 : (isHovering ? 11 : 9)
    }
}

// MARK: - Mini lyrics (compact now-playing)

/// Three synced lyric lines (previous / current / next) filling the gap
/// between the track meta and the transport controls on compact layouts.
/// Tapping opens the full lyrics page.
struct MiniLyricsView: View {
    let onOpen: () -> Void

    @Environment(PlayerService.self) private var player

    private var lines: (previous: LyricLine?, current: LyricLine?, next: LyricLine?) {
        guard let lyrics = player.lyrics, !lyrics.isEmpty else { return (nil, nil, nil) }
        guard let index = lyrics.activeIndex(at: player.progress + 0.2) else {
            return (nil, nil, lyrics.lines.first)
        }
        let all = lyrics.lines
        return (
            index > 0 ? all[index - 1] : nil,
            all[index],
            index + 1 < all.count ? all[index + 1] : nil
        )
    }

    var body: some View {
        let (previous, current, next) = lines
        Group {
            if current != nil || next != nil {
                VStack(spacing: 12) {
                    line(previous, emphasized: false)
                    line(current, emphasized: true)
                    line(next, emphasized: false)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture(perform: onOpen)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: current?.id)
            } else {
                Color.clear
            }
        }
    }

    @ViewBuilder
    private func line(_ line: LyricLine?, emphasized: Bool) -> some View {
        Text(line?.text.isEmpty == false ? line!.text : " ")
            .font(.system(size: emphasized ? 17 : 14, weight: emphasized ? .bold : .medium))
            .foregroundStyle(.white.opacity(emphasized ? 1 : 0.45))
            .lineLimit(1)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 28)
            .id(line?.id)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}
