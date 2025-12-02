//
//  ContentView.swift
//  Location Simulator Boss
//
//  Created by Yugo Ogura on 2025-12-02.
//

import SwiftUI
import MapKit

struct ContentView: View {
    @State private var deviceManager = DeviceManager()
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var lastSentStatus: String?
    
    var body: some View {
        NavigationSplitView {
            SidebarView(deviceManager: deviceManager)
                .navigationSplitViewColumnWidth(min: 200, ideal: 250)
        } detail: {
            LocationMapView(selectedCoordinate: $selectedCoordinate) { coordinate in
                sendLocationToAllDevices(coordinate)
            }
            .overlay(alignment: .top) {
                StatusBanner(status: lastSentStatus)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
    
    private func sendLocationToAllDevices(_ coordinate: CLLocationCoordinate2D) {
        let devices = deviceManager.devices
        
        if devices.isEmpty {
            lastSentStatus = "No devices found"
            clearStatusAfterDelay()
            return
        }
        
        Task {
            await LocationSender.shared.sendLocation(coordinate, to: devices)
            
            await MainActor.run {
                lastSentStatus = "Sent to \(devices.count) device(s)"
                clearStatusAfterDelay()
            }
        }
    }
    
    private func clearStatusAfterDelay() {
        Task {
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run {
                lastSentStatus = nil
            }
        }
    }
}

struct StatusBanner: View {
    let status: String?
    
    var body: some View {
        if let status = status {
            Text(status)
                .font(.callout)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut, value: status)
        }
    }
}

#Preview {
    ContentView()
}
