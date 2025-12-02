//
//  SidebarView.swift
//  Location Simulator Boss
//
//  Created by Yugo Ogura on 2025-12-02.
//

import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @Bindable var deviceManager: DeviceManager
    @Bindable var favoritesManager: FavoritesManager
    var onSelectFavorite: (FavoriteRoute) -> Void
    var onEditFavorite: (FavoriteRoute) -> Void
    
    @State private var showImportError = false
    @State private var importErrorMessage = ""
    
    var body: some View {
        List {
            // Favorite Routes Section
            Section {
                if favoritesManager.favoriteRoutes.isEmpty {
                    Text("No saved routes")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(favoritesManager.favoriteRoutes) { route in
                        FavoriteRouteRow(route: route) {
                            onSelectFavorite(route)
                        }
                        .contextMenu {
                            Button {
                                onEditFavorite(route)
                            } label: {
                                Label("Edit Route", systemImage: "pencil")
                            }
                            
                            Button {
                                exportRoute(route)
                            } label: {
                                Label("Export Route", systemImage: "square.and.arrow.up")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                favoritesManager.removeFavorite(route)
                            } label: {
                                Label("Delete Route", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete { offsets in
                        favoritesManager.removeFavorite(at: offsets)
                    }
                }
            } header: {
                HStack {
                    Text("Favorite Routes")
                    Spacer()
                    Button(action: importRoute) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("Import Route")
                }
            }
            
            // Devices Section
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
        .alert("Import Error", isPresented: $showImportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(importErrorMessage)
        }
    }
    
    private func exportRoute(_ route: FavoriteRoute) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "\(route.name).json"
        savePanel.title = "Export Route"
        savePanel.message = "Choose where to save the route"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    let data = try encoder.encode(route)
                    try data.write(to: url)
                } catch {
                    print("Export error: \(error)")
                }
            }
        }
    }
    
    private func importRoute() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = true
        openPanel.title = "Import Route"
        openPanel.message = "Select route file(s) to import"
        
        openPanel.begin { response in
            if response == .OK {
                for url in openPanel.urls {
                    do {
                        let data = try Data(contentsOf: url)
                        let decoder = JSONDecoder()
                        let route = try decoder.decode(FavoriteRoute.self, from: data)
                        
                        // Create a new route with a new ID to avoid conflicts
                        let importedRoute = FavoriteRoute(
                            name: route.name,
                            startName: route.startName,
                            startCoordinate: route.startCoordinate,
                            endName: route.endName,
                            endCoordinate: route.endCoordinate,
                            waypoints: route.waypoints
                        )
                        favoritesManager.addFavorite(importedRoute)
                    } catch {
                        importErrorMessage = "Failed to import \(url.lastPathComponent): \(error.localizedDescription)"
                        showImportError = true
                    }
                }
            }
        }
    }
}

struct FavoriteRouteRow: View {
    let route: FavoriteRoute
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(route.name)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    if !route.waypoints.isEmpty {
                        Text("+\(route.waypoints.count)")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.orange, in: Capsule())
                    }
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(.green)
                    Text(route.startName)
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                
                // Show waypoints if any
                ForEach(route.waypoints) { waypoint in
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.system(size: 6))
                            .foregroundStyle(.orange)
                        Text(waypoint.name)
                            .lineLimit(1)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(.red)
                    Text(route.endName)
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
    SidebarView(
        deviceManager: DeviceManager(),
        favoritesManager: FavoritesManager(),
        onSelectFavorite: { _ in },
        onEditFavorite: { _ in }
    )
    .frame(width: 250)
}
