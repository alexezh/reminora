//
//  PinCardView.swift
//  reminora
//
//  Created by alexezh on 7/22/25.
//


import CoreData
import Foundation
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
  
  @State private var selectedCard: CardType = .text
  
  private var availableCards: [CardType] {
    var cards: [CardType] = [.text]
    if place.imageData != nil {
      cards.append(.image)
    }
    cards.append(.map)
    return cards
  }
  
  enum CardType {
    case text, image, map
  }
  
  var body: some View {
    GeometryReader { geometry in
      let screenWidth = geometry.size.width
      let cardWidth = screenWidth * (2.0/3.0)
      let visibleEdgeWidth = screenWidth * (1.0/6.0)
      
      ZStack(alignment: .leading) {
        // Text Card (Left position)
        textCard
          .frame(width: cardWidth, height: cardHeight)
          .background(Color(.systemGray6))
          .cornerRadius(16)
          .overlay(
            RoundedRectangle(cornerRadius: 16)
              .stroke(Color(.systemGray4), lineWidth: 0.5)
          )
          .shadow(color: .black.opacity(selectedCard == .text ? 0.2 : 0.1), radius: selectedCard == .text ? 8 : 4, x: 0, y: selectedCard == .text ? 4 : 2)
          .scaleEffect(selectedCard == .text ? 1.0 : 0.9)
          .opacity(selectedCard == .text ? 1.0 : 0.7)
          .zIndex(selectedCard == .text ? 3 : 1)
          .offset(x: 0)
          .animation(.spring(response: 0.6, dampingFraction: 0.8), value: selectedCard)
          .onTapGesture {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
              selectedCard = .text
            }
          }
        
        // Image Card (Center position) - Only show if image exists
        if place.imageData != nil {
          imageCard
            .frame(width: cardWidth, height: cardHeight)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .overlay(
              RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(selectedCard == .image ? 0.2 : 0.1), radius: selectedCard == .image ? 8 : 4, x: 0, y: selectedCard == .image ? 4 : 2)
            .scaleEffect(selectedCard == .image ? 1.0 : 0.9)
            .opacity(selectedCard == .image ? 1.0 : 0.7)
            .zIndex(selectedCard == .image ? 3 : 2)
            .offset(x: place.imageData != nil ? visibleEdgeWidth : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: selectedCard)
            .onTapGesture {
              withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                selectedCard = .image
              }
            }
        }
        
        // Map Card (Position based on image availability)
        mapCard
          .frame(width: cardWidth, height: cardHeight)
          .background(Color(.systemBackground))
          .cornerRadius(16)
          .overlay(
            RoundedRectangle(cornerRadius: 16)
              .stroke(Color(.systemGray4), lineWidth: 0.5)
          )
          .shadow(color: .black.opacity(selectedCard == .map ? 0.2 : 0.1), radius: selectedCard == .map ? 8 : 4, x: 0, y: selectedCard == .map ? 4 : 2)
          .scaleEffect(selectedCard == .map ? 1.0 : 0.9)
          .opacity(selectedCard == .map ? 1.0 : 0.7)
          .zIndex(selectedCard == .map ? 3 : 1)
          .offset(x: place.imageData != nil ? visibleEdgeWidth * 2 : visibleEdgeWidth)
          .animation(.spring(response: 0.6, dampingFraction: 0.8), value: selectedCard)
          .onTapGesture {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
              selectedCard = .map
            }
          }
      }
      .frame(width: screenWidth, height: cardHeight, alignment: .leading)
    }
    .frame(height: cardHeight)
    .clipped()
  }
  
  private var textCard: some View {
    VStack(alignment: .leading, spacing: selectedCard == .text ? 12 : 8) {
      if selectedCard == .text {
        // Full content when text card is selected
        // Title (tappable)
        Button(action: onTitleTap) {
          Text(place.post ?? "Untitled Pin")
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(.primary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PlainButtonStyle())
        
        // Location
        if let locationName = getLocationName() {
          HStack(spacing: 6) {
            Image(systemName: "location.fill")
              .font(.subheadline)
              .foregroundColor(.blue)
            Text(locationName)
              .font(.body)
              .foregroundColor(.secondary)
              .lineLimit(1)
          }
        }
        
        // Phone number
        if let phoneNumber = getPhoneNumber() {
          HStack(spacing: 6) {
            Image(systemName: "phone.fill")
              .font(.subheadline)
              .foregroundColor(.blue)
            Text(phoneNumber)
              .font(.body)
              .foregroundColor(.secondary)
              .lineLimit(1)
          }
          .onTapGesture {
            if let url = URL(string: "tel:\(phoneNumber)") {
              UIApplication.shared.open(url)
            }
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
          HStack(spacing: 10) {
            Image(systemName: "person.circle.fill")
              .font(.title3)
              .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 3) {
              if let originalDisplayName = place.value(forKey: "originalDisplayName") as? String {
                Text(originalDisplayName)
                  .font(.subheadline)
                  .fontWeight(.semibold)
                  .foregroundColor(.primary)
              } else {
                Text("You")
                  .font(.subheadline)
                  .fontWeight(.semibold)
                  .foregroundColor(.primary)
              }
              
              if let dateAdded = place.dateAdded {
                Text(formatDate(dateAdded))
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
            }
            Spacer()
          }
        }
        .buttonStyle(PlainButtonStyle())
        
        Spacer()
        
        // Card indicators
        HStack(spacing: 8) {
          ForEach(availableCards, id: \.self) { cardType in
            Circle()
              .fill(selectedCard == cardType ? Color.blue : Color.gray.opacity(0.3))
              .frame(width: 8, height: 8)
              .onTapGesture {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                  selectedCard = cardType
                }
              }
          }
          Spacer()
        }
      } else {
        // Compressed content when text card is partially visible
        VStack(spacing: 4) {
          Image(systemName: "text.alignleft")
            .font(.title2)
            .foregroundColor(.blue)
          Text("Text")
            .font(.caption)
            .foregroundColor(.blue)
        }
        Spacer()
      }
    }
    .padding(selectedCard == .text ? 20 : 12)
    .contentShape(Rectangle())
    .onTapGesture {
      withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
        selectedCard = .text
      }
    }
  }
  
  private var imageCard: some View {
    ZStack {
      if selectedCard == .image {
        // Full image content when image card is selected
        if let imageData = place.imageData,
           let uiImage = UIImage(data: imageData) {
          Image(uiImage: uiImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        } else {
          // Placeholder image
          Rectangle()
            .fill(LinearGradient(colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
              VStack(spacing: 8) {
                Image(systemName: "photo")
                  .font(.largeTitle)
                  .foregroundColor(.blue)
                Text("No Image")
                  .font(.caption)
                  .foregroundColor(.blue)
              }
            )
        }
        
        // Overlay with back button when selected
        VStack {
          HStack {
            Button(action: {
              withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                selectedCard = .text
              }
            }) {
              Image(systemName: "chevron.left")
                .font(.title2)
                .foregroundColor(.white)
                .padding(8)
                .background(Color.black.opacity(0.6), in: Circle())
            }
            Spacer()
          }
          Spacer()
        }
        .padding(16)
      } else {
        // Compressed content when image card is partially visible
        if let imageData = place.imageData,
           let uiImage = UIImage(data: imageData) {
          Image(uiImage: uiImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .overlay(
              VStack {
                Spacer()
                VStack(spacing: 2) {
                  Image(systemName: "photo")
                    .font(.caption)
                    .foregroundColor(.white)
                  Text("Photo")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
                }
                .padding(4)
                .background(Color.black.opacity(0.6))
                .cornerRadius(6)
              }
              .padding(8)
            )
        } else {
          Rectangle()
            .fill(LinearGradient(colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
              VStack(spacing: 4) {
                Image(systemName: "photo")
                  .font(.title2)
                  .foregroundColor(.blue)
                Text("Photo")
                  .font(.caption)
                  .foregroundColor(.blue)
              }
            )
        }
      }
    }
  }
  
  private var mapCard: some View {
    ZStack {
      if selectedCard == .map {
        // Full map content when map card is selected
        if let coordinate = getCoordinate() {
          Map(coordinateRegion: .constant(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
          )), annotationItems: [PinCardMapAnnotation(coordinate: coordinate)]) { annotation in
            MapAnnotation(coordinate: annotation.coordinate) {
              ZStack {
                Circle()
                  .fill(Color.red)
                  .frame(width: 20, height: 20)
                Circle()
                  .stroke(Color.white, lineWidth: 3)
                  .frame(width: 20, height: 20)
              }
            }
          }
          .allowsHitTesting(true)
        } else {
          // No location placeholder
          Rectangle()
            .fill(LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
              VStack(spacing: 8) {
                Image(systemName: "location.slash")
                  .font(.largeTitle)
                  .foregroundColor(.gray)
                Text("No Location")
                  .font(.caption)
                  .foregroundColor(.gray)
              }
            )
        }
        
        // Overlay with back button when selected
        VStack {
          HStack {
            Button(action: {
              withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                selectedCard = .text
              }
            }) {
              Image(systemName: "chevron.left")
                .font(.title2)
                .foregroundColor(.white)
                .padding(8)
                .background(Color.black.opacity(0.6), in: Circle())
            }
            Spacer()
            
            if getCoordinate() != nil {
              Button(action: onMapTap) {
                Image(systemName: "arrow.up.right")
                  .font(.title2)
                  .foregroundColor(.white)
                  .padding(8)
                  .background(Color.black.opacity(0.6), in: Circle())
              }
            }
          }
          Spacer()
        }
        .padding(16)
      } else {
        // Compressed content when map card is partially visible
        if let coordinate = getCoordinate() {
          Map(coordinateRegion: .constant(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
          )), annotationItems: [PinCardMapAnnotation(coordinate: coordinate)]) { annotation in
            MapAnnotation(coordinate: annotation.coordinate) {
              ZStack {
                Circle()
                  .fill(Color.red)
                  .frame(width: 12, height: 12)
                Circle()
                  .stroke(Color.white, lineWidth: 2)
                  .frame(width: 12, height: 12)
              }
            }
          }
          .allowsHitTesting(false)
          .overlay(
            VStack {
              Spacer()
              VStack(spacing: 2) {
                Image(systemName: "map")
                  .font(.caption)
                  .foregroundColor(.white)
                Text("Map")
                  .font(.system(size: 10))
                  .foregroundColor(.white)
              }
              .padding(4)
              .background(Color.black.opacity(0.6))
              .cornerRadius(6)
            }
            .padding(8)
          )
        } else {
          Rectangle()
            .fill(LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
              VStack(spacing: 4) {
                Image(systemName: "map")
                  .font(.title2)
                  .foregroundColor(.gray)
                Text("Map")
                  .font(.caption)
                  .foregroundColor(.gray)
              }
            )
        }
      }
    }
  }
  
  private func getLocationName() -> String? {
    // First, try to get the first location from the locations JSON
    if let locationsJSON = place.locations,
       !locationsJSON.isEmpty,
       let data = locationsJSON.data(using: .utf8) {
      do {
        let locations = try JSONDecoder().decode([LocationInfo].self, from: data)
        if let firstLocation = locations.first {
          return firstLocation.name
        }
      } catch {
        // If JSON parsing fails, continue to fallback options
        print("Failed to decode locations JSON: \(error)")
      }
    }
    
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
  
  private func getPhoneNumber() -> String? {
    // Try to get phone number from the locations JSON
    if let locationsJSON = place.locations,
       !locationsJSON.isEmpty,
       let data = locationsJSON.data(using: .utf8) {
      do {
        let locations = try JSONDecoder().decode([LocationInfo].self, from: data)
        if let firstLocation = locations.first,
           let phoneNumber = firstLocation.phoneNumber,
           !phoneNumber.isEmpty {
          return phoneNumber
        }
      } catch {
        print("Failed to decode locations JSON: \(error)")
      }
    }
    
    return nil
  }
  
  private func getCoordinate() -> CLLocationCoordinate2D? {
    if let locationData = place.value(forKey: "coordinates") as? Data,
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

struct PinCardMapAnnotation: Identifiable {
  let id = UUID()
  let coordinate: CLLocationCoordinate2D
}
