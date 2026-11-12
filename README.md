# Super Web

一个用 Swift + **WKWebView** 编写的 iOS 浏览器。界面与交互按 Chromium / Chrome 的形态做：胶囊地址栏、底部工具栏、标签页网格总览、无痕模式、书签与历史本地存储。

<p align="center">
  <img src="SuperWeb/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" width="160" alt="Super Web 图标">
</p>

---

## 先说清楚：为什么内核不是 Chromium

这一点必须先讲明白，否则项目从第一步就是错的：

1. **iOS 上不存在"自带 Chromium 内核"的浏览器**。除欧盟 DMA 特批的少数分发渠道外，Apple 要求所有浏览器 App 使用 WebKit（`WKWebView`）。Chrome for iOS 自己就是 WKWebView 外壳，Chromium 源码树里的 `ios/` 目录编出来的同样是 WKWebView 版本。
2. **CEF（Chromium Embedded Framework）不支持 iOS**，Blink 渲染引擎在 iOS 上没有可分发形态。
3. 所以"Super Web 使用 Chromium 内核"在国区 iOS 上客观做不到。本项目诚实地使用 WebKit，把 Chromium 的**产品形态**（UI/交互/功能组织）做出来。

如果将来确实要接 Blink：需要 Apple 的替代浏览器引擎授权（`com.apple.developer.web-browser-engine.host`）、仅限欧盟分发、且要自行编译 Chromium 的 iOS 目标，工程量是另一个量级。项目结构已经把渲染层隔离在 `Tab` / `WKWebView` 这一层，未来替换有落点。

## 功能

- 胶囊地址栏：输入网址直达，输入关键词自动用所选搜索引擎搜索（默认必应，含百度 / 搜狗 / Google / DuckDuckGo）
- 多标签页，标签网格总览（标题 + 网址 + 关闭按钮 + 新建）
- 无痕标签：独立非持久化 `WKWebsiteDataStore`，关标签即清 Cookie
- 前进 / 后退 / 刷新 / 停止、加载进度条、HTTPS 锁标
- 分享当前页面（系统分享面板）
- 书签、历史记录（本地 JSON，可滑动删除、可一键清空）
- 设置：搜索引擎、外观（跟随系统 / 浅色 / 深色）、保存历史开关、清除网站数据
- 页面内 `target="_blank"` 链接自动开新标签
- JS 的 `alert` / `confirm` / `prompt` 原生弹窗
- `tel:` / `mailto:` / `itms-apps:` 等非 http 协议交给系统处理
- 加载失败页 + 重试
- 深色 / 浅色自适应（跟随系统，也可手动锁定浅色 / 深色）
- **多线程分段下载引擎**：默认 32 线程，可调 8 / 16 / 32 / 48 / 64；支持暂停、继续、断点续传、完成后系统分享
- **直接打开 HTML / HTM**：分享面板里「用 Super Web 打开」、或从「文件」App 里点进来，都直接在浏览器里渲染
- **一键把当前页面存成 HTML**：抓 `document.documentElement.outerHTML` 写到 `Documents/Saved Pages`，再弹分享
- **浏览器标识（UA）切换**：iPhone / iPad / MacBook / Android / 塞班 / Old Windows (Win7) / Windows
- **广告拦截**：`WKContentRuleList` 规则表，拦常见广告域名与广告路径
- **标签页会话自动恢复**：退到后台或被杀进程后，重开还原上次的标签与选中项

## 目录结构

```
super-web/
├── .github/workflows/build.yml        # GitHub Actions：macOS 上编译并打包未签名 IPA
├── SuperWeb.xcodeproj/                # 工程文件（脚本生成，含共享 scheme）
├── SuperWeb/
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   ├── Theme.swift                    # 配色 + SF Symbol helper
│   ├── Info.plist                     # ATS 放开 http、Scene 配置
│   ├── Browser/
│   │   ├── BrowserViewController.swift   # 核心：导航 / 标签 / 地址栏 / 菜单 / 下载接线
│   │   ├── AddressBarView.swift
│   │   ├── BrowserToolbar.swift
│   │   ├── ProgressBarView.swift
│   │   ├── TabGridViewController.swift   # 标签网格
│   │   ├── BrowseListViewController.swift # 历史 / 书签列表
│   │   ├── DownloadsViewController.swift  # 下载列表（进度 / 暂停 / 重试 / 分享）
│   │   ├── SettingsViewController.swift
│   │   ├── StartPageView.swift
│   │   └── ErrorView.swift
│   ├── Model/
│   │   ├── Tab.swift                  # 单标签 + WebView 懒加载 + KVO
│   │   ├── TabManager.swift           # 标签集合、无痕数据存储、WebViewConfiguration
│   │   ├── BrowserURL.swift           # 输入解析：网址 or 搜索
│   │   ├── SearchEngine.swift
│   │   ├── Settings.swift
│   │   ├── UserAgent.swift            # 内置 UA 预设
│   │   ├── SessionStore.swift         # 标签页会话持久化
│   │   ├── AdBlocker.swift            # WKContentRuleList 广告规则
│   │   ├── DownloadManager.swift      # 分段多线程下载引擎
│   │   └── HistoryStore.swift         # 历史 / 书签持久化
│   └── Resources/Assets.xcassets
└── scripts/
    ├── generate_xcodeproj.py          # 重新生成 .xcodeproj（增删文件后跑一次）
    └── build.sh                       # 本地 macOS 编译
```

## 几个功能是怎么做的

### 多线程下载（默认 32，最高 64）

1. 先发一个 `Range: bytes=0-0` 的探测请求。服务器回 `206` 且 `Content-Range: bytes 0-0/总长度`，就拿到文件总大小，说明支持分段；否则退化为单连接下载。
2. 分段数取「设置的线程数」和「总大小 / 1MB」的较小值，最多 64 段。每段一条 `URLSessionDownloadTask`，各自带 `Range` 头，写到临时目录里的 `part-N` 文件。
3. `URLSessionConfiguration.httpMaximumConnectionsPerHost` 必须显式设成 64 —— 它的默认值只有 6，不改的话 64 段实际只有 6 个并发。
4. `User-Agent` 用当前选中的 UA 预设，`Cookie` 从 `WKWebsiteDataStore` 里按域名后缀过滤后带上，`Referer` 用来源页。
5. 暂停：取消所有 task 但保留 `part-N`；继续：按磁盘上现有文件大小重算每段的起点，`reset: false` 复用同一个临时目录，实现断点续传。所有段完成后按顺序 `FileHandle` 拼成一个文件，落到 `Documents/Downloads`。

文件位置：**「文件」App → 我的 iPhone → Super Web → Downloads**（`Info.plist` 里已开 `UIFileSharingEnabled`）。

### 打开 HTML / HTM

`Info.plist` 注册了 `public.html` 文档类型（`LSHandlerRank=Alternate`，不抢 Safari 的默认地位），并开启 `LSSupportsOpeningDocumentsInPlace`。从别处分享一个 `.html` 过来、选「用 Super Web 打开」，`SceneDelegate` 的 `openURLContexts` 会收到 URL，浏览器新开一个标签用 `loadFileURL(_:allowingReadAccessTo:)` 渲染。菜单里还有「打开本地 HTML 文件」，走 `UIDocumentPickerViewController` 直接选。

### 广告拦截

编译一份 `WKContentRuleList`，规则只覆盖已知广告域名（doubleclick、googlesyndication、cpro.baidu、tanx、criteo、taboola 等）加少量明显的广告路径（`/ads?/`、`/adserver`、`/popunder`、banner 图）。路径规则都限定 `resource-type` 为 `image` / `script` / `raw`，不碰正文。设置里可开关，切换后当前页会重新加载。

### 会话恢复

每次加载完成、新建 / 关闭标签、进后台时把标签列表（网址 + 标题 + 选中项）写进 `Application Support/SuperWeb/session.json`。无痕标签不写入。下次启动时按这份清单重建标签并逐个重新加载。

## 用 GitHub 编译

1. 在 GitHub 新建一个空仓库（Public 即可，**公开仓库的 macOS Actions 免费**）。
2. 把本目录推上去：

```bash
cd super-web
git init -b main
git add .
git commit -m "Super Web: iOS browser"
git remote add origin https://github.com/<你的用户名>/super-web.git
git push -u origin main
```

3. push 之后打开 **Actions** 页签，`Build Super Web` 会自动跑：在 `macos-15` 机器上 `xcodebuild` 编 Release，产出**未签名**的 `SuperWeb-unsigned.ipa`。
4. 跑完后在对应 run 的 **Artifacts** 里下载 `SuperWeb-unsigned-ipa`（含 `.ipa` 和 `.zip` 两种打包）。完整编译日志在 `build-log` 里。

也可以手动触发：Actions → Build Super Web → Run workflow。

> 未签名 IPA 不能直接双击安装，必须用签名工具用自己的 Apple ID 重签（见下）。

## 装到 iPhone

任选其一：

| 方式 | 说明 |
| --- | --- |
| **Sideloadly**（Windows / macOS） | 拖入 IPA + 输入 Apple ID，自动重签并安装。免费账号签名有效期 **7 天**，到期需重签 |
| **AltStore / SideStore** | 电脑端装 AltServer，手机上用 AltStore 续签，可自动 7 天刷新 |
| **付费开发者账号** | 在 Xcode 里配置 Team，或把 workflow 里的 `CODE_SIGNING_ALLOWED=NO` 去掉 + 导出签名 IPA，有效期 1 年 |
| **TrollStore** | 仅限特定 iOS 版本（依赖 CoreTrust 漏洞），可直接安装未签名 IPA，永久有效 |

安装后首次启动若提示"未受信任的开发者"，去 **设置 → 通用 → VPN 与设备管理** 信任证书。

## 本地编译（有 Mac 时）

```bash
bash scripts/build.sh    # 用 xcodebuild 编 Release 并打包未签名 IPA
open SuperWeb.xcodeproj  # 用 Xcode 打开真机调试
```

如果要改 Bundle ID（重签冲突时常用）：改 `scripts/generate_xcodeproj.py` 里的 `BUNDLE_ID`，重跑脚本；或直接在 Xcode 的 Signing & Capabilities 里改。

## 改东西的入口

- **改名字**：`SuperWeb/Info.plist` 的 `CFBundleDisplayName`
- **改图标**：替换 `SuperWeb/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`（1024×1024，无透明通道）
- **改主色**：`SuperWeb/Theme.swift` 的 `accent`，以及 `AccentColor.colorset`
- **加 / 删 Swift 文件**：把文件放进 `SuperWeb/Browser` 或 `SuperWeb/Model`，然后 `python3 scripts/generate_xcodeproj.py` 重新生成工程（脚本会校验所有 UUID 引用闭合）
- **加搜索引擎**：`SearchEngine` 枚举里加一个 case（`displayName` / `endpoint` / `queryKey`）

## 已知限制

- 不支持浏览器扩展、账号同步
- 下载走的是前台 `URLSession`：App 被系统挂起后下载会停，回来再继续（要真正后台下载得换 `background` session 并处理 `handleEventsForBackgroundURLSession`）
- 广告规则是内置的固定规则表，不是 EasyList 那种可订阅、可自动更新的列表
- 未做 iPad 分栏多窗口（`UIApplicationSupportsMultipleScenes` 目前为 false）
- 无痕模式只保证本地不落 Cookie / 历史，无法对抗网络侧追踪
- 没有做 App Store 上架所需的隐私清单与审核材料；本项目面向自签 / 自用

## 路线图（可选）

- [x] 标签页会话恢复（重启 App 还原已开标签）
- [x] 广告拦截（`WKContentRuleList`）
- [x] 多线程下载引擎
- [x] 自定义 User-Agent / 桌面版网页开关（UA 预设切换）
- [ ] 长按地址栏粘贴并访问、二维码扫描
- [ ] 页面内查找（`WKWebView` 无原生接口，可用 JS 实现高亮）
- [ ] 下载改后台 session，支持 App 挂起后继续
- [ ] iCloud 同步书签（`NSUbiquitousKeyValueStore`）

## 许可

MIT，见 [LICENSE](LICENSE)。
