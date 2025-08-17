# clip/ Directory

## Purpose
Clip editor feature for creating videos from a sequence of pictures with transitions and timing controls.

## Contents

### Core Components
- **Clip.swift** - Data models for clips and clip management service
- **ClipEditor.swift** - State management and video generation service for clip editing
- **ClipEditorView.swift** - Main editor interface with list and player modes

## Key Features

### Clip Management
- **Clip Model**: Represents a sequence of photos with timing and transition settings
- **Persistent Storage**: Clips are serialized to UserDefaults for persistence across app sessions
- **Asset Management**: Uses PHAsset localIdentifiers for photo references with validation
- **Automatic Naming**: Generates clip names based on photo creation dates

### Editor Interface
- **Dual Mode Interface**: List mode for organizing photos, Player mode for preview playback
- **Interactive Image Grid**: 3-column grid showing photos with remove buttons and sequence numbers
- **Real-time Preview**: Generate video previews with AVPlayer integration
- **Settings Panel**: Configure clip name, duration per image, and transition effects

### Video Generation
- **High Quality Output**: 1080x1080 square format at 2Mbps bitrate
- **Multiple Transitions**: Support for fade, slide, zoom, and no transition effects
- **Progress Tracking**: Real-time progress updates during video generation
- **AVFoundation Integration**: Uses AVAssetWriter for professional video encoding

## Architecture

### State Management
- **ClipEditor**: Centralized state manager with persistence, session management, and RList integration
- **Environment Integration**: ClipEditor injected via SwiftUI environment

### Data Flow
1. **Creation**: Start with selected PHAssets from photo library
2. **Editing**: Modify sequence, timing, and transition settings
3. **Preview**: Generate temporary video files for playback
4. **Export**: Save final video to device or share externally

### Video Pipeline
1. **Asset Loading**: Load high-resolution images from PHImageManager
2. **Pixel Buffer Creation**: Convert UIImages to CVPixelBuffers for video encoding
3. **Temporal Sequencing**: Apply timing and transition effects between frames
4. **Encoding**: Use AVAssetWriter with H.264 codec for final output

## Integration

### ActionRouter Integration
- **Action Type**: `.makeClip([PHAsset])` action type triggers clip editor
- **Context Handling**: Uses `.clip` context for UniversalActionSheet integration
- **Session Management**: Automatic state persistence and restoration

### UniversalActionSheet
- **Context-Specific Actions**: "Make Clip" appears in Photos, Pins, and SwipePhoto contexts
- **Editor State**: ClipEditor.shared manages active editing sessions
- **Tab Integration**: Automatically switches to appropriate context when clip editing begins

### Photo Integration
- **PHAsset Compatibility**: Full integration with existing photo system
- **Selection Service**: Works with multi-photo selection from SelectionService
- **Asset Validation**: Handles cases where assets may no longer exist in photo library

## Usage Examples

### Creating a New Clip
```swift
// Start clip editor with selected assets
ClipEditor.shared.startEditing(with: selectedAssets)

// Or via ActionRouter
ActionRouter.shared.execute(.makeClip(selectedAssets))
```

### Clip Management
```swift
// Save current clip
ClipEditor.shared.saveClip()

// Update clip settings
ClipEditor.shared.updateClip(
    name: "My Vacation",
    duration: 3.0,
    transition: .fade
)

// Generate video
ClipEditor.shared.generateVideo { result in
    switch result {
    case .success(let videoURL):
        // Handle generated video
    case .failure(let error):
        // Handle error
    }
}
```

### Clip Management Operations
```swift
let clipEditor = ClipEditor.shared

// Add new clip
let newClip = Clip(name: "Summer Trip", assets: assets)
clipEditor.addClip(newClip)

// Delete clip
clipEditor.deleteClip(id: clipId)

// Update clip RList entry
clipEditor.updateRListEntry(for: clip)
```

## Technical Details

### Video Specifications
- **Resolution**: 1080x1080 pixels (square format)
- **Codec**: H.264 with MPEG-4 container (.mp4)
- **Bitrate**: 2 Mbps average
- **Frame Rate**: Variable based on duration per image setting
- **Color Space**: RGB with alpha channel support

### Transition Effects
- **None**: Direct cuts between images
- **Fade**: Cross-fade transitions with alpha blending
- **Slide**: Horizontal sliding motion between frames
- **Zoom**: Scale-based transitions with zoom effects

### Performance Optimizations
- **Asynchronous Processing**: Video generation on background queue
- **Progress Callbacks**: Real-time progress updates for UI responsiveness
- **Memory Management**: Efficient pixel buffer handling with proper cleanup
- **Temporary Files**: Automatic cleanup of generated preview files

## User Experience

### List Mode Features
- **Visual Grid**: 3-column grid layout showing photo thumbnails
- **Sequence Numbers**: Clear indicators showing photo order in final video
- **Remove Actions**: Individual photo removal with confirmation
- **Add Photos**: Button to expand clip with additional images

### Player Mode Features
- **Video Preview**: Full-screen video player with standard controls
- **Playback Controls**: Play, pause, restart, and export buttons
- **Generation Progress**: Visual progress indicator during video creation
- **Quality Preview**: High-quality preview matching final output

### Settings Panel
- **Clip Naming**: Text field for custom clip names
- **Duration Control**: Slider for setting duration per image (0.5-10 seconds)
- **Transition Selection**: Segmented control for transition type selection
- **Real-time Updates**: Immediate application of setting changes

## Future Enhancements

### Potential Features
- **Advanced Transitions**: More sophisticated transition effects
- **Audio Support**: Background music and sound effect integration
- **Variable Timing**: Per-image duration controls
- **Filter Effects**: Image filters and color adjustments
- **Text Overlays**: Title cards and caption support

### Technical Improvements
- **Export Options**: Multiple resolution and quality presets
- **Cloud Storage**: iCloud sync for clips across devices
- **Batch Processing**: Generate multiple clips simultaneously
- **Format Support**: Additional output formats (GIF, WebM)
- **Template System**: Pre-built clip templates with preset timings

## Design Patterns

### Service-Based Architecture
- **ClipEditor** handles all data persistence, CRUD operations, and video generation
- **RList Integration** managed directly within ClipEditor for clips storage
- **Environment injection** for consistent access across views

### Error Handling
- **Comprehensive Error Types**: Specific error cases for different failure modes
- **Graceful Degradation**: Fallbacks for missing assets or generation failures
- **User Feedback**: Clear error messages and recovery suggestions

### Memory Management
- **Weak References**: Proper memory management in completion handlers
- **Resource Cleanup**: Automatic cleanup of temporary files and pixel buffers
- **Background Processing**: Non-blocking UI during intensive operations