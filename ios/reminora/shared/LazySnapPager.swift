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
    let onVerticalPull: (() -> Void)?
    
    @GestureState private var dragOffset: CGFloat = 0
    @State private var verticalOffset: CGFloat = 0
    
    init(
        itemCount: Int,
        currentIndex: Binding<Int>,
        onIndexChanged: ((Int) -> Void)? = nil,
        onVerticalPull: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Int) -> Content
    ) {
        self.itemCount = itemCount
        self._currentIndex = currentIndex
        self.onIndexChanged = onIndexChanged
        self.onVerticalPull = onVerticalPull
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
            .offset(x: -width + dragOffset, y: verticalOffset)
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        let translationX = value.translation.width
                        let translationY = value.translation.height
                        
                        // Only allow horizontal drag for paging if gesture is primarily horizontal
                        if abs(translationX) > abs(translationY) {
                            state = translationX
                        }
                        
                        // Update vertical offset for pull-down gesture
                        if abs(translationY) > abs(translationX) && translationY > 0 {
                            verticalOffset = min(translationY * 0.5, 200)
                        }
                    }
                    .onEnded { value in
                        let translationX = value.translation.width
                        let translationY = value.translation.height
                        let velocityY = value.velocity.height
                        
                        // Handle vertical pull-down to dismiss
                        if abs(translationY) > abs(translationX) && (translationY > 150 || velocityY > 800) {
                            onVerticalPull?()
                            return
                        }
                        
                        // Reset vertical offset if not dismissing
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                            verticalOffset = 0
                        }
                        
                        // Handle horizontal paging only if gesture was primarily horizontal
                        if abs(translationX) > abs(translationY) {
                            let threshold = width / 2
                            var newIndex = currentIndex
                            
                            // Swipe left (negative translation) = next item
                            if translationX < -threshold {
                                newIndex = min(currentIndex + 1, itemCount - 1)
                            }
                            // Swipe right (positive translation) = previous item
                            if translationX > threshold {
                                newIndex = max(currentIndex - 1, 0)
                            }
                            
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                                currentIndex = newIndex
                            }
                            
                            // Notify about index change
                            onIndexChanged?(newIndex)
                        }
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
