//
//  MapLocationCard.swift
//  reminora
//
//  Created by alexezh on 7/26/25.
//


import SwiftUI
import MapKit
import CoreData
import UIKit
import Foundation

struct MapLocationCard: View {
    let place: LocationInfo
    let isSelected: Bool
    let onShareTap: () -> Void
    let onPinTap: () -> Void
    let onLocationTap: () -> Void
    let onNavigateTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main content - Tappable to show on map
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.headline)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                        .fontWeight(.regular)
                    
                    Text(place.address ?? "Unknown address")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack {
                        Image(systemName: "location")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("\(String(format: "%.1f", place.distance / 1000)) km")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onLocationTap()
            }
            
            // Action buttons
            HStack(spacing: 0) {
                Button(action: onNavigateTap) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                }
                
                Button(action: onPinTap) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                        Text("Pin")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                }
                
            }
        }
        .padding(16)
        .background(
            isSelected ? Color.blue.opacity(0.15) : 
            Color(UIColor.systemBackground)
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isSelected ? Color.blue.opacity(0.5) : 
                    Color.clear, 
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .shadow(color: .black.opacity(isSelected ? 0.15 : 0.1), radius: isSelected ? 4 : 2, x: 0, y: 1)
    }
}
