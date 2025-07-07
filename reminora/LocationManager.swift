import CoreData
import CoreLocation
import MapKit
import SwiftUI

// LocationManager to get current user location
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  @Published var lastLocation: CLLocation?
  //private var cancellables = Set<AnyCancellable>()

  override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyBest
    manager.distanceFilter = 5  // meters before update is triggered
    manager.requestWhenInUseAuthorization()
    manager.startUpdatingLocation()
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let newLocation = locations.last else { return }

    // Ignore invalid or inaccurate readings
    guard newLocation.horizontalAccuracy >= 0 && newLocation.horizontalAccuracy <= 50 else {
      return
    }

    // Avoid publishing duplicates or very small movements
    if let last = lastLocation {
      let distance = newLocation.distance(from: last)
      guard distance >= 5 else {
        return
      }
    }

    // Publish the new valid location
    lastLocation = newLocation
    //DispatchQueue.main.async {
    self.lastLocation = newLocation
    //}
  }
}
