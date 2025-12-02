//
//  SidebarView.swift
//  Location Simulator Boss
//
//  Created by Yugo Ogura on 2025-12-02.
//

import SwiftUI

struct SidebarView: View {
    @Bindable var deviceManager: DeviceManager
    
    var body: some View {
        List {
            Section("Devices (\(deviceManager.devices.count))") {
                if deviceManager.devices.isEmpty {
                    if deviceManager.isScanning {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Scanning...")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("No devices found")
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                } else {
                    // iOS Simulators
                    let iosDevices = deviceManager.devices.filter { $0.type == .iOSSimulator }
                    if !iosDevices.isEmpty {
                        DeviceSection(title: "iOS Simulators", devices: iosDevices)
                    }
                    
                    // Android Emulators
                    let androidDevices = deviceManager.devices.filter { $0.type == .androidEmulator }
                    if !androidDevices.isEmpty {
                        DeviceSection(title: "Android Emulators", devices: androidDevices)
                    }
                }
            }
            
            Section {
                Button(action: {
                    deviceManager.scanDevices()
                }) {
                    Label("Refresh Devices", systemImage: "arrow.clockwise")
                }
                .disabled(deviceManager.isScanning)
            }
        }
        .listStyle(.sidebar)
    }
}

struct DeviceSection: View {
    let title: String
    let devices: [Device]
    
    var body: some View {
        DisclosureGroup(title) {
            ForEach(devices) { device in
                Text(device.displayName)
                    .lineLimit(1)
            }
        }
    }
}

#Preview {
    SidebarView(deviceManager: DeviceManager())
        .frame(width: 250)
}
