//
//  RListLocationView.swift
//  reminora
//
//  Created by alexezh on 7/29/25.
//


import SwiftUI
import Photos
import CoreData
import CoreLocation
import MapKit

struct RListLocationView: View {
    let location: LocationInfo
    let onTap: () -> Void
    let onDelete: (() -> Void)?
    @State private var offset: CGFloat = 0
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        ZStack {
            // Red delete background
            if onDelete != nil {
                HStack {
                    Spacer()
                    Button(action: {
                        showingDeleteConfirmation = true
                    }) {
                        VStack {
                            Image(systemName: "trash")
                                .font(.title2)
                            Text("Delete")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.red)
                .cornerRadius(12)
            }
            
            // Main content
            Button(action: {}) {
                HStack(spacing: 12) {
                    // Location icon
                    Rectangle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .cornerRadius(8)
                        .overlay(
                            Image(systemName: "location.circle.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                        )
                    
                    // Location details
                    VStack(alignment: .leading, spacing: 4) {
                        Text(location.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        Text(location.address ?? "Unknown address")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                        
                        HStack {
                            Image(systemName: "location.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text(String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospaced()
                        }
                        
                        HStack {
                            Image(systemName: "arrow.triangle.turn.up.right.diamond")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("\(String(format: "%.1f", location.distance / 1000)) km away")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .offset(x: offset)
        .gesture(
            onDelete != nil ?
            DragGesture()
                .onChanged { value in
                    // Only allow leftward swipe
                    if value.translation.width < 0 {
                        offset = max(value.translation.width, -80)
                    }
                }
                .onEnded { value in
                    if value.translation.width < -40 {
                        // Show delete button
                        withAnimation(.spring()) {
                            offset = -80
                        }
                    } else {
                        // Snap back
                        withAnimation(.spring()) {
                            offset = 0
                        }
                    }
                } : nil
        )
        .onTapGesture {
            if offset != 0 {
                // Reset swipe if tapped while swiped
                withAnimation(.spring()) {
                    offset = 0
                }
            } else {
                onTap()
            }
        }
        .alert("Delete Item", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                withAnimation(.spring()) {
                    offset = 0
                }
            }
            Button("Delete", role: .destructive) {
                onDelete?()
                withAnimation(.spring()) {
                    offset = 0
                }
            }
        } message: {
            Text("Are you sure you want to delete this item?")
        }
    }
}