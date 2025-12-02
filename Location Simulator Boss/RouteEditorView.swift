//
//  RouteEditorView.swift
//  Location Simulator Boss
//
//  Created by Yugo Ogura on 2025-12-02.
//

import SwiftUI
import MapKit

// Mode for the route editor
enum RouteEditorMode: Equatable {
    case create
    case edit(FavoriteRoute)
}

// Selection state for map placement
enum MapPlacementSelection: Equatable {
    case none
    case start
    case end
    case waypoint(UUID)
}

// Editable waypoint for the route editor
class EditableWaypoint: Identifiable, ObservableObject {
    let id: UUID
    @Published var name: String
    @Published var searchText: String
    @Published var coordinate: CLLocationCoordinate2D?
    
    var isValid: Bool {
        coordinate != nil && !name.isEmpty
    }
    
    init(id: UUID = UUID(), name: String = "", searchText: String = "", coordinate: CLLocationCoordinate2D? = nil) {
        self.id = id
        self.name = name
        self.searchText = searchText
        self.coordinate = coordinate
    }
    
    init(from waypoint: Waypoint) {
        self.id = waypoint.id
        self.name = waypoint.name
        self.searchText = waypoint.name
        self.coordinate = waypoint.coordinate
    }
    
    func toWaypoint() -> Waypoint? {
        guard let coordinate = coordinate else { return nil }
        return Waypoint(id: id, name: name, coordinate: coordinate)
    }
}

struct RouteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    
    let mode: RouteEditorMode
    let favoritesManager: FavoritesManager
    let routeSimulator: RouteSimulator
    var onRouteReady: ((Bool) -> Void)?
    
    // Route name
    @State private var routeName: String = ""
    
    // Start location
    @State private var startSearchText: String = ""
    @State private var startSearchResults: [MKMapItem] = []
    @State private var isSearchingStart: Bool = false
    @State private var startName: String = ""
    @State private var startCoordinate: CLLocationCoordinate2D?
    @State private var selectedStartItem: MKMapItem?
    
    // End location
    @State private var endSearchText: String = ""
    @State private var endSearchResults: [MKMapItem] = []
    @State private var isSearchingEnd: Bool = false
    @State private var endName: String = ""
    @State private var endCoordinate: CLLocationCoordinate2D?
    @State private var selectedEndItem: MKMapItem?
    
    // Waypoints
    @State private var waypoints: [EditableWaypoint] = []
    
    // Route calculation
    @State private var isCalculatingRoute: Bool = false
    @State private var routeError: String?
    @State private var calculatedRoute: Bool = false
    
    // Speed
    @State private var speedKmh: Double = 50
    
    // Map placement selection
    @State private var mapPlacementSelection: MapPlacementSelection = .none
    
    private var isEditMode: Bool {
        if case .edit = mode { return true }
        return false
    }
    
    private var editingRoute: FavoriteRoute? {
        if case .edit(let route) = mode { return route }
        return nil
    }
    
    private var canCalculate: Bool {
        startCoordinate != nil && endCoordinate != nil
    }
    
    private var canSave: Bool {
        !routeName.isEmpty && startCoordinate != nil && endCoordinate != nil
    }
    
    init(mode: RouteEditorMode, favoritesManager: FavoritesManager, routeSimulator: RouteSimulator, onRouteReady: ((Bool) -> Void)? = nil) {
        self.mode = mode
        self.favoritesManager = favoritesManager
        self.routeSimulator = routeSimulator
        self.onRouteReady = onRouteReady
    }
    
    var body: some View {
        HSplitView {
            // Left panel - Route details
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(isEditMode ? "Edit Route" : "Create Route")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding()
                
                Divider()
                
                // Scrollable content
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Route Name
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Route Name", systemImage: "tag")
                                .font(.headline)
                            
                            TextField("Enter route name...", text: $routeName)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        Divider()
                        
                        // Start Location
                        VStack(alignment: .leading, spacing: 8) {
                            Button(action: {
                                mapPlacementSelection = mapPlacementSelection == .start ? .none : .start
                            }) {
                                HStack {
                                    Label("Start Location", systemImage: "circle.fill")
                                        .font(.headline)
                                        .foregroundStyle(.green)
                                    
                                    Spacer()
                                    
                                    if mapPlacementSelection == .start {
                                        Label("Click map to place", systemImage: "hand.tap")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    } else if startCoordinate != nil {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    }
                                }
                                .padding(8)
                                .background(mapPlacementSelection == .start ? Color.green.opacity(0.15) : Color.clear)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(mapPlacementSelection == .start ? Color.green : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(.plain)
                            
                            RouteLocationSearchField(
                                searchText: $startSearchText,
                                searchResults: $startSearchResults,
                                isSearching: $isSearchingStart,
                                placeholder: "Search or click label then map...",
                                onSelect: { item in
                                    selectedStartItem = item
                                    startSearchText = item.name ?? ""
                                    startName = item.name ?? "Unknown"
                                    startCoordinate = item.placemark.coordinate
                                    calculatedRoute = false
                                    mapPlacementSelection = .none
                                }
                            )
                        }
                        
                        // Waypoints
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Waypoints", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                                    .font(.headline)
                                    .foregroundStyle(.orange)
                                
                                Spacer()
                                
                                Button(action: addWaypoint) {
                                    Label("Add Stop", systemImage: "plus.circle.fill")
                                        .foregroundStyle(.orange)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if waypoints.isEmpty {
                                Text("No waypoints added. Click \"Add Stop\" to add intermediate stops to your route.")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 8)
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(Array(waypoints.enumerated()), id: \.element.id) { index, waypoint in
                                        WaypointRow(
                                            waypoint: $waypoints[index],
                                            index: index + 1,
                                            isSelectedForPlacement: mapPlacementSelection == .waypoint(waypoint.id),
                                            onSelectForPlacement: {
                                                if mapPlacementSelection == .waypoint(waypoint.id) {
                                                    mapPlacementSelection = .none
                                                } else {
                                                    mapPlacementSelection = .waypoint(waypoint.id)
                                                }
                                            },
                                            onDelete: {
                                                if mapPlacementSelection == .waypoint(waypoint.id) {
                                                    mapPlacementSelection = .none
                                                }
                                                waypoints.remove(at: index)
                                                calculatedRoute = false
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        
                        // End Location
                        VStack(alignment: .leading, spacing: 8) {
                            Button(action: {
                                mapPlacementSelection = mapPlacementSelection == .end ? .none : .end
                            }) {
                                HStack {
                                    Label("End Location", systemImage: "mappin.circle.fill")
                                        .font(.headline)
                                        .foregroundStyle(.red)
                                    
                                    Spacer()
                                    
                                    if mapPlacementSelection == .end {
                                        Label("Click map to place", systemImage: "hand.tap")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    } else if endCoordinate != nil {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    }
                                }
                                .padding(8)
                                .background(mapPlacementSelection == .end ? Color.red.opacity(0.15) : Color.clear)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(mapPlacementSelection == .end ? Color.red : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(.plain)
                            
                            RouteLocationSearchField(
                                searchText: $endSearchText,
                                searchResults: $endSearchResults,
                                isSearching: $isSearchingEnd,
                                placeholder: "Search or click label then map...",
                                onSelect: { item in
                                    selectedEndItem = item
                                    endSearchText = item.name ?? ""
                                    endName = item.name ?? "Unknown"
                                    endCoordinate = item.placemark.coordinate
                                    calculatedRoute = false
                                    mapPlacementSelection = .none
                                }
                            )
                        }
                        
                        Divider()
                        
                        // Speed
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Simulation Speed: \(Int(speedKmh)) km/h", systemImage: "speedometer")
                                .font(.headline)
                            
                            Slider(value: $speedKmh, in: 10...200, step: 5)
                                .tint(.blue)
                            
                            HStack {
                                Text("10 km/h")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("200 km/h")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        // Error message
                        if let error = routeError {
                            Text(error)
                                .font(.callout)
                                .foregroundStyle(.red)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        }
                        
                        // Route info
                        if calculatedRoute && routeSimulator.hasRoute {
                            HStack {
                                Label(formatDistance(routeSimulator.displayDistance), systemImage: "arrow.triangle.swap")
                                Spacer()
                                Label(formatDuration(routeSimulator.displayTravelTime), systemImage: "clock")
                            }
                            .font(.callout)
                            .padding()
                            .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding()
                }
                
                Divider()
                
                // Action buttons
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                    
                    Spacer()
                    
                    if isCalculatingRoute {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Calculating...")
                            .foregroundStyle(.secondary)
                    }
                    
                    Button("Calculate Route") {
                        calculateRoute()
                    }
                    .disabled(!canCalculate || isCalculatingRoute)
                    
                    if isEditMode {
                        Button("Save Changes") {
                            saveRoute()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSave || isCalculatingRoute)
                    } else {
                        Button("Save to Favorites") {
                            saveRoute()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSave || isCalculatingRoute)
                    }
                    
                    if calculatedRoute && routeSimulator.hasRoute {
                        Button("Start Simulation") {
                            startSimulation()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                }
                .padding()
            }
            .frame(minWidth: 400, idealWidth: 450)
            
            // Right panel - Map preview
            RoutePreviewMap(
                startCoordinate: startCoordinate,
                endCoordinate: endCoordinate,
                waypoints: waypoints.compactMap { $0.coordinate },
                waypointIds: waypoints.map { $0.id },
                routePolyline: routeSimulator.displayPolyline,
                placementSelection: $mapPlacementSelection,
                onMapTap: { coordinate in
                    handleMapTap(coordinate)
                }
            )
            .frame(minWidth: 400)
        }
        .frame(minWidth: 900, minHeight: 600)
        .onAppear {
            loadInitialData()
        }
    }
    
    private func loadInitialData() {
        if case .edit(let route) = mode {
            routeName = route.name
            startSearchText = route.startName
            startName = route.startName
            startCoordinate = route.startCoordinate
            endSearchText = route.endName
            endName = route.endName
            endCoordinate = route.endCoordinate
            waypoints = route.waypoints.map { EditableWaypoint(from: $0) }
        }
        speedKmh = routeSimulator.speedMetersPerSecond * 3.6
    }
    
    private func addWaypoint() {
        waypoints.append(EditableWaypoint())
        calculatedRoute = false
    }
    
    private func handleMapTap(_ coordinate: CLLocationCoordinate2D) {
        switch mapPlacementSelection {
        case .none:
            break
        case .start:
            startCoordinate = coordinate
            startName = formatCoordinate(coordinate)
            startSearchText = startName
            calculatedRoute = false
            mapPlacementSelection = .none
        case .end:
            endCoordinate = coordinate
            endName = formatCoordinate(coordinate)
            endSearchText = endName
            calculatedRoute = false
            mapPlacementSelection = .none
        case .waypoint(let id):
            if let index = waypoints.firstIndex(where: { $0.id == id }) {
                waypoints[index].coordinate = coordinate
                waypoints[index].name = formatCoordinate(coordinate)
                waypoints[index].searchText = waypoints[index].name
                calculatedRoute = false
            }
            mapPlacementSelection = .none
        }
    }
    
    private func formatCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
    }
    
    private func calculateRoute() {
        guard let start = startCoordinate, let end = endCoordinate else { return }
        
        isCalculatingRoute = true
        routeError = nil
        
        // Set up the route simulator
        let startPlacemark = MKPlacemark(coordinate: start)
        let startItem = MKMapItem(placemark: startPlacemark)
        startItem.name = startName
        routeSimulator.startLocation = startItem
        
        let endPlacemark = MKPlacemark(coordinate: end)
        let endItem = MKMapItem(placemark: endPlacemark)
        endItem.name = endName
        routeSimulator.endLocation = endItem
        
        routeSimulator.speedMetersPerSecond = speedKmh / 3.6
        
        // Convert valid waypoints
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
                calculatedRoute = success
                if !success {
                    routeError = "Could not calculate route. Please check your locations and try again."
                }
            }
        }
    }
    
    private func saveRoute() {
        guard let start = startCoordinate, let end = endCoordinate else { return }
        
        let validWaypoints = waypoints.compactMap { editable -> Waypoint? in
            guard let coord = editable.coordinate, !editable.name.isEmpty else { return nil }
            return Waypoint(id: editable.id, name: editable.name, coordinate: coord)
        }
        
        if case .edit(let existingRoute) = mode {
            // Update existing route
            var updatedRoute = existingRoute
            updatedRoute.name = routeName
            updatedRoute.startName = startName
            updatedRoute.startLatitude = start.latitude
            updatedRoute.startLongitude = start.longitude
            updatedRoute.endName = endName
            updatedRoute.endLatitude = end.latitude
            updatedRoute.endLongitude = end.longitude
            updatedRoute.waypoints = validWaypoints
            
            favoritesManager.updateFavorite(updatedRoute)
        } else {
            // Create new route
            let newRoute = FavoriteRoute(
                name: routeName,
                startName: startName,
                startCoordinate: start,
                endName: endName,
                endCoordinate: end,
                waypoints: validWaypoints
            )
            
            favoritesManager.addFavorite(newRoute)
        }
        
        dismiss()
    }
    
    private func startSimulation() {
        routeSimulator.speedMetersPerSecond = speedKmh / 3.6
        onRouteReady?(true)
        dismiss()
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

// MARK: - Route Location Search Field

struct RouteLocationSearchField: View {
    @Binding var searchText: String
    @Binding var searchResults: [MKMapItem]
    @Binding var isSearching: Bool
    let placeholder: String
    let onSelect: (MKMapItem) -> Void
    
    @State private var searchError: String?
    @State private var hasSearched: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField(placeholder, text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        performSearch()
                    }
                
                Button(action: performSearch) {
                    Image(systemName: "magnifyingglass")
                }
                .disabled(searchText.isEmpty || isSearching)
                .help("Search (or press Enter)")
                
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            
            if let error = searchError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            
            if hasSearched && searchResults.isEmpty && !isSearching && searchError == nil {
                Text("No results found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }
            
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
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
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

// MARK: - Waypoint Row

struct WaypointRow: View {
    @Binding var waypoint: EditableWaypoint
    let index: Int
    var isSelectedForPlacement: Bool = false
    var onSelectForPlacement: (() -> Void)? = nil
    let onDelete: () -> Void
    
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching: Bool = false
    @State private var searchError: String?
    @State private var hasSearched: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Clickable header for map placement
            Button(action: {
                onSelectForPlacement?()
            }) {
                HStack(spacing: 12) {
                    // Index badge
                    ZStack {
                        Circle()
                            .fill(isSelectedForPlacement ? .orange : .orange.opacity(0.2))
                            .frame(width: 28, height: 28)
                        Text("\(index)")
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(isSelectedForPlacement ? .white : .orange)
                    }
                    
                    Text("Waypoint \(index)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                    
                    Spacer()
                    
                    if isSelectedForPlacement {
                        Label("Click map to place", systemImage: "hand.tap")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    } else if waypoint.isValid {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Remove waypoint")
                }
                .padding(8)
                .background(isSelectedForPlacement ? Color.orange.opacity(0.15) : Color.clear)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelectedForPlacement ? Color.orange : Color.clear, lineWidth: 2)
                )
            }
            .buttonStyle(.plain)
            
            // Search field
            HStack {
                TextField("Search or click header then map...", text: $waypoint.searchText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        performSearch()
                    }
                
                Button(action: performSearch) {
                    Image(systemName: "magnifyingglass")
                }
                .disabled(waypoint.searchText.isEmpty || isSearching)
                
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            
            if let error = searchError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            
            if hasSearched && searchResults.isEmpty && !isSearching && searchError == nil {
                Text("No results found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }
            
            if !searchResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(searchResults.prefix(5)), id: \.self) { item in
                        Button(action: {
                            waypoint.name = item.name ?? "Unknown"
                            waypoint.searchText = item.name ?? ""
                            waypoint.coordinate = item.placemark.coordinate
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
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
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
        .padding()
        .background(Color.orange.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
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

// MARK: - Route Preview Map

struct RoutePreviewMap: View {
    let startCoordinate: CLLocationCoordinate2D?
    let endCoordinate: CLLocationCoordinate2D?
    let waypoints: [CLLocationCoordinate2D]
    var waypointIds: [UUID] = []
    let routePolyline: MKPolyline?
    @Binding var placementSelection: MapPlacementSelection
    var onMapTap: ((CLLocationCoordinate2D) -> Void)?
    
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    private var isPlacementMode: Bool {
        placementSelection != .none
    }
    
    private var placementColor: Color {
        switch placementSelection {
        case .none: return .clear
        case .start: return .green
        case .end: return .red
        case .waypoint: return .orange
        }
    }
    
    var body: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                // Start marker
                if let start = startCoordinate {
                    Marker("Start", coordinate: start)
                        .tint(.green)
                }
                
                // Waypoint markers
                ForEach(Array(waypoints.enumerated()), id: \.offset) { index, coord in
                    Annotation("Stop \(index + 1)", coordinate: coord) {
                        ZStack {
                            Circle()
                                .fill(.orange)
                                .frame(width: 24, height: 24)
                            Text("\(index + 1)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }
                    }
                }
                
                // End marker
                if let end = endCoordinate {
                    Marker("End", coordinate: end)
                        .tint(.red)
                }
                
                // Route polyline
                if let polyline = routePolyline {
                    MapPolyline(polyline)
                        .stroke(.blue, lineWidth: 4)
                }
            }
            .mapStyle(.standard)
            .onTapGesture { screenPoint in
                if isPlacementMode, let coordinate = proxy.convert(screenPoint, from: .local) {
                    onMapTap?(coordinate)
                }
            }
        }
        .overlay(alignment: .top) {
            if isPlacementMode {
                HStack {
                    Image(systemName: "hand.tap")
                    Text("Click on the map to place the pin")
                }
                .font(.callout)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(placementColor.opacity(0.9), in: Capsule())
                .padding(.top, 12)
            }
        }
        .overlay(alignment: .topLeading) {
            if startCoordinate == nil && endCoordinate == nil && !isPlacementMode {
                VStack {
                    Image(systemName: "map")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Select start and end locations to preview route")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
            }
        }
        .overlay {
            if isPlacementMode {
                RoundedRectangle(cornerRadius: 0)
                    .stroke(placementColor, lineWidth: 4)
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: routePolyline) { _, newPolyline in
            if let polyline = newPolyline {
                let rect = polyline.boundingMapRect
                let region = MKCoordinateRegion(rect)
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
        .onChange(of: startCoordinate?.latitude) { _, _ in
            updateCameraForPoints()
        }
        .onChange(of: endCoordinate?.latitude) { _, _ in
            updateCameraForPoints()
        }
    }
    
    private func updateCameraForPoints() {
        var allCoords: [CLLocationCoordinate2D] = []
        if let start = startCoordinate { allCoords.append(start) }
        allCoords.append(contentsOf: waypoints)
        if let end = endCoordinate { allCoords.append(end) }
        
        guard !allCoords.isEmpty else { return }
        
        if allCoords.count == 1 {
            cameraPosition = .region(MKCoordinateRegion(
                center: allCoords[0],
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        } else {
            let minLat = allCoords.map { $0.latitude }.min()!
            let maxLat = allCoords.map { $0.latitude }.max()!
            let minLon = allCoords.map { $0.longitude }.min()!
            let maxLon = allCoords.map { $0.longitude }.max()!
            
            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )
            let span = MKCoordinateSpan(
                latitudeDelta: (maxLat - minLat) * 1.5 + 0.01,
                longitudeDelta: (maxLon - minLon) * 1.5 + 0.01
            )
            cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
        }
    }
}

#Preview {
    RouteEditorView(
        mode: .create,
        favoritesManager: FavoritesManager(),
        routeSimulator: RouteSimulator()
    )
}

