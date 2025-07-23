//
//  PinCardView.swift
//  reminora
//
//  Created by alexezh on 7/22/25.
//


import CoreData
import MapKit
import SwiftUI

// MARK: - PinCardView Component
struct PinCardView: View {
  let place: Place
  let cardHeight: CGFloat
  let onPhotoTap: () -> Void
  let onTitleTap: () -> Void
  let onMapTap: () -> Void
  let onUserTap: (String, String) -> Void
  
  @State private var showingMap = false
  
  var body: some View {
    HStack(spacing: 0) {
      // Left side - Content
      VStack(alignment: .leading, spacing: 8) {
        // Title (tappable)
        Button(action: onTitleTap) {
          Text(place.post ?? "Untitled Pin")
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.primary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PlainButtonStyle())
        
        // Location
        if let locationName = getLocationName() {
          HStack(spacing: 4) {
            Image(systemName: "location.fill")
              .font(.caption)
              .foregroundColor(.blue)
            Text(locationName)
              .font(.subheadline)
              .foregroundColor(.secondary)
              .lineLimit(1)
          }
        }
        
        // User info (tappable)
        Button(action: {
          let userId = place.value(forKey: "originalUserId") as? String ?? ""
          let userName = place.value(forKey: "originalDisplayName") as? String ?? "You"
          if !userId.isEmpty {
            onUserTap(userId, userName)
          }
        }) {
          HStack(spacing: 8) {
            Image(systemName: "person.circle.fill")
              .font(.caption)
              .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
              if let originalDisplayName = place.value(forKey: "originalDisplayName") as? String {
                Text(originalDisplayName)
                  .font(.caption)
                  .fontWeight(.medium)
                  .foregroundColor(.primary)
              } else {
                Text("You")
                  .font(.caption)
                  .fontWeight(.medium)
                  .foregroundColor(.primary)
              }
              
              if let dateAdded = place.dateAdded {
                Text(formatDate(dateAdded))
                  .font(.caption2)
                  .foregroundColor(.secondary)
              }
            }
          }
        }
        .buttonStyle(PlainButtonStyle())
        
        Spacer()
      }
      .padding(.leading, 16)
      .padding(.vertical, 12)
      .frame(maxWidth: .infinity, alignment: .leading)
      
      // Right side - Image/Map with toggle
      ZStack {
        if showingMap {
          // Map view (tappable)
          Button(action: onMapTap) {
            if let coordinate = getCoordinate() {
              Map(coordinateRegion: .constant(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
              )), annotationItems: [MapAnnotationItem(coordinate: coordinate)]) { annotation in
                MapAnnotation(coordinate: annotation.coordinate) {
                  ZStack {
                    Circle()
                      .fill(Color.red)
                      .frame(width: 16, height: 16)
                    Circle()
                      .stroke(Color.white, lineWidth: 2)
                      .frame(width: 16, height: 16)
                  }
                }
              }
              .allowsHitTesting(false)
            } else {
              // No location placeholder
              Rectangle()
                .fill(Color.gray.opacity(0.2))
                .overlay(
                  VStack(spacing: 4) {
                    Image(systemName: "location.slash")
                      .font(.title2)
                      .foregroundColor(.gray)
                    Text("No Location")
                      .font(.caption2)
                      .foregroundColor(.gray)
                  }
                )
            }
          }
          .buttonStyle(PlainButtonStyle())
        } else {
          // Image view - scale to fit properly (tappable)
          Button(action: onPhotoTap) {
            if let imageData = place.imageData,
               let uiImage = UIImage(data: imageData) {
              Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: cardHeight * 1.2, height: cardHeight)
                .clipped()
            } else {
              // Placeholder image
              Rectangle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: cardHeight * 1.2, height: cardHeight)
                .overlay(
                  Image(systemName: "photo")
                    .font(.title2)
                    .foregroundColor(.blue)
                )
            }
          }
          .buttonStyle(PlainButtonStyle())
        }
        
        // Toggle button - positioned relative to card area
        VStack {
          HStack {
            Spacer()
            Button(action: {
              withAnimation(.easeInOut(duration: 0.3)) {
                showingMap.toggle()
              }
            }) {
              Image(systemName: showingMap ? "photo" : "map")
                .font(.title3)
                .foregroundColor(.white)
                .padding(8)
                .background(Color.black.opacity(0.6), in: Circle())
            }
            .padding(.top, 8)
            .padding(.trailing, 8)
          }
          Spacer()
        }
      }
      .frame(width: cardHeight * 1.2, height: cardHeight)
      .background(Color.gray.opacity(0.1))
      .cornerRadius(12)
    }
    .frame(height: cardHeight)
    .background(Color(.systemBackground))
    .cornerRadius(16)
    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
  }
  
  private func getLocationName() -> String? {
    // Try to get location name from URL field or reverse geocoding
    if let url = place.url, !url.isEmpty {
      return url
    }
    
    // Fallback to coordinates
    if let coordinate = getCoordinate() {
      return String(format: "%.3f, %.3f", coordinate.latitude, coordinate.longitude)
    }
    
    return nil
  }
  
  private func getCoordinate() -> CLLocationCoordinate2D? {
    if let locationData = place.value(forKey: "location") as? Data,
       let location = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(locationData) as? CLLocation {
      return location.coordinate
    }
    return nil
  }
  
  private func formatDate(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
  }
}
