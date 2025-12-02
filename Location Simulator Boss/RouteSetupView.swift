//
//  RouteSetupView.swift
//  Location Simulator Boss
//
//  Created by Yugo Ogura on 2025-12-02.
//

import SwiftUI
import MapKit

struct RouteSetupView: View {
    @Bindable var routeSimulator: RouteSimulator
    @Bindable var favoritesManager: FavoritesManager
    var onStartRoute: () -> Void
    var onDismiss: () -> Void
    
    @State private var startSearchText: String = ""
    @State private var endSearchText: String = ""
    @State private var startSearchResults: [MKMapItem] = []
    @State private var endSearchResults: [MKMapItem] = []
    @State private var isSearchingStart: Bool = false
    @State private var isSearchingEnd: Bool = false
    @State private var showStartResults: Bool = false
    @State private var showEndResults: Bool = false
    @State private var isCalculatingRoute: Bool = false
    @State private var routeError: String?
    @State private var showSaveDialog: Bool = false
    @State private var favoriteName: String = ""
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Route Simulation")
                    .font(.headline)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Start Location
            VStack(alignment: .leading, spacing: 8) {
                Label("Start Location", systemImage: "circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)
                
                LocationSearchField(
                    searchText: $startSearchText,
                    searchResults: $startSearchResults,
                    isSearching: $isSearchingStart,
                    showResults: $showStartResults,
                    selectedItem: routeSimulator.startLocation,
                    placeholder: "Search start location...",
                    onSelect: { item in
                        routeSimulator.startLocation = item
                        startSearchText = item.name ?? ""
                        showStartResults = false
                        routeError = nil
                    }
                )
            }
            
            // End Location
            VStack(alignment: .leading, spacing: 8) {
                Label("End Location", systemImage: "mappin.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                
                LocationSearchField(
                    searchText: $endSearchText,
                    searchResults: $endSearchResults,
                    isSearching: $isSearchingEnd,
                    showResults: $showEndResults,
                    selectedItem: routeSimulator.endLocation,
                    placeholder: "Search end location...",
                    onSelect: { item in
                        routeSimulator.endLocation = item
                        endSearchText = item.name ?? ""
                        showEndResults = false
                        routeError = nil
                    }
                )
            }
            
            // Speed control
            VStack(alignment: .leading, spacing: 8) {
                Label("Speed: \(Int(routeSimulator.speedMetersPerSecond * 3.6)) km/h", systemImage: "speedometer")
                    .font(.subheadline)
                
                Slider(value: $routeSimulator.speedMetersPerSecond, in: 2.8...55.6) // 10-200 km/h
                    .tint(.blue)
            }
            
            // Error message
            if let error = routeError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            
            Divider()
            
            // Action buttons
            HStack {
                Button("Reset") {
                    routeSimulator.reset()
                    startSearchText = ""
                    endSearchText = ""
                    routeError = nil
                }
                .disabled(isCalculatingRoute)
                
                Spacer()
                
                if routeSimulator.hasRoute {
                    // Save to favorites button
                    Button(action: {
                        favoriteName = "\(routeSimulator.startLocation?.name ?? "Start") → \(routeSimulator.endLocation?.name ?? "End")"
                        showSaveDialog = true
                    }) {
                        Image(systemName: "star")
                    }
                    .help("Save to Favorites")
                    
                    Button("Start Route") {
                        onStartRoute()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Calculate Route") {
                        calculateRoute()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!routeSimulator.canCalculateRoute || isCalculatingRoute)
                }
            }
            
            // Route info
            if let route = routeSimulator.route {
                HStack {
                    Label(formatDistance(route.distance), systemImage: "arrow.triangle.swap")
                    Spacer()
                    Label(formatDuration(route.expectedTravelTime), systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            if isCalculatingRoute {
                ProgressView("Calculating route...")
                    .font(.caption)
            }
        }
        .padding()
        .frame(width: 320)
        .sheet(isPresented: $showSaveDialog) {
            SaveFavoriteView(
                name: $favoriteName,
                onSave: {
                    saveToFavorites()
                    showSaveDialog = false
                },
                onCancel: {
                    showSaveDialog = false
                }
            )
        }
    }
    
    private func calculateRoute() {
        isCalculatingRoute = true
        routeError = nil
        
        Task {
            let success = await routeSimulator.calculateRoute()
            
            await MainActor.run {
                isCalculatingRoute = false
                if !success {
                    routeError = "Could not calculate route. Try different locations."
                }
            }
        }
    }
    
    private func saveToFavorites() {
        guard let start = routeSimulator.startLocation,
              let end = routeSimulator.endLocation else { return }
        
        let favorite = FavoriteRoute(
            name: favoriteName,
            startName: start.name ?? "Unknown",
            startCoordinate: start.placemark.coordinate,
            endName: end.name ?? "Unknown",
            endCoordinate: end.placemark.coordinate
        )
        
        favoritesManager.addFavorite(favorite)
    }
    
    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        } else {
            return String(format: "%.0f m", meters)
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) min"
        }
    }
}

struct SaveFavoriteView: View {
    @Binding var name: String
    var onSave: () -> Void
    var onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Save to Favorites")
                .font(.headline)
            
            TextField("Route name", text: $name)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Button("Cancel", action: onCancel)
                
                Spacer()
                
                Button("Save", action: onSave)
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 280)
    }
}

struct LocationSearchField: View {
    @Binding var searchText: String
    @Binding var searchResults: [MKMapItem]
    @Binding var isSearching: Bool
    @Binding var showResults: Bool
    let selectedItem: MKMapItem?
    let placeholder: String
    let onSelect: (MKMapItem) -> Void
    
    @State private var searchError: String?
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                TextField(placeholder, text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        performSearch()
                    }
                
                // Search button
                Button(action: { performSearch() }) {
                    Image(systemName: "magnifyingglass")
                }
                .disabled(searchText.isEmpty || isSearching)
                
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.7)
                } else if selectedItem != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            
            // Show error if any
            if let error = searchError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            
            // Always show results if we have them
            if !searchResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(searchResults.prefix(5)), id: \.self) { item in
                        Button(action: { 
                            onSelect(item)
                            searchResults = []
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name ?? "Unknown")
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    
                                    if let address = formatAddress(item.placemark) {
                                        Text(address)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        if item != searchResults.prefix(5).last {
                            Divider()
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
    
    private func formatAddress(_ placemark: MKPlacemark) -> String? {
        let components = [
            placemark.subThoroughfare,
            placemark.thoroughfare,
            placemark.locality,
            placemark.administrativeArea,
            placemark.country
        ].compactMap { $0 }
        
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        searchError = nil
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        
        let search = MKLocalSearch(request: request)
        
        Task { @MainActor in
            do {
                let response = try await search.start()
                self.searchResults = response.mapItems
                self.isSearching = false
                print("Found \(response.mapItems.count) results")
            } catch {
                self.searchResults = []
                self.isSearching = false
                self.searchError = "Search failed: \(error.localizedDescription)"
                print("Search error: \(error)")
            }
        }
    }
}

#Preview {
    RouteSetupView(
        routeSimulator: RouteSimulator(),
        favoritesManager: FavoritesManager(),
        onStartRoute: {},
        onDismiss: {}
    )
}
