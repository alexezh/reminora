# onion/ Directory

## Purpose
Onion is a powerful composition engine for creating layered visual designs combining images, text, and geometric shapes. The system provides professional-grade layer management, transformations, filters, and high-quality rendering capabilities.

## Contents

### Core Components
- **OnionModels.swift** - Data models for layers, transforms, filters, and layer types
- **OnionScene.swift** - Scene composition system with layer management and selection
- **OnionRenderer.swift** - High-performance rendering engine for preview and export

## Key Features

### Layer System
- **Multiple Layer Types**: Image, Text, Geometry (shapes), and Group layers
- **Z-Order Management**: Precise layer ordering with front/back operations
- **Transform System**: Position, size, rotation, scale, opacity, and anchor points
- **Filter Support**: Blur, brightness, contrast, saturation, sepia, vintage, and shadow effects
- **Content Modes**: Comprehensive image scaling and positioning options

### Scene Management
- **Layer Operations**: Add, remove, duplicate, reorder, and group layers
- **Selection System**: Multi-select with alignment and transformation tools
- **Bounds Calculation**: Automatic content bounds and selection bounds
- **Version Control**: Scene versioning with metadata support

### Rendering Engine
- **Quality Levels**: Preview, Standard, High, and Print quality rendering
- **Output Formats**: JPEG, PNG, and HEIC with configurable compression
- **Scalable Output**: From thumbnails to print-resolution exports
- **Performance Monitoring**: Memory usage estimation and render statistics
- **Async Rendering**: Non-blocking render operations with progress tracking

## Architecture

### Layer Protocol Design
```swift
protocol OnionLayer: Codable, Identifiable, Equatable {
    var id: UUID { get }
    var name: String { get set }
    var transform: LayerTransform { get set }
    var filters: [LayerFilter] { get set }
    var isVisible: Bool { get set }
    var zOrder: Int { get set }
    var layerType: LayerType { get }
    
    func render(in context: CGContext, bounds: CGRect) throws
    func naturalSize() -> CGSize
    func copy() -> Self
}
```

### Transform System
- **Position**: X/Y coordinates in scene space
- **Size**: Width/height dimensions
- **Rotation**: Angle in radians around anchor point
- **Scale**: Uniform or non-uniform scaling factor
- **Opacity**: Alpha transparency (0.0 to 1.0)
- **Anchor Point**: Transform origin (normalized 0-1 coordinates)

### Layer Types

#### Image Layer
- **Image Data**: JPEG/PNG data storage
- **Content Modes**: Scale to fill, aspect fit, aspect fill, positioning modes
- **Filter Chain**: Stackable image processing filters
- **Memory Management**: Efficient image data handling

#### Text Layer
- **Rich Text**: Font family, size, color, alignment configuration
- **Typography**: Line spacing, letter spacing, text alignment
- **Multi-line Support**: Configurable line limits and overflow handling
- **Core Text Rendering**: High-quality text rendering with proper metrics

#### Geometry Layer
- **Shape Types**: Rectangle, circle, ellipse, triangle, star, polygon
- **Fill/Stroke**: Configurable fill and stroke colors with line width
- **Corner Radius**: Rounded rectangles with custom corner radius
- **Path Generation**: Efficient CGPath creation for each shape type

#### Group Layer
- **Child Management**: Nested layer hierarchies with z-order preservation
- **Clipping**: Optional content clipping to group bounds
- **Transform Propagation**: Inherited transformations for child layers
- **Bounds Calculation**: Automatic bounding box computation

### Scene Composition
```swift
class OnionScene: ObservableObject, Codable {
    @Published var layers: [AnyOnionLayer]
    @Published var selectedLayerIds: Set<UUID>
    
    // Layer management
    func addLayer<T: OnionLayer>(_ layer: T)
    func removeLayer(withId id: UUID)
    func duplicateLayer(withId id: UUID)
    func moveLayer(fromIndex: Int, toIndex: Int)
    
    // Selection operations
    func selectLayer(withId id: UUID, addToSelection: Bool = false)
    func translateSelectedLayers(by offset: CGPoint)
    func scaleSelectedLayers(by factor: CGFloat, aroundPoint: CGPoint?)
    func rotateSelectedLayers(by angle: CGFloat, aroundPoint: CGPoint?)
    
    // Alignment tools
    func alignSelectedLayers(_ alignment: LayerAlignment)
}
```

### Rendering Pipeline
1. **Scene Validation**: Verify layer integrity and visibility
2. **Context Creation**: Generate graphics context with appropriate scale and format
3. **Background Rendering**: Fill scene background color
4. **Layer Sorting**: Order layers by z-index for proper compositing
5. **Layer Rendering**: Render each visible layer with transforms and filters
6. **Format Conversion**: Convert to target format (JPEG/PNG/HEIC) with quality settings
7. **Statistics Collection**: Gather performance metrics and memory usage

## Usage Examples

### Creating a Basic Scene
```swift
let scene = OnionScene(name: "My Design", size: CGSize(width: 800, height: 600))

// Add background image
var imageLayer = ImageLayer(name: "Background")
imageLayer.imageData = backgroundImageData
imageLayer.transform.size = scene.size
scene.addLayer(imageLayer)

// Add title text
var textLayer = TextLayer(name: "Title")
textLayer.text = "My Design"
textLayer.fontSize = 48
textLayer.textColor = "#FFFFFF"
textLayer.transform.position = CGPoint(x: 100, y: 50)
scene.addLayer(textLayer)

// Add shape overlay
var shapeLayer = GeometryLayer(name: "Accent")
shapeLayer.shape = .circle
shapeLayer.fillColor = "#FF6B6B"
shapeLayer.transform = LayerTransform(
    position: CGPoint(x: 600, y: 400),
    size: CGSize(width: 100, height: 100)
)
scene.addLayer(shapeLayer)
```

### Rendering Options
```swift
let renderer = OnionRenderer.shared

// Quick preview
let previewImage = try await renderer.renderPreview(scene: scene)

// High-quality export
let config = OnionRenderConfig(scene: scene, quality: .high, format: .png)
let result = try await renderer.render(scene: scene, config: config)

// Save to photo library
UIImageWriteToSavedPhotosAlbum(result.image, nil, nil, nil)
```

### Layer Transformations
```swift
// Select and transform layers
scene.selectLayer(withId: textLayer.id)
scene.translateSelectedLayers(by: CGPoint(x: 50, y: 0))
scene.scaleSelectedLayers(by: 1.2)
scene.rotateSelectedLayers(by: .pi / 4) // 45 degrees

// Alignment operations
scene.selectAllLayers()
scene.alignSelectedLayers(.centerHorizontal)
```

### Filter Application
```swift
// Apply filters to image layer
imageLayer.filters = [
    .brightness(amount: 0.2),
    .contrast(amount: 1.3),
    .sepia(intensity: 0.5)
]

// Add shadow to text
textLayer.filters = [
    .shadow(offset: CGSize(width: 2, height: 2), blur: 4, color: "#000000")
]
```

## Performance Considerations

### Memory Management
- **Lazy Loading**: Images loaded only when needed for rendering
- **Memory Estimation**: Pre-render memory usage calculation
- **Quality Scaling**: Automatic quality reduction for large scenes
- **Resource Cleanup**: Proper disposal of graphics contexts and image data

### Rendering Optimization
- **Layer Culling**: Skip rendering invisible or out-of-bounds layers
- **Progressive Rendering**: Incremental render updates for large scenes
- **Background Processing**: Async rendering without blocking UI
- **Caching Strategy**: Reuse rendered layer content when possible

### Device Compatibility
- **Memory Limits**: Automatic quality reduction on memory-constrained devices
- **Scale Factor Detection**: Adapt to device pixel density
- **Format Selection**: Choose optimal output format based on content

## Integration Guidelines

### With Existing Systems
- **PhotoLibraryService**: Import images from photo library into image layers
- **ActionRouter**: Add "Create Composition" actions to photo workflows
- **UniversalActionSheet**: Composition tools in context-sensitive menus
- **SheetStack**: Present composition editor as modal sheets

### Editor Interface Considerations
- **Layer Panel**: Hierarchical layer list with visibility toggles
- **Property Inspector**: Transform and filter controls for selected layers
- **Canvas View**: Interactive scene editing with direct manipulation
- **Tool Palette**: Layer creation tools and alignment utilities

## Future Enhancements

### Advanced Features
- **Animation System**: Keyframe-based layer animations
- **Blend Modes**: Photoshop-style layer blending options
- **Smart Objects**: Linked layer content with update propagation
- **Vector Graphics**: SVG layer support with scalable vector content
- **3D Transforms**: Perspective transformations and 3D layer positioning

### Workflow Integration
- **Template System**: Pre-built composition templates
- **Asset Library**: Shared resource management for images and fonts
- **Collaboration**: Multi-user editing with conflict resolution
- **Version History**: Scene change tracking with undo/redo
- **Export Presets**: Common output configurations for different use cases

### Performance Improvements
- **Metal Rendering**: GPU-accelerated layer composition
- **Multi-threading**: Parallel layer rendering for complex scenes
- **Streaming**: Progressive loading for large image assets
- **Compression**: Advanced image compression for storage efficiency

## Design Patterns

### Protocol-Oriented Design
- **Layer Protocol**: Common interface for all layer types
- **Type Erasure**: AnyOnionLayer wrapper for heterogeneous collections
- **Copy-on-Write**: Efficient layer duplication and modification

### Reactive Architecture
- **Observable Objects**: Real-time UI updates via Combine publishers
- **Environment Injection**: Service availability through SwiftUI environment
- **Async Operations**: Non-blocking operations with proper cancellation

### Error Handling
- **Typed Errors**: Specific error types for different failure modes
- **Graceful Degradation**: Fallback rendering when layers fail
- **Recovery Mechanisms**: Automatic retry for transient failures

This composition engine provides a solid foundation for professional-grade image editing and design tools within the Reminora app ecosystem.