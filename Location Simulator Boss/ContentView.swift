//
//  ContentView.swift
//  Location Simulator Boss
//
//  Created by Yugo Ogura on 2025-12-02.
//

import SwiftUI
import MapKit

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    
    @State private var deviceManager = DeviceManager()
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var lastSentStatus: String?
    @State private var isLoadingFavorite: Bool = false
    
    private var favoritesManager: FavoritesManager { appState.favoritesManager }
    private var routeSimulator: RouteSimulator { appState.routeSimulator }
    
    var body: some View {
        NavigationSplitView {
            SidebarView(
                deviceManager: deviceManager,
                favoritesManager: favoritesManager,
                onSelectFavorite: { favorite in
                    loadFavoriteRoute(favorite)
                },
                onEditFavorite: { favorite in
                    openRouteEditor(for: favorite)
                }
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 250)
        } detail: {
            ZStack {
                LocationMapView(
                    selectedCoordinate: $selectedCoordinate,
                    routeSimulator: routeSimulator,
                    favoritesManager: favoritesManager,
                    onOpenRouteEditor: {
                        openRouteEditor()
                    }
                ) { coordinate in
                    sendLocationToAllDevices(coordinate)
                }
                .overlay(alignment: .top) {
                    StatusBanner(status: lastSentStatus)
                }
                
                if isLoadingFavorite {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack {
                        ProgressView()
                        Text("Loading route...")
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onChange(of: appState.shouldStartSimulation) { _, shouldStart in
            if shouldStart {
                startRouteSimulation()
                appState.shouldStartSimulation = false
            }
        }
    }
    
    private func openRouteEditor(for route: FavoriteRoute? = nil) {
        if let route = route {
            openWindow(id: "route-editor", value: RouteEditorData(mode: .edit(route)))
        } else {
            openWindow(id: "route-editor", value: RouteEditorData(mode: .create))
        }
    }
    
    private func loadFavoriteRoute(_ favorite: FavoriteRoute) {
        isLoadingFavorite = true
        
        Task {
            let success = await routeSimulator.loadFromFavorite(favorite)
            
            await MainActor.run {
                isLoadingFavorite = false
                
                if success {
                    lastSentStatus = "Route loaded: \(favorite.name)"
                } else {
                    lastSentStatus = "Failed to load route"
                }
                clearStatusAfterDelay()
            }
        }
    }
    
    private func startRouteSimulation() {
        routeSimulator.startSimulation { coordinate in
            sendLocationToAllDevices(coordinate)
        }
    }
    
    private func sendLocationToAllDevices(_ coordinate: CLLocationCoordinate2D) {
        let devices = deviceManager.devices
        
        if devices.isEmpty {
            // Only show status if not simulating (to avoid spam)
            if !routeSimulator.isSimulating {
                lastSentStatus = "No devices found"
                clearStatusAfterDelay()
            }
            return
        }
        
        // Use detached task to avoid blocking
        Task.detached {
            await LocationSender.shared.sendLocation(coordinate, to: devices)
        }
        
        // Only show status if not simulating (to avoid spam and main thread pressure)
        if !routeSimulator.isSimulating {
            lastSentStatus = "Sent to \(devices.count) device(s)"
            clearStatusAfterDelay()
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
        .environment(AppState())
}
