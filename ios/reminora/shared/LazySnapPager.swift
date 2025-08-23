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
    
    private func getOffset(width: CGFloat, offs: CGFloat) -> CGFloat {
        print("offset \(offs)")
        return -width + offs; // always center the middle item in [prev, current, next]
    }
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            
            // Only render previous, current, next
            ZStack {
                HStack(spacing: 0) {
                    ForEach(visibleIndices, id: \.self) { index in
                        content(index)
                            .frame(width: width)
                    }
                }
                .offset(x: -width + dragOffset, y: verticalOffset)
            }
            // Calculate offset so middle one is currentIndex (second item in array)
            //.animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentIndex)
            //.id("gesture-\(currentIndex)")
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        let translationX = value.translation.width
                        let translationY = value.translation.height
                        
                        print("dragOffset = \(value.translation.width)")
                        
                        // Only allow horizontal drag for paging if gesture is primarily horizontal
                        //if abs(translationX) > abs(translationY) {
                            state = translationX
                        //}
                        
                        // Update vertical offset for pull-down gesture
                        if abs(translationY) > abs(translationX) && translationY > 0 {
                            verticalOffset = min(translationY * 0.5, 200)
                        }
                    }
                    .onEnded { value in
                        let translationX = value.translation.width
                        let translationY = value.translation.height
                        let velocityY = value.velocity.height
                        
                        print("end = \(value.translation.width)")

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
                            let velocityX = value.velocity.width
                            let threshold: CGFloat = 50 // Minimum drag distance to trigger page change
                            var newIndex = currentIndex
                            
                            // Determine new index based on drag distance and velocity
                            if abs(translationX) > threshold || abs(velocityX) > 300 {
                                // Strong velocity or significant drag
                                if velocityX < -300 || (translationX < -threshold && velocityX <= 300) {
                                    // Swipe left (negative) = next item
                                    newIndex = min(currentIndex + 1, itemCount - 1)
                                } else if velocityX > 300 || (translationX > threshold && velocityX >= -300) {
                                    // Swipe right (positive) = previous item
                                    newIndex = max(currentIndex - 1, 0)
                                }
                            }
                            // If drag distance is small and velocity is low, snap back to current
                            
                            // Always animate to ensure snapping (either to new index or back to current)
                            let indexChanged = newIndex != currentIndex
                            
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                                currentIndex = newIndex
                            }
                            
                            // Notify about index change if it actually changed
                            if indexChanged {
                                onIndexChanged?(newIndex)
                            }
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
