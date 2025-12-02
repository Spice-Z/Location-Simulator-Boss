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
    @State private var waypoints: [EditableWaypoint] = []
    
    var body: some View {
        VStack(spacing: 0) {
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
            .padding()
            
            Divider()
            
            // Scrollable content
            ScrollView {
                VStack(spacing: 16) {
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
                    
                    // Waypoints Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Waypoints", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                            
                            Spacer()
                            
                            Button(action: addWaypoint) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.orange)
                            }
                            .buttonStyle(.plain)
                            .help("Add waypoint")
                        }
                        
                        if waypoints.isEmpty {
                            Text("No waypoints. Click + to add a stop.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .italic()
                                .padding(.vertical, 4)
                        } else {
                            ForEach(Array(waypoints.enumerated()), id: \.element.id) { index, waypoint in
                                WaypointEditRow(
                                    waypoint: $waypoints[index],
                                    index: index + 1,
                                    onDelete: {
                                        waypoints.remove(at: index)
                                    }
                                )
                            }
                        }
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
                    
                    // Route info
                    if routeSimulator.hasRoute {
                        HStack {
                            Label(formatDistance(routeSimulator.displayDistance), systemImage: "arrow.triangle.swap")
                            Spacer()
                            Label(formatDuration(routeSimulator.displayTravelTime), systemImage: "clock")
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
            }
            
            Divider()
            
            // Action buttons
            HStack {
                Button("Reset") {
                    routeSimulator.reset()
                    startSearchText = ""
                    endSearchText = ""
                    waypoints = []
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
            .padding()
        }
        .frame(width: 380, height: 520)
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
    
    private func addWaypoint() {
        waypoints.append(EditableWaypoint())
    }
    
    private func calculateRoute() {
        isCalculatingRoute = true
        routeError = nil
        
        // Convert valid waypoints to Waypoint structs
        let validWaypoints = waypoints.compactMap { editable -> Waypoint? in
            guard let coord = editable.coordinate, !editable.name.isEmpty else { return nil }
            return Waypoint(id: editable.id, name: editable.name, coordinate: coord)
        }
        
        Task {
            let success: Bool
            if validWaypoints.isEmpty {
                success = await routeSimulator.calculateRoute()
            } else {
                success = await routeSimulator.calculateRouteWithWaypoints(validWaypoints)
            }
            
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
        
        // Convert valid waypoints to Waypoint structs
        let validWaypoints = waypoints.compactMap { editable -> Waypoint? in
            guard let coord = editable.coordinate, !editable.name.isEmpty else { return nil }
            return Waypoint(id: editable.id, name: editable.name, coordinate: coord)
        }
        
        let favorite = FavoriteRoute(
            name: favoriteName,
            startName: start.name ?? "Unknown",
            startCoordinate: start.placemark.coordinate,
            endName: end.name ?? "Unknown",
            endCoordinate: end.placemark.coordinate,
            waypoints: validWaypoints
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

// Helper struct to track waypoint editing state
struct EditableWaypoint: Identifiable {
    let id: UUID
    var name: String
    var coordinate: CLLocationCoordinate2D?
    var searchText: String
    var searchResults: [MKMapItem] = []
    var isSearching: Bool = false
    
    init(from waypoint: Waypoint) {
        self.id = waypoint.id
        self.name = waypoint.name
        self.coordinate = waypoint.coordinate
        self.searchText = waypoint.name
    }
    
    init() {
        self.id = UUID()
        self.name = ""
        self.coordinate = nil
        self.searchText = ""
    }
    
    var isValid: Bool {
        coordinate != nil && !name.isEmpty
    }
}

struct EditFavoriteRouteView: View {
    @Bindable var favoritesManager: FavoritesManager
    let route: FavoriteRoute
    var onDismiss: () -> Void
    
    @State private var editedName: String
    @State private var startSearchText: String
    @State private var endSearchText: String
    @State private var startSearchResults: [MKMapItem] = []
    @State private var endSearchResults: [MKMapItem] = []
    @State private var isSearchingStart: Bool = false
    @State private var isSearchingEnd: Bool = false
    @State private var startName: String
    @State private var endName: String
    @State private var startCoordinate: CLLocationCoordinate2D
    @State private var endCoordinate: CLLocationCoordinate2D
    @State private var hasChangedStart: Bool = false
    @State private var hasChangedEnd: Bool = false
    @State private var waypoints: [EditableWaypoint]
    
    init(favoritesManager: FavoritesManager, route: FavoriteRoute, onDismiss: @escaping () -> Void) {
        self.favoritesManager = favoritesManager
        self.route = route
        self.onDismiss = onDismiss
        // Initialize state with route values
        _editedName = State(initialValue: route.name)
        _startSearchText = State(initialValue: route.startName)
        _endSearchText = State(initialValue: route.endName)
        _startName = State(initialValue: route.startName)
        _endName = State(initialValue: route.endName)
        _startCoordinate = State(initialValue: route.startCoordinate)
        _endCoordinate = State(initialValue: route.endCoordinate)
        _waypoints = State(initialValue: route.waypoints.map { EditableWaypoint(from: $0) })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Route")
                    .font(.headline)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            // Scrollable content
            ScrollView {
                VStack(spacing: 16) {
                    // Route Name
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Route Name", systemImage: "tag")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        
                        TextField("Route name", text: $editedName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    // Start Location
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Start Location", systemImage: "circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                            
                            Spacer()
                            
                            if !hasChangedStart {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            }
                        }
                        
                        EditLocationSearchField(
                            searchText: $startSearchText,
                            searchResults: $startSearchResults,
                            isSearching: $isSearchingStart,
                            placeholder: "Type and press Enter...",
                            onSelect: { item in
                                startSearchText = item.name ?? ""
                                startName = item.name ?? "Unknown"
                                startCoordinate = item.placemark.coordinate
                                hasChangedStart = true
                            }
                        )
                    }
                    
                    // Waypoints Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Waypoints", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                            
                            Spacer()
                            
                            Button(action: addWaypoint) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.orange)
                            }
                            .buttonStyle(.plain)
                            .help("Add waypoint")
                        }
                        
                        if waypoints.isEmpty {
                            Text("No waypoints. Click + to add a stop.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .italic()
                                .padding(.vertical, 4)
                        } else {
                            ForEach(Array(waypoints.enumerated()), id: \.element.id) { index, waypoint in
                                WaypointEditRow(
                                    waypoint: $waypoints[index],
                                    index: index + 1,
                                    onDelete: {
                                        waypoints.remove(at: index)
                                    }
                                )
                            }
                        }
                    }
                    
                    // End Location
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("End Location", systemImage: "mappin.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.red)
                            
                            Spacer()
                            
                            if !hasChangedEnd {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            }
                        }
                        
                        EditLocationSearchField(
                            searchText: $endSearchText,
                            searchResults: $endSearchResults,
                            isSearching: $isSearchingEnd,
                            placeholder: "Type and press Enter...",
                            onSelect: { item in
                                endSearchText = item.name ?? ""
                                endName = item.name ?? "Unknown"
                                endCoordinate = item.placemark.coordinate
                                hasChangedEnd = true
                            }
                        )
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Action buttons
            HStack {
                Button("Cancel", action: onDismiss)
                
                Spacer()
                
                Button("Save Changes") {
                    saveChanges()
                }
                .buttonStyle(.borderedProminent)
                .disabled(editedName.isEmpty)
            }
            .padding()
        }
        .frame(width: 400, height: 550)
    }
    
    private func addWaypoint() {
        waypoints.append(EditableWaypoint())
    }
    
    private func saveChanges() {
        var updatedRoute = route
        updatedRoute.name = editedName
        updatedRoute.startName = startName
        updatedRoute.endName = endName
        updatedRoute.startLatitude = startCoordinate.latitude
        updatedRoute.startLongitude = startCoordinate.longitude
        updatedRoute.endLatitude = endCoordinate.latitude
        updatedRoute.endLongitude = endCoordinate.longitude
        
        // Convert valid editable waypoints to Waypoint structs
        updatedRoute.waypoints = waypoints.compactMap { editable in
            guard let coord = editable.coordinate, !editable.name.isEmpty else { return nil }
            return Waypoint(id: editable.id, name: editable.name, coordinate: coord)
        }
        
        favoritesManager.updateFavorite(updatedRoute)
        onDismiss()
    }
}

struct WaypointEditRow: View {
    @Binding var waypoint: EditableWaypoint
    let index: Int
    let onDelete: () -> Void
    
    @State private var searchError: String?
    @State private var hasSearched: Bool = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Waypoint number indicator
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.2))
                    .frame(width: 24, height: 24)
                Text("\(index)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.orange)
            }
            
            // Search field
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    TextField("Type and press Enter...", text: $waypoint.searchText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            performSearch()
                        }
                    
                    Button(action: performSearch) {
                        Image(systemName: "magnifyingglass")
                    }
                    .disabled(waypoint.searchText.isEmpty || waypoint.isSearching)
                    .help("Search")
                    
                    if waypoint.isSearching {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else if waypoint.isValid {
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
                
                // Show "no results" message
                if hasSearched && waypoint.searchResults.isEmpty && !waypoint.isSearching && searchError == nil {
                    Text("No results found")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                }
                
                // Search results
                if !waypoint.searchResults.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(waypoint.searchResults.prefix(5)), id: \.self) { item in
                            Button(action: {
                                waypoint.name = item.name ?? "Unknown"
                                waypoint.searchText = item.name ?? ""
                                waypoint.coordinate = item.placemark.coordinate
                                waypoint.searchResults = []
                                hasSearched = false
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
                            
                            if item != waypoint.searchResults.prefix(5).last {
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
            
            // Delete button
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help("Remove waypoint")
        }
        .padding(.vertical, 4)
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
        let query = waypoint.searchText
        guard !query.isEmpty else { return }
        
        waypoint.isSearching = true
        searchError = nil
        hasSearched = true
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        
        let search = MKLocalSearch(request: request)
        
        Task {
            do {
                let response = try await search.start()
                await MainActor.run {
                    waypoint.searchResults = response.mapItems
                    waypoint.isSearching = false
                }
            } catch {
                await MainActor.run {
                    waypoint.searchResults = []
                    waypoint.isSearching = false
                    searchError = "Search failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

// Simplified search field for editing (without the selectedItem parameter)
struct EditLocationSearchField: View {
    @Binding var searchText: String
    @Binding var searchResults: [MKMapItem]
    @Binding var isSearching: Bool
    let placeholder: String
    let onSelect: (MKMapItem) -> Void
    
    @State private var searchError: String?
    @State private var hasSearched: Bool = false
    
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
                .help("Search (or press Enter)")
                
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            
            // Show error if any
            if let error = searchError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            
            // Show "no results" message
            if hasSearched && searchResults.isEmpty && !isSearching && searchError == nil {
                Text("No results found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }
            
            // Always show results if we have them
            if !searchResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(searchResults.prefix(5)), id: \.self) { item in
                        Button(action: { 
                            onSelect(item)
                            searchResults = []
                            hasSearched = false
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
        let query = searchText
        guard !query.isEmpty else { return }
        
        isSearching = true
        searchError = nil
        hasSearched = true
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        
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
                    searchError = "Search failed: \(error.localizedDescription)"
                }
            }
        }
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
