import Cocoa
import os.log

private let log = OSLog(subsystem: "com.ln.rightkit", category: "exec")

enum Kinds {
    static func template(_ kind: String) -> (String, String)? {
        switch kind {
        case "txt":  return ("未命名", "")
        case "md":   return ("未命名", "# 标题\n\n")
        case "json": return ("未命名", "{\n  \n}\n")
        case "sh":   return ("未命名", "#!/bin/bash\n\n")
        case "py":   return ("未命名", "#!/usr/bin/env python3\n\n")
        case "blank": return ("未命名", "")
        default: return nil
        }
    }
}

func uniqueName(in dir: URL, base: String, ext: String) -> String {
    let fm = FileManager.default
    func build(_ i: Int) -> String {
        let stem = i <= 1 ? base : "\(base) \(i)"
        return ext.isEmpty ? stem : "\(stem).\(ext)"
    }
    var i = 1
    var name = build(i)
    while fm.fileExists(atPath: dir.appendingPathComponent(name).path) && i < 10000 {
        i += 1; name = build(i)
    }
    return name
}

final class Delegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for u in urls { perform(u) }
    }

    private func perform(_ url: URL) {
        guard url.scheme == "rightkit" else { return }
        let action = url.host ?? ""
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var q: [String: String] = [:]
        for it in comps?.queryItems ?? [] { q[it.name] = it.value ?? "" }
        let dir = URL(fileURLWithPath: q["dir"] ?? NSHomeDirectory())
        os_log("action=%{public}@ dir=%{public}@", log: log, type: .default, action, dir.path)

        switch action {
        case "newfile":
            let kind = q["kind"] ?? "txt"
            guard let (base, content) = Kinds.template(kind) else { return }
            let ext = kind == "blank" ? "" : kind
            let name = uniqueName(in: dir, base: base, ext: ext)
            let target = dir.appendingPathComponent(name)
            do {
                try content.write(to: target, atomically: true, encoding: .utf8)
                if ext == "sh" || ext == "py" {
                    try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: target.path)
                }
                NSWorkspace.shared.activateFileViewerSelecting([target])
            } catch { report("新建文件失败", error.localizedDescription) }

        case "newfolder":
            let name = uniqueName(in: dir, base: "未命名文件夹", ext: "")
            let target = dir.appendingPathComponent(name)
            do {
                try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
                NSWorkspace.shared.activateFileViewerSelecting([target])
            } catch { report("新建文件夹失败", error.localizedDescription) }

        case "terminal":
            let term = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
            NSWorkspace.shared.open([dir], withApplicationAt: term, configuration: NSWorkspace.OpenConfiguration()) { _, err in
                if let err = err { self.report("打开终端失败", err.localizedDescription) }
            }

        case "copy", "move":
            let raw = q["paths"] ?? ""
            let urls = raw.split(separator: "\n").map { URL(fileURLWithPath: String($0)) }
            guard !urls.isEmpty,
                  let dest = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else { return }
            let fm = FileManager.default
            var errs: [String] = []
            for src in urls {
                var target = dest.appendingPathComponent(src.lastPathComponent)
                if fm.fileExists(atPath: target.path) {
                    target = dest.appendingPathComponent(
                        uniqueName(in: dest, base: src.deletingPathExtension().lastPathComponent, ext: src.pathExtension))
                }
                do {
                    if action == "move" { try fm.moveItem(at: src, to: target) }
                    else { try fm.copyItem(at: src, to: target) }
                } catch { errs.append("\(src.lastPathComponent): \(error.localizedDescription)") }
            }
            if !errs.isEmpty { report("部分操作失败", errs.joined(separator: "\n")) }
            else { NSWorkspace.shared.activateFileViewerSelecting([dest]) }

        default:
            break
        }
    }

    private func report(_ title: String, _ body: String) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = body
        a.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        a.runModal()
    }
}

let app = NSApplication.shared
let delegate = Delegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
