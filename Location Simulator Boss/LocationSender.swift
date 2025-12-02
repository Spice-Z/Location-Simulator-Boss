//
//  LocationSender.swift
//  Location Simulator Boss
//
//  Created by Yugo Ogura on 2025-12-02.
//

import Foundation
import CoreLocation

class LocationSender {
    
    static let shared = LocationSender()
    
    private init() {}
    
    func sendLocation(_ coordinate: CLLocationCoordinate2D, to devices: [Device]) async {
        await withTaskGroup(of: Void.self) { group in
            for device in devices {
                group.addTask {
                    await self.sendLocationToDevice(coordinate, device: device)
                }
            }
        }
    }
    
    private func sendLocationToDevice(_ coordinate: CLLocationCoordinate2D, device: Device) async {
        switch device.type {
        case .iOSSimulator:
            await sendToIOSSimulator(coordinate, udid: device.id)
        case .androidEmulator:
            await sendToAndroidEmulator(coordinate, deviceId: device.id)
        }
    }
    
    // MARK: - iOS Simulator
    
    private func sendToIOSSimulator(_ coordinate: CLLocationCoordinate2D, udid: String) async {
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        
        // xcrun simctl location <udid> set <lat>,<lon>
        let result = await runShellCommand(
            "/usr/bin/xcrun",
            arguments: ["simctl", "location", udid, "set", "\(lat),\(lon)"]
        )
        
        if !result.isEmpty {
            print("iOS Simulator (\(udid)) location sent: \(lat), \(lon) - \(result)")
        } else {
            print("iOS Simulator (\(udid)) location sent: \(lat), \(lon)")
        }
    }
    
    // MARK: - Android Emulator
    
    private func sendToAndroidEmulator(_ coordinate: CLLocationCoordinate2D, deviceId: String) async {
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        
        // Find adb path
        guard let adbPath = await findADBPath() else {
            print("ADB not found")
            return
        }
        
        // adb -s <device> emu geo fix <longitude> <latitude>
        // Note: Android's geo fix takes longitude first, then latitude
        let result = await runShellCommand(
            adbPath,
            arguments: ["-s", deviceId, "emu", "geo", "fix", "\(lon)", "\(lat)"]
        )
        
        if !result.isEmpty {
            print("Android Emulator (\(deviceId)) location sent: \(lat), \(lon) - \(result)")
        } else {
            print("Android Emulator (\(deviceId)) location sent: \(lat), \(lon)")
        }
    }
    
    // MARK: - Helpers
    
    private func findADBPath() async -> String? {
        let adbPaths = [
            "/usr/local/bin/adb",
            "\(NSHomeDirectory())/Library/Android/sdk/platform-tools/adb",
            "/opt/homebrew/bin/adb"
        ]
        
        for path in adbPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        // Try finding adb in PATH
        let whichResult = await runShellCommand("/usr/bin/which", arguments: ["adb"])
        let trimmed = whichResult.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && FileManager.default.fileExists(atPath: trimmed) {
            return trimmed
        }
        
        return nil
    }
    
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

