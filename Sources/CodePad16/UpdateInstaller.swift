import AppKit
import Foundation

/// Mounts a downloaded disk image and replaces the installed app with the
/// copy inside it, then relaunches. The replacement runs from a small script
/// after the current process exits, so the running bundle is never modified.
enum UpdateInstaller {
    static func install(dmg: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try installSynchronously(dmg: dmg)
                DispatchQueue.main.async {
                    completion(.success(()))
                    NSApp.terminate(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    private static func installSynchronously(dmg: URL) throws {
        let fileManager = FileManager.default
        let destination = try destinationURL()

        guard fileManager.isWritableFile(atPath: destination.deletingLastPathComponent().path) else {
            throw InstallError.destinationNotWritable(destination)
        }

        let mount = fileManager.temporaryDirectory
            .appendingPathComponent("CodePad16-update-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: mount, withIntermediateDirectories: true)

        try run("/usr/bin/hdiutil", ["attach", "-nobrowse", "-readonly", "-mountpoint", mount.path, dmg.path])

        do {
            let contents = try fileManager.contentsOfDirectory(at: mount, includingPropertiesForKeys: nil)
            guard let source = contents.first(where: { $0.pathExtension == "app" }) else {
                throw InstallError.appNotFound
            }

            let script = fileManager.temporaryDirectory
                .appendingPathComponent("codepad16-install-\(UUID().uuidString).sh")
            let scriptText = """
            #!/bin/sh
            pid="$1"
            destination="$2"
            source="$3"
            mount="$4"
            script="$5"
            n=0
            while kill -0 "$pid" 2>/dev/null && [ "$n" -lt 300 ]; do
              sleep 0.2
              n=$((n + 1))
            done

            cleanup() {
              /usr/bin/hdiutil detach "$mount" -quiet 2>/dev/null
              rm -rf "$mount"
              rm -f "$script"
            }

            new="$destination.new.$$"
            old="$destination.old.$$"

            fail() {
              rm -rf "$new"
              cleanup
              /usr/bin/open "$destination" 2>/dev/null
              exit 1
            }

            rm -rf "$new"
            /usr/bin/ditto "$source" "$new" || fail
            if [ -e "$destination" ]; then
              mv "$destination" "$old" || fail
            fi
            if mv "$new" "$destination"; then
              rm -rf "$old"
            else
              if [ -e "$old" ]; then mv "$old" "$destination"; fi
              fail
            fi
            /usr/bin/xattr -dr com.apple.quarantine "$destination" 2>/dev/null
            cleanup
            /usr/bin/open "$destination"
            """
            try scriptText.write(to: script, atomically: true, encoding: .utf8)
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = [
                script.path,
                "\(ProcessInfo.processInfo.processIdentifier)",
                destination.path,
                source.path,
                mount.path,
                script.path
            ]
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
        } catch {
            _ = try? run("/usr/bin/hdiutil", ["detach", mount.path, "-quiet"])
            try? fileManager.removeItem(at: mount)
            throw error
        }
    }

    private static func destinationURL() throws -> URL {
        let current = Bundle.main.bundleURL
        // When running from a mounted image or a Gatekeeper-translocated copy,
        // install into Applications.
        if current.path.hasPrefix("/Volumes/") || current.path.contains("/AppTranslocation/") {
            return URL(fileURLWithPath: "/Applications/CodePad16.app")
        }
        guard current.pathExtension == "app" else {
            throw InstallError.notAnApp
        }
        return current
    }

    @discardableResult
    private static func run(_ tool: String, _ arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw InstallError.commandFailed(tool)
        }
        return process.terminationStatus
    }

    enum InstallError: LocalizedError {
        case notAnApp
        case appNotFound
        case destinationNotWritable(URL)
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .notAnApp:
                return "The app is not running from an application bundle."
            case .appNotFound:
                return "The downloaded disk image does not contain CodePad16."
            case .destinationNotWritable(let url):
                return "CodePad16 cannot replace \(url.path). Move the app to a writable location and try again."
            case .commandFailed(let tool):
                return "The update could not be installed (\(tool) failed)."
            }
        }
    }
}
