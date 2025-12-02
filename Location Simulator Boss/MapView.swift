//
//  MapView.swift
//  Location Simulator Boss
//
//  Created by Yugo Ogura on 2025-12-02.
//

import SwiftUI
import MapKit

struct LocationMapView: View {
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    @Bindable var routeSimulator: RouteSimulator
    @Bindable var favoritesManager: FavoritesManager
    var onLocationSelected: (CLLocationCoordinate2D) -> Void
    
    @State private var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503), // Tokyo
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    ))
    
    @State private var searchText: String = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching: Bool = false
    @State private var showResults: Bool = false
    
    @State private var showRouteSetup: Bool = false
    
    var body: some View {
        ZStack(alignment: .top) {
            // Map
            MapReader { proxy in
                Map(position: $cameraPosition) {
                    // Selected location marker (only when not simulating/paused and no route location)
                    if let coordinate = selectedCoordinate,
                       !routeSimulator.isSimulating,
                       !routeSimulator.isPaused,
                       routeSimulator.currentLocation == nil {
                        Marker("Selected Location", coordinate: coordinate)
                            .tint(.red)
                    }
                    
                    // Route polyline
                    if let route = routeSimulator.route {
                        MapPolyline(route.polyline)
                            .stroke(.blue, lineWidth: 5)
                    }
                    
                    // Start marker (only when route exists)
                    if routeSimulator.route != nil, let start = routeSimulator.startLocation {
                        Marker("Start", coordinate: start.placemark.coordinate)
                            .tint(.green)
                    }
                    
                    // End marker (only when route exists)
                    if routeSimulator.route != nil, let end = routeSimulator.endLocation {
                        Marker("End", coordinate: end.placemark.coordinate)
                            .tint(.red)
                    }
                    
                    // Current location marker (during simulation, paused, or after stop)
                    if let current = routeSimulator.currentLocation {
                        Annotation("", coordinate: current) {
                            ZStack {
                                Circle()
                                    .fill(routeSimulator.isPaused ? .orange : .blue)
                                    .frame(width: 20, height: 20)
                                Circle()
                                    .fill(.white)
                                    .frame(width: 10, height: 10)
                            }
                        }
                    }
                }
                .mapStyle(.standard)
                .onTapGesture { screenPoint in
                    // Ignore taps during simulation
                    guard !routeSimulator.isSimulating else { return }
                    
                    if let coordinate = proxy.convert(screenPoint, from: .local) {
                        selectedCoordinate = coordinate
                        showResults = false
                        
                        // Fire and forget to avoid blocking
                        Task {
                            onLocationSelected(coordinate)
                        }
                    }
                }
            }
            
            // Search overlay
            VStack(spacing: 0) {
                // Search field + Route button
                HStack(spacing: 8) {
                    // Search field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        
                        TextField("Search location...", text: $searchText)
                            .textFieldStyle(.plain)
                            .onSubmit {
                                performSearch()
                            }
                            .disabled(routeSimulator.isSimulating)
                        
                        if isSearching {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                searchResults = []
                                showResults = false
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                    .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 10))
                    
                    // Route button
                    Button(action: {
                        showRouteSetup.toggle()
                    }) {
                        Image(systemName: routeSimulator.hasRoute ? "point.topleft.down.to.point.bottomright.curvepath.fill" : "point.topleft.down.to.point.bottomright.curvepath")
                            .font(.system(size: 16))
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                    .background(routeSimulator.hasRoute ? Color.blue.opacity(0.2) : Color.clear)
                    .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
                .sheet(isPresented: $showRouteSetup) {
                    RouteSetupView(
                        routeSimulator: routeSimulator,
                        favoritesManager: favoritesManager,
                        onStartRoute: {
                            startRouteSimulation()
                            showRouteSetup = false
                        },
                        onDismiss: {
                            showRouteSetup = false
                        }
                    )
                }
                
                // Search results
                if showResults && !searchResults.isEmpty {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(searchResults, id: \.self) { item in
                                SearchResultRow(item: item) {
                                    selectSearchResult(item)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 250)
                    .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding()
            .frame(maxWidth: 450)
            
            // Route simulation controls
            if routeSimulator.hasRoute {
                VStack {
                    Spacer()
                    RouteControlsView(
                        routeSimulator: routeSimulator,
                        onStart: { startRouteSimulation() },
                        onPause: { routeSimulator.pauseSimulation() },
                        onResume: { resumeRouteSimulation() },
                        onStop: { routeSimulator.stopSimulation() }
                    )
                    .padding()
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            CoordinateOverlay(coordinate: routeSimulator.isSimulating ? routeSimulator.currentLocation : selectedCoordinate)
                .padding()
        }
        .onChange(of: searchText) { _, newValue in
            if newValue.isEmpty {
                searchResults = []
                showResults = false
            }
        }
        .onChange(of: routeSimulator.route) { _, newRoute in
            if let route = newRoute {
                // Fit map to show the entire route
                let rect = route.polyline.boundingMapRect
                let region = MKCoordinateRegion(rect)
                // Add some padding by increasing the span
                let paddedRegion = MKCoordinateRegion(
                    center: region.center,
                    span: MKCoordinateSpan(
                        latitudeDelta: region.span.latitudeDelta * 1.3,
                        longitudeDelta: region.span.longitudeDelta * 1.3
                    )
                )
                cameraPosition = .region(paddedRegion)
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        showResults = true
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        
        let search = MKLocalSearch(request: request)
        
        Task {
            do {
                let response = try await search.start()
                await MainActor.run {
                    searchResults = response.mapItems
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    searchResults = []
                    isSearching = false
                }
            }
        }
    }
    
    private func selectSearchResult(_ item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        selectedCoordinate = coordinate
        
        // Move camera to selected location
        cameraPosition = .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
        
        // Send location to devices
        onLocationSelected(coordinate)
        
        // Clear search
        showResults = false
        searchText = item.name ?? ""
    }
    
    private func startRouteSimulation() {
        routeSimulator.startSimulation { coordinate in
            onLocationSelected(coordinate)
        }
    }
    
    private func resumeRouteSimulation() {
        routeSimulator.resumeSimulation { coordinate in
            onLocationSelected(coordinate)
        }
    }
}

struct RouteControlsView: View {
    @Bindable var routeSimulator: RouteSimulator
    var onStart: () -> Void
    var onPause: () -> Void
    var onResume: () -> Void
    var onStop: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Progress bar
            ProgressView(value: routeSimulator.progress)
                .tint(.blue)
            
            // Status text
            if routeSimulator.isPaused {
                Text("Paused")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            
            HStack(spacing: 16) {
                // Stop button - clears route and keeps current location
                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(!routeSimulator.isSimulating && !routeSimulator.isPaused)
                .help("Stop and clear route")
                
                // Play/Pause button
                Button(action: {
                    if routeSimulator.isSimulating {
                        onPause()
                    } else if routeSimulator.canResume {
                        onResume()
                    } else {
                        onStart()
                    }
                }) {
                    Image(systemName: routeSimulator.isSimulating ? "pause.fill" : "play.fill")
                        .font(.title)
                }
                .buttonStyle(.borderedProminent)
                
                // Speed controls
                HStack(spacing: 8) {
                    Button(action: decreaseSpeed) {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.plain)
                    .disabled(routeSimulator.speedMetersPerSecond <= 2.8)
                    
                    Text("\(Int(routeSimulator.speedMetersPerSecond * 3.6))")
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 40)
                    
                    Button(action: increaseSpeed) {
                        Image(systemName: "plus.circle")
                    }
                    .buttonStyle(.plain)
                    .disabled(routeSimulator.speedMetersPerSecond >= 55.6)
                    
                    Text("km/h")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: 350)
    }
    
    private func increaseSpeed() {
        // Increase by ~10 km/h (2.78 m/s)
        routeSimulator.speedMetersPerSecond = min(55.6, routeSimulator.speedMetersPerSecond + 2.78)
    }
    
    private func decreaseSpeed() {
        // Decrease by ~10 km/h (2.78 m/s)
        routeSimulator.speedMetersPerSecond = max(2.8, routeSimulator.speedMetersPerSecond - 2.78)
    }
}

struct SearchResultRow: View {
    let item: MKMapItem
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name ?? "Unknown")
                    .font(.body)
                    .foregroundStyle(.primary)
                
                if let address = item.placemark.formattedAddress {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct CoordinateOverlay: View {
    let coordinate: CLLocationCoordinate2D?
    
    var body: some View {
        if let coord = coordinate {
            VStack(alignment: .trailing, spacing: 4) {
                Text("Lat: \(coord.latitude, specifier: "%.6f")")
                Text("Lon: \(coord.longitude, specifier: "%.6f")")
            }
            .font(.system(.caption, design: .monospaced))
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Extensions

extension MKPlacemark {
    var formattedAddress: String? {
        let components = [
            subThoroughfare,
            thoroughfare,
            locality,
            administrativeArea,
            country
        ].compactMap { $0 }
        
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
}

#Preview {
    LocationMapView(
        selectedCoordinate: .constant(nil),
        routeSimulator: RouteSimulator(),
        favoritesManager: FavoritesManager()
    ) { coordinate in
        print("Selected: \(coordinate)")
    }
}
