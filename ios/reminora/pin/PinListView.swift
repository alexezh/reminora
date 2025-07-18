import CoreData
import MapKit
import SwiftUI

struct PinListView: View {
  let items: [Place]
  let selectedPlace: Place?
  let onSelect: (Place) -> Void
  let onLongPress: ((Place) -> Void)?
  let onDelete: (IndexSet) -> Void
  let mapCenter: CLLocationCoordinate2D

  var body: some View {
    List {
      ForEach(items, id: \.objectID) { item in
        HStack(alignment: .center, spacing: 12) {
          VStack(alignment: .leading, spacing: 4) {
            if let date = item.dateAdded {
              Text(date, formatter: itemFormatter)
                .font(.headline)
            }
            if let post = item.post, !post.isEmpty {
              Text(post)
                .font(.body)
                .lineLimit(1)
            } else if let urlString = item.url {
              Text(urlString)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            }

            // Show distance from current map center
            Text(distanceText(for: item))
              .font(.caption)
              .foregroundColor(.secondary)
          }
          Spacer()
          if let imageData = item.imageData, let image = UIImage(data: imageData) {
            Image(uiImage: image)
              .resizable()
              .scaledToFill()
              .frame(width: 56, height: 56)
              .clipShape(RoundedRectangle(cornerRadius: 8))
          } else if let urlString = item.url, let url = URL(string: urlString),
            let image = loadImage(from: url)
          {
            Image(uiImage: image)
              .resizable()
              .scaledToFill()
              .frame(width: 56, height: 56)
              .clipShape(RoundedRectangle(cornerRadius: 8))
          } else {
            Image(systemName: "photo")
              .resizable()
              .scaledToFill()
              .frame(width: 56, height: 56)
              .clipShape(RoundedRectangle(cornerRadius: 8))
              .foregroundColor(.gray)
          }
        }
        .padding(.vertical, 4)
        .background(
          selectedPlace?.objectID == item.objectID ? Color.blue.opacity(0.1) : Color.clear
        )
        .id(item.objectID)  // Important for ScrollViewReader
        .onTapGesture {
          onSelect(item)
        }
        .onLongPressGesture(minimumDuration: 0.5) {
          onLongPress?(item)
        }
      }
      .onDelete(perform: onDelete)
    }
    .listStyle(PlainListStyle())
  }

  // Helper to load image from file URL
  private func loadImage(from url: URL) -> UIImage? {
    if url.isFileURL {
      return UIImage(contentsOfFile: url.path)
    } else if let data = try? Data(contentsOf: url) {
      return UIImage(data: data)
    }
    return nil
  }

  // Helper to get coordinate from Place
  private func coordinate(for item: Place) -> CLLocationCoordinate2D {
    if let locationData = item.value(forKey: "location") as? Data,
      let location = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(locationData)
        as? CLLocation
    {
      return location.coordinate
    }
    // Default to San Francisco if no location
    return CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
  }

  // Helper to calculate and format distance
  private func distanceText(for item: Place) -> String {
    let itemCoord = coordinate(for: item)
    let mapCenterLocation = CLLocation(latitude: mapCenter.latitude, longitude: mapCenter.longitude)
    let itemLocation = CLLocation(latitude: itemCoord.latitude, longitude: itemCoord.longitude)

    let distance = mapCenterLocation.distance(from: itemLocation)

    if distance < 1000 {
      return "\(Int(distance))m away"
    } else {
      return String(format: "%.1fkm away", distance / 1000)
    }
  }
}

private let itemFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.dateStyle = .short
  formatter.timeStyle = .medium
  return formatter
}()
