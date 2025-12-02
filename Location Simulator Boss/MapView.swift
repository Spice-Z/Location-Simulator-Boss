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
    
    var body: some View {
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
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            CoordinateOverlay(coordinate: selectedCoordinate)
                .padding()
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

#Preview {
    LocationMapView(selectedCoordinate: .constant(nil)) { coordinate in
        print("Selected: \(coordinate)")
    }
}

