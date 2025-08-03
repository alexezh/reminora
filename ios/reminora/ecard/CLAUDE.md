# ecard/ Directory

## Purpose
ECard feature for creating decorative cards from photos using SVG templates with customizable text and image slots.

## Contents

### Core Components
- **ECardModels.swift** - Data models for templates, cards, and configuration
- **ECardTemplateService.swift** - Service managing SVG templates and built-in designs
- **ECardEditorView.swift** - Main editor interface for creating and customizing ECards

## Key Features

### Template System
- **SVG-based templates** with defined image and text slots using IDs (Image1, Image2, Text1, etc.)
- **Multiple categories**: Polaroid, Modern, Vintage, Holiday, Travel, General
- **Built-in templates**: Classic Polaroid, Modern Gradient, Vintage Postcard
- **Extensible architecture** for adding custom templates

### Editor Interface
- **Template selection** with category filters and thumbnail previews
- **Interactive preview** showing SVG with actual photos and text
- **Image assignment** via tap-to-select interface
- **Text editing** with inline TextField controls
- **Real-time preview** updates as user makes changes

### Integration
- **ActionRouter integration** - `.makeECard([PHAsset])` action type triggers editor
- **UniversalActionSheet** - "Make ECard" appears in Photos, Pins, and SwipePhoto contexts
- **SheetRouter managed** - Uses centralized sheet management via `.eCardEditor(assets:)` type
- **SelectionService integration** - Automatic asset selection from multi-photo selection or current photo
- **Environment services** - ECardTemplateService.shared injected via SwiftUI environment

## Template Structure

### SVG Template Format
```svg
<svg viewBox="0 0 400 500" xmlns="http://www.w3.org/2000/svg">
    <!-- Background and decorative elements -->
    
    <!-- Image slots with specific IDs -->
    <rect id="Image1" x="40" y="40" width="320" height="320"/>
    
    <!-- Text slots with specific IDs -->
    <text id="Text1" x="200" y="410">Your text here</text>
</svg>
```

### Image Slots
- **ID-based targeting** (Image1, Image2, etc.)
- **Position and size** defined in SVG coordinates
- **Corner radius support** for rounded images
- **Aspect ratio preservation** options

### Text Slots
- **ID-based targeting** (Text1, Text2, etc.) 
- **Font configuration** (family, size, alignment)
- **Multi-line support** with line limits
- **Placeholder text** for user guidance

## Usage Examples

### Triggering ECard Creation
```swift
// Single photo ECard
sheetStack.push(.eCardEditor(assets: [asset]))

// Multi-photo ECard (from selection)
sheetStack.push(.eCardEditor(assets: selectedAssets))
```

### Template Service
```swift
let templateService = ECardTemplateService.shared
let polaroidTemplates = templateService.getTemplates(for: .polaroid)
let template = templateService.getTemplate(id: "polaroid_classic")
```

### Creating Custom Templates
```swift
let customTemplate = ECardTemplate(
    id: "my_template",
    name: "Custom Design",
    svgContent: svgString,
    imageSlots: [ImageSlot(id: "Image1", x: 0, y: 0, width: 100, height: 100)],
    textSlots: [TextSlot(id: "Text1", x: 0, y: 100, width: 100, height: 20)],
    category: .general
)
```

## Future Enhancements

### Potential Features
- **Custom template creation** within the app
- **Template sharing** between users
- **Animation support** for dynamic ECards
- **Export options** (PNG, PDF, sharing)
- **Template marketplace** integration
- **AI-powered layout suggestions**

### Technical Improvements
- **True SVG rendering** with WebKit integration
- **Advanced text styling** (fonts, colors, effects)
- **Image filters and effects** within templates
- **Template versioning** and migration support
- **Cloud template synchronization**

## Design Patterns

### Service-Based Architecture
- **ECardTemplateService** manages all template operations
- **Environment injection** for consistent access
- **ObservableObject** for reactive UI updates

### Sheet Integration
- **Centralized routing** via SheetRouter
- **Consistent presentation** with other app sheets
- **Proper dismissal handling** and navigation flow

### Photo Integration
- **PHAsset compatibility** with existing photo system
- **Thumbnail loading** with proper caching
- **Selection service integration** for batch operations