//
//  SaveSearchDialog.swift
//  reminora
//
//  Created by alexezh on 7/28/25.
//


import SwiftUI
import MapKit
import CoreData
import UIKit
import Foundation

struct SaveSearchDialog: View {
    @Binding var city: String
    @Binding var searchString: String
    let onSave: (String, String) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Save Search Results")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("City")
                    .font(.headline)
                TextField("Enter city name", text: $city)
                    .textFieldStyle(.roundedBorder)
                
                Text("Search String")
                    .font(.headline)
                TextField("Enter search description", text: $searchString)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)
            
            Spacer()
            
            HStack(spacing: 20) {
                Button("Cancel") {
                    onCancel()
                }
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .cornerRadius(10)
                
                Button("Save") {
                    onSave(city, searchString)
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
                .disabled(city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                         searchString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .navigationBarHidden(true)
    }
}