//
//  RouteSimulator.swift
//  Location Simulator Boss
//
//  Created by Yugo Ogura on 2025-12-02.
//

import Foundation
import MapKit
import Observation

@Observable
class RouteSimulator {
    var isSimulating: Bool = false
    var currentLocation: CLLocationCoordinate2D?
    var route: MKRoute?
    var progress: Double = 0.0 // 0.0 to 1.0
    
    var startLocation: MKMapItem?
    var endLocation: MKMapItem?
    
    private var routeCoordinates: [CLLocationCoordinate2D] = []
    private var simulationTask: Task<Void, Never>?
    private var currentIndex: Int = 0
    
    // Simulation speed in meters per second (default ~50 km/h)
    var speedMetersPerSecond: Double = 14.0
    
    var canCalculateRoute: Bool {
        startLocation != nil && endLocation != nil
    }
    
    var hasRoute: Bool {
        route != nil && !routeCoordinates.isEmpty
    }
    
    func calculateRoute() async -> Bool {
        guard let start = startLocation, let end = endLocation else { return false }
        
        let request = MKDirections.Request()
        request.source = start
        request.destination = end
        request.transportType = .automobile
        request.requestsAlternateRoutes = false
        
        let directions = MKDirections(request: request)
        
        do {
            let response = try await directions.calculate()
            
            if let route = response.routes.first {
                await MainActor.run {
                    self.route = route
                    self.routeCoordinates = extractCoordinates(from: route.polyline)
                    self.progress = 0.0
                    self.currentIndex = 0
                    if let first = routeCoordinates.first {
                        self.currentLocation = first
                    }
                }
                return true
            }
        } catch {
            print("Route calculation failed: \(error)")
        }
        
        return false
    }
    
    private func extractCoordinates(from polyline: MKPolyline) -> [CLLocationCoordinate2D] {
        let pointCount = polyline.pointCount
        var coordinates = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: pointCount)
        polyline.getCoordinates(&coordinates, range: NSRange(location: 0, length: pointCount))
        
        // Interpolate to get smoother movement (add points between each pair)
        var interpolatedCoordinates: [CLLocationCoordinate2D] = []
        
        for i in 0..<coordinates.count - 1 {
            let start = coordinates[i]
            let end = coordinates[i + 1]
            
            let distance = calculateDistance(from: start, to: end)
            // Add intermediate points every ~10 meters
            let steps = max(1, Int(distance / 10))
            
            for step in 0..<steps {
                let fraction = Double(step) / Double(steps)
                let lat = start.latitude + (end.latitude - start.latitude) * fraction
                let lon = start.longitude + (end.longitude - start.longitude) * fraction
                interpolatedCoordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
            }
        }
        
        // Add the final point
        if let last = coordinates.last {
            interpolatedCoordinates.append(last)
        }
        
        return interpolatedCoordinates
    }
    
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }
    
    func startSimulation(onLocationUpdate: @escaping (CLLocationCoordinate2D) -> Void) {
        guard hasRoute else { return }
        
        isSimulating = true
        currentIndex = 0
        
        simulationTask = Task {
            while currentIndex < routeCoordinates.count && !Task.isCancelled {
                let coordinate = routeCoordinates[currentIndex]
                
                await MainActor.run {
                    currentLocation = coordinate
                    progress = Double(currentIndex) / Double(routeCoordinates.count - 1)
                    onLocationUpdate(coordinate)
                }
                
                // Calculate delay based on distance to next point and speed
                if currentIndex < routeCoordinates.count - 1 {
                    let nextCoordinate = routeCoordinates[currentIndex + 1]
                    let distance = calculateDistance(from: coordinate, to: nextCoordinate)
                    let delay = distance / speedMetersPerSecond
                    
                    try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
                }
                
                currentIndex += 1
            }
            
            await MainActor.run {
                isSimulating = false
                progress = 1.0
            }
        }
    }
    
    func pauseSimulation() {
        simulationTask?.cancel()
        simulationTask = nil
        isSimulating = false
    }
    
    func resumeSimulation(onLocationUpdate: @escaping (CLLocationCoordinate2D) -> Void) {
        guard hasRoute && currentIndex < routeCoordinates.count else { return }
        
        isSimulating = true
        
        simulationTask = Task {
            while currentIndex < routeCoordinates.count && !Task.isCancelled {
                let coordinate = routeCoordinates[currentIndex]
                
                await MainActor.run {
                    currentLocation = coordinate
                    progress = Double(currentIndex) / Double(routeCoordinates.count - 1)
                    onLocationUpdate(coordinate)
                }
                
                if currentIndex < routeCoordinates.count - 1 {
                    let nextCoordinate = routeCoordinates[currentIndex + 1]
                    let distance = calculateDistance(from: coordinate, to: nextCoordinate)
                    let delay = distance / speedMetersPerSecond
                    
                    try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
                }
                
                currentIndex += 1
            }
            
            await MainActor.run {
                isSimulating = false
                progress = 1.0
            }
        }
    }
    
    func stopSimulation() {
        simulationTask?.cancel()
        simulationTask = nil
        isSimulating = false
        currentIndex = 0
        progress = 0.0
        if let first = routeCoordinates.first {
            currentLocation = first
        }
    }
    
    func reset() {
        stopSimulation()
        route = nil
        routeCoordinates = []
        startLocation = nil
        endLocation = nil
        currentLocation = nil
    }
}

