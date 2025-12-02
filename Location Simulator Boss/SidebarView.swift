//
//  SidebarView.swift
//  Location Simulator Boss
//
//  Created by Yugo Ogura on 2025-12-02.
//

import SwiftUI

struct SidebarView: View {
    @Bindable var deviceManager: DeviceManager
    @Bindable var favoritesManager: FavoritesManager
    var onSelectFavorite: (FavoriteRoute) -> Void
    var onEditFavorite: (FavoriteRoute) -> Void
    
    var body: some View {
        List {
            // Favorite Routes Section
            Section("Favorite Routes") {
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
    }
}

struct FavoriteRouteRow: View {
    let route: FavoriteRoute
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
                Text(route.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                HStack(spacing: 4) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(.green)
                    Text(route.startName)
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                
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
