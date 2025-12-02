//
//  DeviceManager.swift
//  Location Simulator Boss
//
//  Created by Yugo Ogura on 2025-12-02.
//

import Foundation
import Observation

@Observable
class DeviceManager {
    var devices: [Device] = []
    var isScanning: Bool = false
    
    private var scanTimer: Timer?
    
    init() {
        startPeriodicScan()
    }
    
    deinit {
        stopPeriodicScan()
    }
    
    func startPeriodicScan() {
        scanDevices()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.scanDevices()
        }
    }
    
    func stopPeriodicScan() {
        scanTimer?.invalidate()
        scanTimer = nil
    }
    
    func scanDevices() {
        isScanning = true
        
        Task {
            async let iosDevices = scanIOSSimulators()
            async let androidDevices = scanAndroidEmulators()
            
            let allDevices = await iosDevices + androidDevices
            
            await MainActor.run {
                devices = allDevices
                isScanning = false
            }
        }
    }
    
    // MARK: - iOS Simulator Discovery
    
    private func scanIOSSimulators() async -> [Device] {
        let result = await runShellCommand("/usr/bin/xcrun", arguments: ["simctl", "list", "devices", "--json"])
        
        guard let data = result.data(using: .utf8) else { return [] }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let devicesDict = json?["devices"] as? [String: [[String: Any]]] else { return [] }
            
            var bootedDevices: [Device] = []
            
            for (_, deviceList) in devicesDict {
                for deviceInfo in deviceList {
                    guard let state = deviceInfo["state"] as? String,
                          state == "Booted",
                          let udid = deviceInfo["udid"] as? String,
                          let name = deviceInfo["name"] as? String else {
                        continue
                    }
                    
                    bootedDevices.append(Device(
                        id: udid,
                        name: name,
                        type: .iOSSimulator
                    ))
                }
            }
            
            return bootedDevices
        } catch {
            print("Failed to parse iOS simulators: \(error)")
            return []
        }
    }
    
    // MARK: - Android Emulator Discovery
    
    private func scanAndroidEmulators() async -> [Device] {
        // Try common adb paths
        let adbPaths = [
            "/usr/local/bin/adb",
            "\(NSHomeDirectory())/Library/Android/sdk/platform-tools/adb",
            "/opt/homebrew/bin/adb"
        ]
        
        var adbPath: String?
        for path in adbPaths {
            if FileManager.default.fileExists(atPath: path) {
                adbPath = path
                break
            }
        }
        
        // If not found in common paths, try finding adb in PATH
        if adbPath == nil {
            let whichResult = await runShellCommand("/usr/bin/which", arguments: ["adb"])
            let trimmed = whichResult.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && FileManager.default.fileExists(atPath: trimmed) {
                adbPath = trimmed
            }
        }
        
        guard let adb = adbPath else {
            return []
        }
        
        let result = await runShellCommand(adb, arguments: ["devices"])
        
        var emulators: [Device] = []
        let lines = result.components(separatedBy: "\n")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Look for emulator entries (e.g., "emulator-5554	device")
            if trimmed.contains("emulator-") && trimmed.contains("device") {
                let components = trimmed.components(separatedBy: .whitespaces)
                if let deviceId = components.first, !deviceId.isEmpty {
                    emulators.append(Device(
                        id: deviceId,
                        name: deviceId,
                        type: .androidEmulator
                    ))
                }
            }
        }
        
        return emulators
    }
    
    // MARK: - Shell Command Helper
    
    private func runShellCommand(_ command: String, arguments: [String]) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()
                
                process.executableURL = URL(fileURLWithPath: command)
                process.arguments = arguments
                process.standardOutput = pipe
                process.standardError = pipe
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: output)
                } catch {
                    print("Shell command failed: \(error)")
                    continuation.resume(returning: "")
                }
            }
        }
    }
}
