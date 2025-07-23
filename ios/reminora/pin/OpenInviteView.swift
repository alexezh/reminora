import SwiftUI

/**
 * Placeholder view for Open Invite functionality
 */
struct OpenInviteView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 40) {
                Spacer()
                
                // Icon
                Image(systemName: "envelope.open.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                // Title
                Text("Open Invite")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                // Description
                Text("Open Invite Text")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                // Placeholder content
                VStack(spacing: 16) {
                    Text("This feature will allow you to:")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Create open invitations to places")
                        }
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Share location-based invites")
                        }
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Manage invitation responses")
                        }
                    }
                    .font(.body)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Coming Soon badge
                Text("Coming Soon")
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(20)
                
                Spacer()
            }
            .navigationTitle("Open Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    OpenInviteView()
}