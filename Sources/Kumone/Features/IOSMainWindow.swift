import SwiftUI

#if os(iOS)
public struct IOSMainWindow: View {
    @State private var player = PlayerService.shared
    @State private var account = AccountStore.shared
    @State private var settings = SettingsManager.shared
    @State private var toasts = ToastCenter.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedTab: IOSTab = .home
    @State private var showLogin = false
    @State private var homePath = NavigationPath()
    @State private var explorePath = NavigationPath()
    @State private var fmPath = NavigationPath()
    @State private var searchPath = NavigationPath()
    @State private var libraryPath = NavigationPath()

    public init() {}

    public var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                // iPad / Large screen: Split view
                MainWindow()
            } else {
                // iPhone / Compact screen: Tab view
                tabInterface
            }
        }
        .environment(player)
        .environment(account)
        .environment(settings)
        .environment(toasts)
        .tint(Theme.accent)
        .preferredColorScheme(settings.appearance.colorScheme)
        .environment(\.openLogin, { showLogin = true })
        .task {
            await account.bootstrap()
            // Quiet auto-check on launch: only surfaces a sheet if newer.
            IOSUpdater.shared.check(interactive: false)
        }
        .sheet(isPresented: Bindable(IOSUpdater.shared).showSheet) {
            IOSUpdaterSheet()
        }
        .sheet(isPresented: $showLogin) {
            LoginSheet()
                .environment(account)
                .environment(toasts)
        }
        .fullScreenCover(isPresented: Bindable(player).showNowPlaying) {
            NowPlayingView()
                .environment(player)
                .environment(account)
                .environment(settings)
        }
        .overlay(alignment: .top) {
            if let toast = toasts.current {
                ToastView(toast: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
        .animation(.spring(duration: 0.3), value: toasts.current)
    }

    private var tabInterface: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    HomeView()
                        .appDestinations()
                }
                .tabItem {
                    Label("推荐", systemImage: "house.fill")
                }
                .tag(IOSTab.home)

                NavigationStack {
                    ExploreView()
                        .appDestinations()
                }
                .tabItem {
                    Label("精选", systemImage: "square.grid.2x2.fill")
                }
                .tag(IOSTab.explore)

                NavigationStack {
                    FMView()
                        .appDestinations()
                }
                .tabItem {
                    Label("漫游", systemImage: "wave.3.right.circle.fill")
                }
                .tag(IOSTab.fm)

                NavigationStack {
                    SearchView(query: "")
                        .appDestinations()
                }
                .tabItem {
                    Label("搜索", systemImage: "magnifyingglass")
                }
                .tag(IOSTab.search)

                NavigationStack {
                    IOSLibraryView(showLogin: $showLogin)
                        .appDestinations()
                }
                .tabItem {
                    Label("我的", systemImage: "person.crop.circle.fill")
                }
                .tag(IOSTab.library)
            }

            if player.hasCurrentTrack {
                IOSMiniPlayerBar()
                    .padding(.horizontal, 12)
                    .padding(.bottom, 54)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(AppAnimation.standard, value: player.hasCurrentTrack)
    }
}

enum IOSTab: Hashable {
    case home, explore, fm, search, library
}

// MARK: - Mini player bar for iOS

struct IOSMiniPlayerBar: View {
    @Environment(PlayerService.self) private var player
    @Environment(AccountStore.self) private var account

    var body: some View {
        Button {
            withAnimation(AppAnimation.smooth) {
                player.showNowPlaying = true
            }
        } label: {
            HStack(spacing: 10) {
                CachedAsyncImage(url: player.currentTrack?.album.picUrl?.resizedImageURL(128))
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(player.currentTrack?.name ?? "")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(player.currentTrack?.artistNames ?? "")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.pressable)

                Button {
                    player.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.pressable)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - iOS Library View

struct IOSLibraryView: View {
    @Binding var showLogin: Bool
    @Environment(AccountStore.self) private var account
    @State private var showSettings = false
    @State private var showNewPlaylist = false
    @State private var newPlaylistName = ""

    var body: some View {
        List {
            // Profile / Login header
            Section {
                if let profile = account.profile {
                    HStack(spacing: 14) {
                        CachedAsyncImage(url: profile.avatarUrl?.resizedImageURL(128))
                            .frame(width: 52, height: 52)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(profile.nickname)
                                    .font(.headline)
                                if profile.vipType > 0 {
                                    VIPBadge()
                                }
                            }
                            if let sig = profile.signature, !sig.isEmpty {
                                Text(sig)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    Button {
                        showLogin = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 32))
                                .foregroundStyle(Theme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("登录网易云音乐")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("同步我喜欢的音乐、歌单与每日推荐")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }

            if account.hasAuthCookie {
                Section("我的音乐") {
                    if let liked = account.likedSongsPlaylist {
                        NavigationLink(value: Destination.playlist(liked.id)) {
                            Label("我喜欢的音乐", systemImage: "heart.fill")
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    NavigationLink(value: Destination.daily) {
                        Label("每日推荐", systemImage: "calendar")
                    }
                    NavigationLink(value: Destination.recents) {
                        Label("最近播放", systemImage: "clock.fill")
                    }
                    NavigationLink(value: Destination.collections) {
                        Label("我的收藏", systemImage: "star.fill")
                    }
                    NavigationLink(value: Destination.cloud) {
                        Label("音乐云盘", systemImage: "icloud.fill")
                    }
                }

                if !account.createdPlaylists.isEmpty {
                    Section {
                        ForEach(account.createdPlaylists) { playlist in
                            NavigationLink(value: Destination.playlist(playlist.id)) {
                                HStack(spacing: 10) {
                                    CachedAsyncImage(url: playlist.coverURL?.resizedImageURL(80), animated: false)
                                        .frame(width: 32, height: 32)
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(playlist.name)
                                            .font(.system(size: 14))
                                            .lineLimit(1)
                                        Text("\(playlist.trackCount) 首")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text("创建的歌单")
                            Spacer()
                            Button {
                                showNewPlaylist = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                        }
                    }
                }

                if !account.subscribedPlaylists.isEmpty {
                    Section("收藏的歌单") {
                        ForEach(account.subscribedPlaylists) { playlist in
                            NavigationLink(value: Destination.playlist(playlist.id)) {
                                HStack(spacing: 10) {
                                    CachedAsyncImage(url: playlist.coverURL?.resizedImageURL(80), animated: false)
                                        .frame(width: 32, height: 32)
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(playlist.name)
                                            .font(.system(size: 14))
                                            .lineLimit(1)
                                        Text("\(playlist.trackCount) 首")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("我的")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
                    .navigationTitle("设置")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("完成") {
                                showSettings = false
                            }
                        }
                    }
            }
        }
        .alert("新建歌单", isPresented: $showNewPlaylist) {
            TextField("歌单名称", text: $newPlaylistName)
            Button("创建") {
                let name = newPlaylistName.trimmingCharacters(in: .whitespaces)
                newPlaylistName = ""
                guard !name.isEmpty else { return }
                Task {
                    do {
                        try await NeteaseAPI.createPlaylist(name: name, isPrivate: false)
                        await account.refreshLibrary()
                        ToastCenter.shared.show(String(localized: "歌单已创建"))
                    } catch {
                        ToastCenter.shared.show(error.localizedDescription)
                    }
                }
            }
            Button("取消", role: .cancel) { newPlaylistName = "" }
        }
    }
}
#endif
