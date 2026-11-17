//
//  LocationService.swift
//  BEACON
//
//  Location Service for Apple Maps Integration
//

import Foundation
import CoreLocation
import MapKit
import Combine

class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    // MARK: - Published Properties
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String?

    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    private var locationHistory: [(coordinate: CLLocationCoordinate2D, timestamp: Date)] = []

    override private init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10  // Update every 10 meters

        print("[Location] Location Service initialized")
    }

    // MARK: - Permission Management
    func requestPermission() {
        print("[Location] Requesting location permission...")
        locationManager.requestWhenInUseAuthorization()
    }

    // MARK: - Location Fetching
    func getCurrentLocation() {
        switch authorizationStatus {
        case .notDetermined:
            print("[Location] Permission not determined - requesting...")
            requestPermission()

        case .restricted, .denied:
            print("[Location] ❌ Permission denied or restricted")
            locationError = "Location permission denied. Please enable in Settings."

        case .authorizedAlways, .authorizedWhenInUse:
            print("[Location] ✅ Permission granted - requesting location")
            locationManager.requestLocation()

        @unknown default:
            print("[Location] Unknown authorization status")
        }
    }

    func startContinuousUpdates() {
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            requestPermission()
            return
        }

        locationManager.startUpdatingLocation()
        print("[Location] Started continuous location updates")
    }

    func stopContinuousUpdates() {
        locationManager.stopUpdatingLocation()
        print("[Location] Stopped continuous location updates")
    }

    // MARK: - Apple Maps Integration
    func openInAppleMaps() {
        guard let location = currentLocation else {
            print("[Location] ❌ No location available to show on map")
            locationError = "Location not available. Please wait for GPS fix."
            return
        }

        print("========================================")
        print("[Location] Opening Apple Maps")
        print("[Location] Coordinates: \(location.latitude), \(location.longitude)")
        print("========================================")

        let coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)

        mapItem.name = "My BEACON Device"

        // Launch options for better map presentation
        let launchOptions: [String: Any] = [
            MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: coordinate),
            MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)),
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ]

        mapItem.openInMaps(launchOptions: launchOptions)
    }

    func openInAppleMapsWithDirections() {
        guard let location = currentLocation else {
            print("[Location] ❌ No location for directions")
            return
        }

        let coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = "My BEACON Device"

        let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]
        mapItem.openInMaps(launchOptions: launchOptions)
    }

    // MARK: - Location History
    func addToHistory(_ coordinate: CLLocationCoordinate2D) {
        let entry = (coordinate: coordinate, timestamp: Date())
        locationHistory.append(entry)

        // Keep only last 100 locations
        if locationHistory.count > 100 {
            locationHistory.removeFirst()
        }

        print("[Location] Added location to history - Total: \(locationHistory.count)")
    }

    func getLocationHistory() -> [(coordinate: CLLocationCoordinate2D, timestamp: Date)] {
        return locationHistory
    }

    func clearHistory() {
        locationHistory.removeAll()
        print("[Location] Location history cleared")
    }

    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        print("[Location] ✅ Location updated:")
        print("[Location]   Latitude: \(location.coordinate.latitude)")
        print("[Location]   Longitude: \(location.coordinate.longitude)")
        print("[Location]   Accuracy: \(location.horizontalAccuracy)m")

        DispatchQueue.main.async {
            self.currentLocation = location.coordinate
            self.locationError = nil
        }

        // Add to history
        addToHistory(location.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[Location] ❌ Error: \(error.localizedDescription)")

        DispatchQueue.main.async {
            self.locationError = error.localizedDescription
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus

            print("[Location] Authorization status changed: \(self.authorizationStatus.rawValue)")

            if self.authorizationStatus == .authorizedAlways || self.authorizationStatus == .authorizedWhenInUse {
                print("[Location] ✅ Location permission granted")
            } else if self.authorizationStatus == .denied || self.authorizationStatus == .restricted {
                print("[Location] ❌ Location permission denied/restricted")
                self.locationError = "Location permission required"
            }
        }
    }

    // MARK: - Utility
    func getLocationString() -> String {
        guard let location = currentLocation else {
            return "Location unavailable"
        }

        return String(format: "%.6f, %.6f", location.latitude, location.longitude)
    }

    func getDistanceString(from coordinate: CLLocationCoordinate2D) -> String {
        guard let current = currentLocation else {
            return "Unknown"
        }

        let location1 = CLLocation(latitude: current.latitude, longitude: current.longitude)
        let location2 = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let distance = location1.distance(from: location2)

        if distance < 1000 {
            return String(format: "%.0f m", distance)
        } else {
            return String(format: "%.1f km", distance / 1000)
        }
    }
}
