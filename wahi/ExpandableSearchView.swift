import CoreData
import MapKit
import SwiftUI

// Expandable bottom sheet view
struct ExpandableSearchView<Content: View>: View {
  @Binding var isOpen: Bool
  @Binding var isExpanded: Bool
  let minHeight: CGFloat
  let maxHeight: CGFloat
  let content: Content

  @GestureState private var translation: CGFloat = 0

  init(
    isOpen: Binding<Bool>,
    isExpanded: Binding<Bool>,
    minHeight: CGFloat,
    maxHeight: CGFloat,
    @ViewBuilder content: () -> Content
  ) {
    self._isOpen = isOpen
    self._isExpanded = isExpanded
    self.minHeight = minHeight
    self.maxHeight = maxHeight
    self.content = content()
  }

  private var currentHeight: CGFloat {
    isExpanded ? maxHeight : minHeight
  }

  private var offset: CGFloat {
    isOpen ? 0 : currentHeight - minHeight
  }

  var body: some View {
    VStack {
      Spacer()
      VStack(spacing: 0) {
        content
      }
      .frame(maxWidth: .infinity)
      .frame(height: currentHeight)
      .background(.ultraThinMaterial)
      .cornerRadius(16)
      .offset(y: offset + translation)
      .animation(.interactiveSpring(), value: isOpen)
      .animation(.interactiveSpring(), value: isExpanded)
      .gesture(
        DragGesture().updating($translation) { value, state, _ in
          state = max(0, value.translation.height)
        }
        .onEnded { value in
          if value.translation.height > 100 {
            isOpen = false
          } else if value.translation.height < -100 {
            isExpanded = true
          }
        }
      )
    }
    .ignoresSafeArea(edges: .bottom)
  }
}
