//
//  LocationManager.swift
//  Hidden Gems
//
//  Created by Divine Davis on 3/17/26.
//

import CoreLocation
import SwiftUI

@Observable
class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var userLocation: CLLocation?

    /// When true, the CoreLocation manager is never touched. Used by the
    /// screenshot harness so a system permission dialog doesn't paint over
    /// every captured screen.
    private let isHarness: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.environment["HG_TEST_EMAIL"] != nil
        #else
        return false
        #endif
    }()

    override init() {
        super.init()
        guard !isHarness else {
            authorizationStatus = .authorizedWhenInUse
            return
        }
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermission() {
        guard !isHarness else { return }
        manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.last
        manager.stopUpdatingLocation()
    }
}
