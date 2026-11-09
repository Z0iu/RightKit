import Cocoa
import FinderSync
import os.log

private let log = OSLog(subsystem: "com.ln.rightkit.ext", category: "menu")

@objc(RightKitExt)
final class RightKitExt: FIFinderSync {

    // 顺序必须与菜单一致
    static let fileKinds = ["文本文件 .txt", "Markdown .md", "JSON .json",
                            "Shell 脚本 .sh", "Python .py", "空白文件"]
    static let kindValues = ["txt", "md", "json", "sh", "py", "blank"]
    static let kindIcons  = ["doc.text", "text.alignleft", "curlybraces",
                             "terminal", "chevron.left.forwardslash.chevron.right", "doc"]

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    /// SF Symbol -> 按当前外观预烘焙颜色的图标
    /// 走 XPC 传给 Finder 时 isTemplate 标记会丢，导致固定显示黑色，
    /// 所以这里直接把对的颜色画进图里，不依赖模板机制。
    private static func icon(_ name: String) -> NSImage? {
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let color: NSColor = dark ? .white : .black
        let sizeCfg = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        let colorCfg = NSImage.SymbolConfiguration(paletteColors: [color])
        let cfg = sizeCfg.applying(colorCfg)
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return nil }
        guard let img = base.withSymbolConfiguration(cfg) else { return nil }
        img.isTemplate = false
        img.size = NSSize(width: 16, height: 16)
        return img
    }

    private func item(_ title: String, _ symbol: String, _ action: Selector?, tag: Int = 0) -> NSMenuItem {
        let mi = NSMenuItem(title: title, action: action, keyEquivalent: "")
        mi.target = self
        mi.tag = tag
        if let img = Self.icon(symbol) { mi.image = img }
        return mi
    }

    private func targetDirectory() -> URL {
        let c = FIFinderSyncController.default()
        let sel = c.selectedItemURLs() ?? []
        if let first = sel.first {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: first.path, isDirectory: &isDir), isDir.boolValue {
                return first
            }
            return first.deletingLastPathComponent()
        }
        return c.targetedURL() ?? URL(fileURLWithPath: NSHomeDirectory())
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let menu = NSMenu(title: "")
        let sel = FIFinderSyncController.default().selectedItemURLs() ?? []

        // 新建文件 ▸
        let newFile = item("新建文件", "doc.badge.plus", nil)
        let sub = NSMenu(title: "新建文件")
        for (idx, title) in Self.fileKinds.enumerated() {
            sub.addItem(item(title, Self.kindIcons[idx], #selector(doNewFile(_:)), tag: idx))
        }
        newFile.submenu = sub
        menu.addItem(newFile)

        // 新建文件夹
        menu.addItem(item("新建文件夹", "folder.badge.plus", #selector(doNewFolder(_:))))

        menu.addItem(.separator())

        // 终端
        menu.addItem(item("在终端中打开", "terminal", #selector(doTerminal(_:))))

        // 拷贝路径
        menu.addItem(item(sel.count > 1 ? "拷贝 \(sel.count) 个路径" : "拷贝路径",
                          "doc.on.clipboard", #selector(doCopyPath(_:))))

        if !sel.isEmpty {
            menu.addItem(.separator())
            menu.addItem(item("拷贝到「下载」", "arrow.down.doc", #selector(doCopy(_:))))
            menu.addItem(item("移动到「下载」", "arrow.right.doc", #selector(doMove(_:))))
        }
        return menu
    }

    // MARK: - 交给宿主 App 执行
    private func dispatch(_ action: String, _ extra: [String: String] = [:]) {
        let dir = targetDirectory()
        var comps = URLComponents()
        comps.scheme = "rightkit"
        comps.host = action
        var items = [URLQueryItem(name: "dir", value: dir.path)]
        for (k, v) in extra { items.append(URLQueryItem(name: k, value: v)) }
        comps.queryItems = items
        guard let url = comps.url else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func doNewFile(_ sender: NSMenuItem) {
        let idx = min(max(sender.tag, 0), Self.kindValues.count - 1)
        dispatch("newfile", ["kind": Self.kindValues[idx]])
    }

    @objc private func doNewFolder(_ sender: NSMenuItem) { dispatch("newfolder") }
    @objc private func doTerminal(_ sender: NSMenuItem) { dispatch("terminal") }

    @objc private func doCopy(_ sender: NSMenuItem) {
        let sel = FIFinderSyncController.default().selectedItemURLs() ?? []
        dispatch("copy", ["paths": sel.map { $0.path }.joined(separator: "\n")])
    }

    @objc private func doMove(_ sender: NSMenuItem) {
        let sel = FIFinderSyncController.default().selectedItemURLs() ?? []
        dispatch("move", ["paths": sel.map { $0.path }.joined(separator: "\n")])
    }

    @objc private func doCopyPath(_ sender: NSMenuItem) {
        let c = FIFinderSyncController.default()
        let sel = c.selectedItemURLs() ?? []
        let paths = sel.isEmpty ? [targetDirectory().path] : sel.map { $0.path }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(paths.joined(separator: "\n"), forType: .string)
        os_log("copied %d paths", log: log, type: .default, paths.count)
    }
}
