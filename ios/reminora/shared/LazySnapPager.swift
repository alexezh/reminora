//
//  LazySnapPager.swift
//  reminora
//
//  Created by alexezh on 8/12/25.
//

import SwiftUI

struct LazySnapPager<Content: View>: View {
    let itemCount: Int
    let content: (Int) -> Content
    @Binding var currentIndex: Int
    let onIndexChanged: ((Int) -> Void)?
    
    @GestureState private var dragOffset: CGFloat = 0
    
    init(
        itemCount: Int,
        currentIndex: Binding<Int>,
        onIndexChanged: ((Int) -> Void)? = nil,
        @ViewBuilder content: @escaping (Int) -> Content
    ) {
        self.itemCount = itemCount
        self._currentIndex = currentIndex
        self.onIndexChanged = onIndexChanged
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            
            // Only render previous, current, next
            HStack(spacing: 0) {
                ForEach(visibleIndices, id: \.self) { index in
                    content(index)
                        .frame(width: width)
                }
            }
            // Calculate offset so middle one is currentIndex (second item in array)
            .offset(x: -width + dragOffset)
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.width
                    }
                    .onEnded { value in
                        let threshold = width / 2
                        var newIndex = currentIndex
                        
                        // Swipe left (negative translation) = next item
                        if value.translation.width < -threshold {
                            newIndex = min(currentIndex + 1, itemCount - 1)
                        }
                        // Swipe right (positive translation) = previous item
                        if value.translation.width > threshold {
                            newIndex = max(currentIndex - 1, 0)
                        }
                        
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                            currentIndex = newIndex
                        }
                        
                        // Notify about index change
                        onIndexChanged?(newIndex)
                    }
            )
        }
        .clipped()
    }
    
    // Indices for prev/current/next
    private var visibleIndices: [Int] {
        let prev = max(currentIndex - 1, 0)
        let next = min(currentIndex + 1, itemCount - 1)
        return [prev, currentIndex, next]
    }
}
