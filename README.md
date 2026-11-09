# RightKit · 右键助手

一个极简的 macOS Finder 右键增强工具，用纯 Swift 写成，无第三方依赖、无 Xcode 工程、一条命令构建。

只做每天真会用到的那几件事：**新建文件、新建文件夹、在终端打开、拷贝路径、拷走文件**。

![platform](https://img.shields.io/badge/macOS-13%2B-black)
![arch](https://img.shields.io/badge/arch-arm64-blue)
![license](https://img.shields.io/badge/license-MIT-green)

---

## 功能

右键点击 **桌面 / 文件夹空白处 / 选中的文件或文件夹**：

| 菜单项 | 说明 |
|---|---|
| **新建文件** ▸ | 文本 `.txt`、Markdown `.md`、JSON `.json`、Shell `.sh`、Python `.py`、空白文件。`.sh` 和 `.py` 自动带 `755` 执行位 |
| **新建文件夹** | 自动命名，重名自动加序号 |
| **在终端中打开** | 用 Terminal 打开当前目录；选中文件夹时打开那个文件夹 |
| **拷贝路径** | 支持多选；空白处右键则为当前目录路径 |
| **拷贝到「下载」** | 选中项复制到 `~/Downloads`，重名自动改名 |
| **移动到「下载」** | 同上，但是移动 |

新建出来的文件会自动在 Finder 里**选中**，直接按回车就能改名。

## 安装

需要 macOS 13+（arm64）、Xcode 命令行工具。

```bash
xcode-select --install      # 如果没装过
git clone https://github.com/Z0iu/RightKit.git
cd RightKit
./build.sh
```

`build.sh` 会编译、ad-hoc 签名、安装到 `~/Applications`、并向 PlugInKit 注册扩展。

装完如果右键没反应，执行一次：

```bash
pluginkit -e use -i com.ln.rightkit.ext
killall Finder
```

首次运行 macOS 可能会在「系统设置 → 隐私与安全性」里提示，允许即可。

卸载：

```bash
./uninstall.sh
```

## 为什么是两层结构

```
~/Applications/RightKit.app                    宿主 App（LSUIElement，无 Dock 图标、不常驻）
└── Contents/PlugIns/RightKitExt.appex         FinderSync 扩展（负责出菜单）
```

macOS 强制 FinderSync 扩展运行在沙盒里，而**沙盒扩展拿不到任何目标文件夹的写权限**。
所以扩展只负责「出菜单 + 拼 URL」，真正的文件操作通过自定义 URL scheme
交给不在沙盒里的宿主 App 执行：

```
扩展（沙盒） --rightkit://newfile?dir=...&kind=md--> 宿主 App（无沙盒）--写盘--> Finder
```

这个 scheme 也可以直接自己调，方便写脚本或接 Alfred / Raycast：

```
rightkit://newfile?dir=/Users/me/Desktop&kind=md     # kind: txt md json sh py blank
rightkit://newfolder?dir=/Users/me/Desktop
rightkit://terminal?dir=/Users/me/Desktop
rightkit://copy?dir=/Users/me/Desktop&paths=%2Fa%0A%2Fb
rightkit://move?dir=/Users/me/Desktop&paths=%2Fa%0A%2Fb
```

`paths` 用换行分隔，做 URL 编码。

## 三个 FinderSync 的坑（踩过，改代码前先看）

1. **`representedObject` 过 XPC 会丢。**
   菜单项参数一律用 `tag`（整数）传递。早期版本用 `representedObject` 传文件类型，
   结果无论选什么都建成 `.txt`。

2. **`isTemplate` 过 XPC 会丢。**
   图标不要指望系统自动着色——会固定显示为黑色，深色菜单下直接看不见。
   现在按 `NSApp.effectiveAppearance` 判断深浅色，用
   `NSImage.SymbolConfiguration(paletteColors:)` 把颜色**预烘焙**进图里。

3. **扩展里不能用 `NSAlert.runModal()` / `NSOpenPanel` / `Process`。**
   会抛 `FIFinderSync caught an exception while executing selector`，
   用户侧表现为「点了没反应」。需要 UI 或写盘，一律走 `rightkit://` 交给宿主 App。

## 目录结构

```
src/RightKitExt.swift     FinderSync 扩展：菜单定义、图标、动作分发
src/main.swift            宿主 App：URL 解析 + 实际文件操作
src/ext.entitlements      扩展的沙盒权限
src/AppIcon.icns          图标
Info.plist.app            宿主 App 的 Info.plist
Info.plist.ext            扩展的 Info.plist（含 NSExtension 声明）
build.sh                  构建 + 签名 + 安装 + 注册
uninstall.sh              卸载
```

## 自定义

- **改模板**：编辑 `src/main.swift` 里的 `Kinds.template(_:)`
- **改菜单项 / 图标**：编辑 `src/RightKitExt.swift` 里的 `fileKinds` / `kindIcons` 和 `menu(for:)`
- **改 bundle id**：`Info.plist.app`、`Info.plist.ext`、`build.sh` 里 `pluginkit -e use -i` 三处一起改

## 已知限制

- ad-hoc 签名（自用足够），没有公证，不能上架 App Store
- 只编译了 arm64；要 Intel 支持加 `-target x86_64-apple-macos13.0` 再用 `lipo` 合并
- 「拷贝到…」目前固定目标为「下载」；要任选目录需要额外做一次安全作用域书签授权

## License

MIT
