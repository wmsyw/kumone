# Changelog

每个版本必须在此记录变更；发布流程会提取对应版本的段落，作为 GitHub Release
正文并渲染进 Sparkle appcast 的更新说明。Sections are the change categories
(`### Added / 新增`, `### Fixed / 修复`, `### Improved / 改进`); within each
section the English bullets come first, followed by their Simplified Chinese
counterparts. 段落格式：`## <版本号> - <日期>`，条目必须写成单行。

## 0.2.5 - 2026-08-23

### Added / 新增

- Phone number + SMS code login, alongside QR (single-device iOS users no longer need a second phone) (#10)
- QR login survives app switching: polling tolerates background network errors and resumes when you return — screenshot the QR, scan it from your photo library in the NetEase app, come back (#10)
- iOS: Settings → About → Check for Updates looks up the latest GitHub release and links to it; README documents sideload install and update (#9)
- 手机号 + 短信验证码登录，与扫码并列（iOS 单设备用户不再需要第二台手机）（#10）
- 扫码登录支持切换 App：轮询容忍后台断网并在回到前台时续上 —— 截图二维码、去网易云 App 相册识别、再回来即可（#10）
- iOS：设置 → 关于 → 检查更新 会查询 GitHub 最新版本并给出下载链接；README 补充侧载安装与更新说明（#9）

### Fixed / 修复

- The last song of a list (e.g. Daily Recommendations) could be hidden behind the player bar; pages now reserve the clearance explicitly instead of relying on safe-area padding, which was unreliable inside navigation stacks (#12)
- Hovering the feature cards / shelf cards on Home no longer clips the enlarged card at the top and bottom (#11)
- 列表最后一首（如每日推荐）可能被播放条遮住的问题；页面改为显式预留净空，不再依赖导航栈内不可靠的安全区内边距（#12）
- 首页功能卡片 / 货架卡片 hover 放大时上下不再被裁切（#11）

## 0.2.4 - 2026-08-23

### Improved / 改进

- The iOS deployment target is lowered from 18.0 to 17.0 (iPhone XS and later); iOS 18-only APIs now have iOS 17 fallbacks. iOS 16 is not feasible — the app's state layer is built on the Observation framework, which requires iOS 17
- iOS 最低系统要求从 18.0 降至 17.0（iPhone XS 及之后机型均可安装）；iOS 18 专属 API 已补 iOS 17 回退。iOS 16 不可行 —— 应用状态层基于 Observation 框架，其最低要求即 iOS 17

## 0.2.3 - 2026-08-22

### Fixed / 修复

- iOS playback now resumes automatically after audio interruptions (phone calls, WeChat voice messages) end; playback also pauses when headphones are unplugged
- The artwork was clipped in iPhone landscape on the now-playing page; it now scales to the display height
- Lock-screen artwork is now served at 1024px so the tap-to-fullscreen presentation engages
- iOS 音频被打断（来电、微信语音等）结束后现在会自动恢复播放；拔出耳机时自动暂停
- iPhone 横屏下播放页封面显示不全的问题；封面现随屏幕高度自适应缩放
- 锁屏封面改为 1024px 高清图，点按全屏展示可正常触发

### Added / 新增

- The compact now-playing page fills the gap between the artwork and the controls with three auto-scrolling synced lyric lines; tap them (or the top-right button) for the full lyrics page
- 紧凑播放页在封面与控制键之间新增三行自动滚动的同步歌词，点击歌词（或右上角按钮）进入全屏歌词页

## 0.2.2 - 2026-08-22

### Fixed / 修复

- The iOS app icon never showed — the icon set contained no image; the gold-spiral icon is now rendered from the shared artwork with the same composition as macOS
- The iOS Home Screen name showed "KumoneIOS" (`PRODUCT_DISPLAY_NAME` is not a real build setting); it now displays "Kumone" via `CFBundleDisplayName`
- iOS 图标一直不显示的问题（图标集里没有任何图片）；现从共享素材按 macOS 相同构图渲染金色旋涡图标
- iOS 主屏名称显示为「KumoneIOS」的问题（`PRODUCT_DISPLAY_NAME` 并非有效构建设置）；现通过 `CFBundleDisplayName` 显示为「Kumone」

### Improved / 改进

- The iOS bundle identifier is now `sb.moe.kumone`, distinct from the macOS app (`im.missuo.Kumone` stays unchanged so Sparkle updates keep working)
- iOS 的 bundle ID 改为 `sb.moe.kumone`，与 macOS 区分（macOS 保持 `im.missuo.Kumone` 不变，确保 Sparkle 升级不受影响）

## 0.2.1 - 2026-08-22

### Added / 新增

- Now Playing gains a like command: the hearted state syncs with the app and can be toggled from CarPlay / Control Center contexts
- 系统 Now Playing 接入「喜欢」：红心状态与 App 内双向同步，可在 CarPlay / 控制中心相关场景切换

### Fixed / 修复

- iOS audio stopped when the app left the foreground: `INFOPLIST_KEY_UIBackgroundModes` is not a real build setting and was silently ignored, so the built Info.plist had no background-audio declaration; it now comes from a partial Info.plist merged into the generated one
- iOS 应用退到后台后音频停止的问题：`INFOPLIST_KEY_UIBackgroundModes` 并非有效构建设置、被静默忽略，构建产物缺少后台音频声明；现改由部分 Info.plist 与自动生成内容合并提供

## 0.2.0 - 2026-08-21

### Added / 新增

- iOS and iPadOS support: cross-platform core (KumoneCore), adaptive layouts for compact and regular widths, and an `ios/` app workspace (#5, contributed by @MikeChongCan)
- Every release now ships an unsigned iOS IPA alongside the macOS build (sideload with your own signing)
- The macOS build is now Universal 2 — Intel Macs are supported (#7)
- iOS 与 iPadOS 支持：跨平台核心（KumoneCore）、紧凑/常规宽度自适应布局，以及 `ios/` 应用工程（#5，由 @MikeChongCan 贡献）
- 每次发版现在会同时附带无签名的 iOS IPA（自行签名侧载）
- macOS 构建改为 Universal 2，支持 Intel Mac（#7）

### Fixed / 修复

- Toolbar availability check missed the iOS clause, breaking the iOS build against the iOS 18 target
- Player bar's bottom fade no longer bleeds over the sidebar's corner
- The iOS app-shell Xcode project was silently excluded by .gitignore; it is now reconstructed via XcodeGen (`ios/project.yml`) and checked in, with the missing launch-screen key added so the app no longer letterboxes
- The sidebar divider's resize cursor no longer leaks onto the immersive now-playing page (#6)
- 工具栏可用性判断缺少 iOS 条件，导致 iOS 18 目标编译失败的问题
- 播放条底部渐变不再溢出覆盖侧边栏底角
- iOS app 壳工程曾被 .gitignore 静默排除；现改由 XcodeGen（`ios/project.yml`）生成并入库，并补上缺失的启动屏声明，App 不再上下黑边
- 侧边栏分隔条的拖拽光标不再泄漏到沉浸播放页上（#6）

### Improved / 改进

- Player chrome clearance is now derived from shared layout constants instead of scattered magic numbers
- The Home page no longer shows a sign-in card for anonymous users; the login entry lives only in the sidebar / 我的 tab
- 播放条净空高度改由共享布局常量推导，替代分散的魔数
- 未登录时首页不再显示登录卡片，登录入口仅保留在侧边栏 / 「我的」中

## 0.1.10 - 2026-08-19

### Fixed / 修复

- Gray-track unblocking now probes third-party media URLs with Range requests, falls back when a provider candidate fails, handles failed AVPlayer items, and tries multiple Kugou hashes
- 灰色歌曲解锁现在会通过 Range 请求探活第三方媒体 URL，在候选音源失败时回退，处理 AVPlayer item 播放失败，并尝试多个酷狗 hash
- pyncmd now requests the highest available audio quality by default (FLAC when available) and automatically falls back to 320 kbps when media candidates fail
- pyncmd 默认请求最高可用音质（可用时为 FLAC）；媒体候选失败时自动降级到 320 kbps

## 0.1.9 - 2026-08-17

### Fixed / 修复

- Scrolling long playlists could loop endlessly around the middle and never reach the bottom — caused by nested lazy stacks fighting over height estimation; list pages now use a plain outer container with lazy rows and fixed row heights (#3)
- The player bar and lyrics/queue panels now persist across page navigation instead of re-attaching per page (#4, contributed by @sld272)
- 长歌单滚动到中部时可能无限循环、无法到达底部的问题 —— 嵌套懒加载容器的高度估算互相干扰所致；列表页改为普通外层容器 + 懒加载行 + 固定行高（#3）
- 播放条与歌词/队列面板改为跨页面持久化，不再随页面切换重新挂载（#4，由 @sld272 贡献）

## 0.1.8 - 2026-08-17

### Added / 新增

- Desktop lyrics (LyricsX-style): a floating, always-on-top lyric line with translation, toggled from the player bar or Settings; draggable with center snapping, position persisted, excluded from screenshots, visible across all Spaces and full-screen apps
- 桌面歌词（LyricsX 风格）：悬浮置顶显示当前歌词与翻译，播放条或设置中开关；可拖动（带中线磁吸）、位置持久化、不出现在截图中、所有空间与全屏应用上可见

## 0.1.7 - 2026-08-16

### Fixed / 修复

- The like button in the player bar never actually rendered — the marquee title column pushed it out of the fixed-width section; it now always shows whenever a track is loaded
- 播放条的红心按钮此前从未真正显示（跑马灯标题列把它挤出了固定宽度区域）；现在只要有歌曲加载就始终显示

### Improved / 改进

- Release notes are now structured by change category with English and Chinese stacked under each section (GitHub Releases and Sparkle update notes)
- 更新说明改为按变更分类组织，每节内英文在上、中文在下（GitHub Release 与 Sparkle 更新弹窗同步生效）

## 0.1.6 - 2026-08-16

### Improved / 改进

- The "+" button next to Created Playlists now anchors to the trailing edge aligned with the playlist rows, independent of header text length in any language
- 「创建的歌单」的加号按钮改为尾部锚定并与歌单行右缘对齐，位置不再受各语言标题长度影响

## 0.1.5 - 2026-08-16

### Added / 新增

- Radar Playlists section on Home (Personal Radar / Chinese / Western / Japanese — personalized per account)
- English localization; the app follows the system language
- 首页「雷达歌单」专区（私人雷达 / 华语 / 欧美 / 日系，按账号个性化生成）
- 英文界面，App 跟随系统语言

### Fixed / 修复

- Cloud Disk always showed "no songs" — the real API nests song data under `privateCloud`/`simpleSong` and serves numeric quota fields, which broke decoding
- 音乐云盘始终显示「没有歌曲」的问题（真实接口把歌曲数据嵌在 `privateCloud`/`simpleSong` 里、容量字段为数字，导致解码失败）

## 0.1.4 - 2026-08-16

### Fixed / 修复

- New accounts (or accounts with little listening history) got a raw decoding error on the Daily Recommendations page because the API returns `data: null`; related endpoints (Personal FM, Heartbeat Mode, Cloud Disk) hardened the same way
- 新账号或听歌历史不足时，每日推荐接口返回空数据（`data: null`）导致页面报「数据解析失败」的问题；相关接口（私人漫游、心动模式、云盘）同步加固

### Improved / 改进

- Daily Recommendations now shows a friendly empty state, and decoding errors no longer surface raw error details to the user
- 每日推荐无数据时显示友好的空状态提示；解析错误不再向用户展示原始错误详情

## 0.1.3 - 2026-08-16

### Fixed / 修复

- "Play All" on a playlist failed silently (and the player bar never appeared) when every track was gray; it now matches the track list behavior and keeps gray tracks when unblocking is enabled (#1)
- 歌单「播放全部」在整单灰色歌曲时静默失败、播放条不出现的问题（现在与列表行为一致，解锁开启时保留灰色歌曲）（#1）

### Improved / 改进

- The player bar is now always visible with a placeholder idle state, removing the first-play layout jump (#1)
- 播放条改为常驻：未播放时显示占位状态，消除首次播放时的布局跳动，也不再遮挡列表底部（#1）

## 0.1.2 - 2026-08-16

### Improved / 改进

- The window toolbar (sidebar toggle, page title, search field) is hidden while the immersive now-playing page is open
- Tightened the sidebar's leading insets for a more compact navigation and playlist list
- 沉浸播放页打开时隐藏窗口工具栏（侧边栏折叠按钮、页面标题与搜索框不再露出）
- 收紧侧边栏行的左侧留白，导航与歌单列表更紧凑

## 0.1.1 - 2026-08-16

### Fixed / 修复

- Switching back to Home from other pages jittered the sidebar and flashed skeletons (Home and Explore page state is now kept across sidebar switches, no reloading)
- 从每日推荐等页面切回推荐时，侧边栏抖动、首页闪骨架屏的问题（首页与精选的页面状态现在跨切换保留，不再重复加载）

## 0.1.0 - 2026-08-16

### Added / 新增

- First public release
- QR code login with locally persisted, auto-refreshed cookies
- Home: daily recommendations, Personal FM, Heartbeat Mode, recommended playlists, charts, new albums, recommended artists
- Explore: category playlists with infinite scrolling
- Playback: Standard to Hi-Res quality, shuffle / repeat, play queue, gray track detection with third-party source unblocking
- Immersive now-playing page: artwork-tinted gradient backdrop with large synced lyrics
- Library: liked songs, playlists, albums, artists, recently played, cloud disk
- Search: aggregate / songs / artists / albums / playlists
- System integration: media keys, Control Center Now Playing, scrobbling
- Built-in Sparkle automatic updates
- 首个公开版本
- 扫码登录，Cookie 本地持久化、自动续期
- 推荐页：每日推荐、私人漫游、心动模式、推荐歌单、排行榜、新碟上架、推荐歌手
- 精选页：分类歌单无限滚动
- 播放：标准 ~ Hi-Res 音质、随机 / 循环、播放队列、灰色歌曲识别与第三方音源解锁
- 沉浸播放页：封面取色渐变背景、大字同步歌词
- 音乐库：喜欢的音乐、歌单、专辑、歌手、最近播放、音乐云盘
- 搜索：综合 / 单曲 / 歌手 / 专辑 / 歌单
- 系统集成：媒体键、控制中心 Now Playing、听歌打卡
- 内置 Sparkle 自动更新
