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
    var onLocationSelected: (CLLocationCoordinate2D) -> Void
    
    @State private var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503), // Tokyo
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    ))
    
    @State private var searchText: String = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching: Bool = false
    @State private var showResults: Bool = false
    
    var body: some View {
        ZStack(alignment: .top) {
            // Map
            MapReader { proxy in
                Map(position: $cameraPosition) {
                    if let coordinate = selectedCoordinate {
                        Marker("Selected Location", coordinate: coordinate)
                            .tint(.red)
                    }
                }
                .mapStyle(.standard)
                .onTapGesture { screenPoint in
                    if let coordinate = proxy.convert(screenPoint, from: .local) {
                        selectedCoordinate = coordinate
                        onLocationSelected(coordinate)
                        showResults = false
                    }
                }
            }
            
            // Search overlay
            VStack(spacing: 0) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
                    TextField("Search location...", text: $searchText)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            performSearch()
                        }
                    
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
            .frame(maxWidth: 400)
        }
        .overlay(alignment: .bottomTrailing) {
            CoordinateOverlay(coordinate: selectedCoordinate)
                .padding()
        }
        .onChange(of: searchText) { _, newValue in
            if newValue.isEmpty {
                searchResults = []
                showResults = false
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
        search.start { response, error in
            isSearching = false
            
            if let response = response {
                searchResults = response.mapItems
            } else {
                searchResults = []
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
        .background {
            Rectangle()
                .fill(.clear)
        }
        .onHover { hovering in
            // Visual feedback handled by system
        }
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
    LocationMapView(selectedCoordinate: .constant(nil)) { coordinate in
        print("Selected: \(coordinate)")
    }
}
