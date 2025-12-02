//
//  RouteSimulator.swift
//  Location Simulator Boss
//
//  Created by Yugo Ogura on 2025-12-02.
//

import Foundation
import MapKit
import Observation

@MainActor
@Observable
class RouteSimulator {
    var isSimulating: Bool = false
    var isPaused: Bool = false
    var currentLocation: CLLocationCoordinate2D?
    var route: MKRoute?
    var progress: Double = 0.0 // 0.0 to 1.0
    
    var startLocation: MKMapItem?
    var endLocation: MKMapItem?
    
    // Simulation speed in meters per second (default ~50 km/h)
    var speedMetersPerSecond: Double = 14.0
    
    private var routeCoordinates: [CLLocationCoordinate2D] = []
    private var simulationTask: Task<Void, Never>?
    private var currentIndex: Int = 0
    
    var canCalculateRoute: Bool {
        startLocation != nil && endLocation != nil
    }
    
    var hasRoute: Bool {
        (route != nil || combinedPolyline != nil) && !routeCoordinates.isEmpty
    }
    
    /// True if simulation can be resumed (paused mid-way)
    var canResume: Bool {
        isPaused && currentIndex > 0 && currentIndex < routeCoordinates.count
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
            
            if let calculatedRoute = response.routes.first {
                self.route = calculatedRoute
                self.routeCoordinates = extractCoordinates(from: calculatedRoute.polyline)
                self.progress = 0.0
                self.currentIndex = 0
                if let first = routeCoordinates.first {
                    self.currentLocation = first
                }
                return true
            }
        } catch {
            print("Route calculation failed: \(error)")
        }
        
        return false
    }
    
    nonisolated private func extractCoordinates(from polyline: MKPolyline) -> [CLLocationCoordinate2D] {
        let pointCount = polyline.pointCount
        var coordinates = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: pointCount)
        polyline.getCoordinates(&coordinates, range: NSRange(location: 0, length: pointCount))
        
        // Interpolate to get smoother movement (add points between each pair)
        var interpolatedCoordinates: [CLLocationCoordinate2D] = []
        
        for i in 0..<coordinates.count - 1 {
            let start = coordinates[i]
            let end = coordinates[i + 1]
            
            let distance = calculateDistanceSync(from: start, to: end)
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
    
    nonisolated private func calculateDistanceSync(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }
    
    func startSimulation(onLocationUpdate: @escaping @Sendable (CLLocationCoordinate2D) -> Void) {
        guard hasRoute else { return }
        
        // Cancel any existing simulation
        simulationTask?.cancel()
        
        isSimulating = true
        isPaused = false
        currentIndex = 0
        progress = 0.0
        
        runSimulation(from: 0, onLocationUpdate: onLocationUpdate)
    }
    
    func pauseSimulation() {
        simulationTask?.cancel()
        simulationTask = nil
        isSimulating = false
        isPaused = true
        // currentIndex and progress are preserved
    }
    
    func resumeSimulation(onLocationUpdate: @escaping @Sendable (CLLocationCoordinate2D) -> Void) {
        guard canResume else { return }
        
        // Cancel any existing simulation
        simulationTask?.cancel()
        
        isSimulating = true
        isPaused = false
        
        runSimulation(from: currentIndex, onLocationUpdate: onLocationUpdate)
    }
    
    private func runSimulation(from startIndex: Int, onLocationUpdate: @escaping @Sendable (CLLocationCoordinate2D) -> Void) {
        // Capture values needed for simulation
        let coordinates = routeCoordinates
        let totalCount = coordinates.count
        
        simulationTask = Task { [weak self] in
            var index = startIndex
            
            while index < totalCount && !Task.isCancelled {
                let coordinate = coordinates[index]
                
                // Get current speed (can change during simulation)
                let currentSpeed = await self?.speedMetersPerSecond ?? 14.0
                
                // Update state on main actor
                await MainActor.run { [weak self] in
                    self?.currentLocation = coordinate
                    self?.progress = Double(index) / Double(max(1, totalCount - 1))
                    self?.currentIndex = index
                }
                
                // Send location update (fire and forget)
                Task.detached {
                    onLocationUpdate(coordinate)
                }
                
                // Calculate delay based on distance to next point and speed
                if index < totalCount - 1 {
                    let nextCoordinate = coordinates[index + 1]
                    let distance = self?.calculateDistanceSync(from: coordinate, to: nextCoordinate) ?? 10.0
                    let delayMs = max(50, Int((distance / currentSpeed) * 1000))
                    
                    try? await Task.sleep(for: .milliseconds(delayMs))
                }
                
                index += 1
            }
            
            await MainActor.run { [weak self] in
                self?.isSimulating = false
                self?.isPaused = false
                self?.progress = 1.0
            }
        }
    }
    
    /// Stop simulation and clear the route, but keep current location
    func stopSimulation() {
        simulationTask?.cancel()
        simulationTask = nil
        isSimulating = false
        isPaused = false
        
        // Clear route but keep currentLocation as the final position
        route = nil
        routeCoordinates = []
        combinedPolyline = nil
        combinedDistance = 0
        combinedTravelTime = 0
        startLocation = nil
        endLocation = nil
        currentIndex = 0
        progress = 0.0
        // Note: currentLocation is preserved so the marker stays
    }
    
    func reset() {
        simulationTask?.cancel()
        simulationTask = nil
        isSimulating = false
        isPaused = false
        route = nil
        routeCoordinates = []
        combinedPolyline = nil
        combinedDistance = 0
        combinedTravelTime = 0
        startLocation = nil
        endLocation = nil
        currentLocation = nil
        currentIndex = 0
        progress = 0.0
    }
    
    func loadFromFavorite(_ favorite: FavoriteRoute) async -> Bool {
        // Create MKMapItems from the favorite coordinates
        let startPlacemark = MKPlacemark(coordinate: favorite.startCoordinate)
        let endPlacemark = MKPlacemark(coordinate: favorite.endCoordinate)
        
        let startItem = MKMapItem(placemark: startPlacemark)
        startItem.name = favorite.startName
        
        let endItem = MKMapItem(placemark: endPlacemark)
        endItem.name = favorite.endName
        
        self.startLocation = startItem
        self.endLocation = endItem
        
        // If there are waypoints, calculate route through them
        if !favorite.waypoints.isEmpty {
            return await calculateRouteWithWaypoints(favorite.waypoints)
        }
        
        // Calculate the direct route
        return await calculateRoute()
    }
    
    /// Calculate a route that goes through all waypoints in order
    func calculateRouteWithWaypoints(_ waypoints: [Waypoint]) async -> Bool {
        guard let start = startLocation, let end = endLocation else { return false }
        
        // Build list of all points: start -> waypoints -> end
        var allPoints: [MKMapItem] = [start]
        
        for waypoint in waypoints {
            let placemark = MKPlacemark(coordinate: waypoint.coordinate)
            let item = MKMapItem(placemark: placemark)
            item.name = waypoint.name
            allPoints.append(item)
        }
        
        allPoints.append(end)
        
        // Calculate routes between each consecutive pair of points
        var allCoordinates: [CLLocationCoordinate2D] = []
        var totalDistance: Double = 0
        var totalTime: TimeInterval = 0
        var combinedPolylinePoints: [CLLocationCoordinate2D] = []
        
        for i in 0..<(allPoints.count - 1) {
            let segmentStart = allPoints[i]
            let segmentEnd = allPoints[i + 1]
            
            let request = MKDirections.Request()
            request.source = segmentStart
            request.destination = segmentEnd
            request.transportType = .automobile
            request.requestsAlternateRoutes = false
            
            let directions = MKDirections(request: request)
            
            do {
                let response = try await directions.calculate()
                
                if let segmentRoute = response.routes.first {
                    // Extract coordinates from this segment
                    let segmentCoords = extractCoordinates(from: segmentRoute.polyline)
                    
                    // Avoid duplicating the connecting point
                    if !allCoordinates.isEmpty && !segmentCoords.isEmpty {
                        allCoordinates.append(contentsOf: segmentCoords.dropFirst())
                    } else {
                        allCoordinates.append(contentsOf: segmentCoords)
                    }
                    
                    // Accumulate polyline points for display
                    let pointCount = segmentRoute.polyline.pointCount
                    var coords = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: pointCount)
                    segmentRoute.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
                    
                    if !combinedPolylinePoints.isEmpty && !coords.isEmpty {
                        combinedPolylinePoints.append(contentsOf: coords.dropFirst())
                    } else {
                        combinedPolylinePoints.append(contentsOf: coords)
                    }
                    
                    totalDistance += segmentRoute.distance
                    totalTime += segmentRoute.expectedTravelTime
                }
            } catch {
                print("Route calculation failed for segment \(i): \(error)")
                return false
            }
        }
        
        // Create a combined route for display
        if !combinedPolylinePoints.isEmpty {
            let combinedPolyline = MKPolyline(coordinates: combinedPolylinePoints, count: combinedPolylinePoints.count)
            
            // Create a pseudo-route with the combined polyline
            // Note: We store the polyline directly and use it for display
            self.route = nil // We'll handle display separately
            self.routeCoordinates = allCoordinates
            self.combinedPolyline = combinedPolyline
            self.combinedDistance = totalDistance
            self.combinedTravelTime = totalTime
            self.progress = 0.0
            self.currentIndex = 0
            if let first = allCoordinates.first {
                self.currentLocation = first
            }
            return true
        }
        
        return false
    }
    
    // For waypoint routes, we store the combined polyline separately
    var combinedPolyline: MKPolyline?
    var combinedDistance: Double = 0
    var combinedTravelTime: TimeInterval = 0
    
    /// Returns the polyline to display on map (either from route or combined waypoint route)
    var displayPolyline: MKPolyline? {
        combinedPolyline ?? route?.polyline
    }
    
    /// Returns the distance to display (either from route or combined)
    var displayDistance: Double {
        if combinedPolyline != nil {
            return combinedDistance
        }
        return route?.distance ?? 0
    }
    
    /// Returns the travel time to display (either from route or combined)
    var displayTravelTime: TimeInterval {
        if combinedPolyline != nil {
            return combinedTravelTime
        }
        return route?.expectedTravelTime ?? 0
    }
}
