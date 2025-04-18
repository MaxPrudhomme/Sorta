//
//  DaemonManager.swift
//  Sorta
//
//  Created by Max PRUDHOMME on 17/04/2025.
//

import Foundation

actor DaemonManager {
    enum Error: Swift.Error {
        case helperNotInBundle
        case plistNotInBundle
        case launchCtlFailed(cmd: String, code: Int32, stderr: String)
        case fileOpFailed(underlying: Swift.Error)
    }

    private let fileManager = FileManager.default

    private var appSupportDir: URL {
        fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/SortaApp", isDirectory: true)
    }
    private var launchAgentsDir: URL {
        fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents", isDirectory: true)
    }
    private var installedHelper: URL {
        appSupportDir.appendingPathComponent("SortaDaemon")
    }
    private var installedPlist: URL {
        launchAgentsDir.appendingPathComponent("com.maxprudhomme.sortadaemon.plist")
    }

    private let label = "com.maxprudhomme.sortadaemon"

    func isRunning() async -> Bool {
        let uid = getuid()
        let result = await runProcess("/bin/launchctl", args: ["print", "gui/\(uid)/\(label)"])
        return result.exitCode == 0
    }

    func installAndStart() async throws {
        do {
            try fileManager.createDirectory(at: appSupportDir, withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true, attributes: nil)

            // Check if llama.framework exists
            await checkIfFrameworkExists()

            guard let helperSrc = Bundle.main
              .url(forResource: "SortaDaemon", withExtension: nil)
            else {
              throw Error.helperNotInBundle
            }
            if fileManager.fileExists(atPath: installedHelper.path) {
                try fileManager.removeItem(at: installedHelper)
            }
            
            try fileManager.copyItem(at: helperSrc, to: installedHelper)
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: installedHelper.path)

            let plistContents: [String: Any] = [
                "Label": label,
                "ProgramArguments": [installedHelper.path],
                "RunAtLoad": true,
                "KeepAlive": true,
                "StandardOutPath": "/tmp/sorta-daemon.log",
                "StandardErrorPath": "/tmp/sorta-daemon.err"
            ]

            let plistData = try PropertyListSerialization.data(fromPropertyList: plistContents, format: .xml, options: 0)

            if fileManager.fileExists(atPath: installedPlist.path) {
                try fileManager.removeItem(at: installedPlist)
            }
            try plistData.write(to: installedPlist)

            let uid = getuid()
            let bootstrap = await runProcess("/bin/launchctl", args: ["bootstrap", "gui/\(uid)", installedPlist.path])
            guard bootstrap.exitCode == 0 else { throw Error.launchCtlFailed(cmd: "bootstrap", code: bootstrap.exitCode, stderr: bootstrap.stderr) }
            
            print("✅ Daemon installed and started successfully.")
        } catch {
            throw Error.fileOpFailed(underlying: error)
        }
    }

    func stopAndUninstall() async throws {
        do {
            let uid = getuid()
            let bootout = await runProcess("/bin/launchctl", args: ["bootout", "gui/\(uid)", installedPlist.path])

            if bootout.exitCode != 0 { print("⚠️ launchctl bootout stderr:", bootout.stderr) }

            if fileManager.fileExists(atPath: installedPlist.path) { try fileManager.removeItem(at: installedPlist) }
            if fileManager.fileExists(atPath: installedHelper.path) { try fileManager.removeItem(at: installedHelper) }
            print("✅ Daemon stopped and uninstalled successfully.")
        } catch {
            throw Error.fileOpFailed(underlying: error)
        }
    }

    func checkIfFrameworkExists() async {
        let frameworkDir = appSupportDir.appendingPathComponent("Frameworks", isDirectory: true)
        let frameworkPath = frameworkDir.appendingPathComponent("llama.framework")

        // Check if the framework exists
        if fileManager.fileExists(atPath: frameworkPath.path) {
            print("✅ llama.framework exists at: \(frameworkPath.path)")
        } else {
            print("❌ llama.framework does not exist at: \(frameworkPath.path)")

            // If it doesn't exist, copy the framework to the location
            guard let frameworkSrc = Bundle.main.privateFrameworksURL?.appendingPathComponent("llama.framework") else {
                print("❌ llama.framework not found in privateFrameworksURL")
                return
            }
            
            do {
                try fileManager.createDirectory(at: frameworkDir, withIntermediateDirectories: true, attributes: nil)
                try fileManager.copyItem(at: frameworkSrc, to: frameworkPath)
                print("✅ Successfully copied llama.framework to: \(frameworkPath.path)")
            } catch {
                print("❌ Failed to copy llama.framework: \(error)")
            }
        }
    }

    @discardableResult
    private func runProcess(_ launchPath: String, args: [String]) async -> (exitCode: Int32, stdout: String, stderr: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: launchPath)
        proc.arguments = args

        let outPipe = Pipe(), errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError  = errPipe

        do {
            try proc.run()
        } catch {
            return (-1, "", "failed to run \(launchPath): \(error)")
        }

        proc.waitUntilExit()
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let outStr = String(decoding: outData, as: UTF8.self)
        let errStr = String(decoding: errData, as: UTF8.self)
        return (proc.terminationStatus, outStr, errStr)
    }
}
