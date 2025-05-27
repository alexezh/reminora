import CoreData
import MapKit
import SwiftUI

struct PlaceListView: View {
  let items: [Place]
  let selectedPlace: Place?
  let onSelect: (Place) -> Void
  let onDelete: (IndexSet) -> Void

  var body: some View {
    List {
      ForEach(items, id: \.objectID) { item in
        HStack(alignment: .center, spacing: 12) {
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
          }
        }
        .padding(.vertical, 4)
        .background(selectedPlace?.objectID == item.objectID ? Color.blue.opacity(0.1) : Color.clear)
        .id(item.objectID) // Important for ScrollViewReader
        .onTapGesture {
          onSelect(item)
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
}

private let itemFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.dateStyle = .short
  formatter.timeStyle = .medium
  return formatter
}()
