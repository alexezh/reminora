# rlist/ Directory

## Purpose
List management system for organizing and sharing collections of places and photos.

## Contents

### Core List Views
- **RListView.swift** - Main list interface with unified photo/pin display system
- **RListDetailView.swift** - Detailed view of a specific list with items
- **AllRListsView.swift** - Browse all available lists
- **RListExampleView.swift** - Example/template list implementations

### Photo System (Complete - Do Not Add New Photo Classes)
- **RPhotoStack.swift** - Unified photo container class (single photos + photo stacks)
- **RListPhotoView.swift** - Single view component for all photo display needs

### List Creation & Management
- **RListPickerView.swift** - Select from existing lists
- **AddToListPickerView.swift** - Add items to lists interface

### Quick Lists
- **QuickListView.swift** - Fast access to frequently used lists
- **QuickListService.swift** - Service layer for Quick List functionality

### Sharing
- **SharedListView.swift** - View shared lists from other users
- **SharedListService.swift** - Handle list sharing and collaboration

### Documentation
- **RListView-Usage.md** - Documentation for list functionality

## Architecture

### View Hierarchy
- **RListView**: Main container with date sections and row management
  - **RListSectionView**: Groups items by date with smart row arrangement
    - **RListRowView**: Handles photo rows (.photoRow) and pin rows (.pinRow) with dynamic layout
      - **Photo Rows**: Direct usage of `RListPhotoView` with `RPhotoStack` objects
      - **Pin Rows**: Uses `RRListItemDataView` for pins and locations only

### Data Model
- **RRListItemDataType**: Only `.photoStack(RPhotoStack)`, `.pin(PinData)`, `.location(LocationInfo)`
- **RListPhotoStackItem**: Wrapper for `RPhotoStack` objects implementing `RListViewItem`
- **RListPinItem/RListLocationItem**: Wrappers for pins and locations

### Photo Layout System
- **Dynamic row heights**: Each row calculates optimal height based on photo aspect ratios
- **Proportional widths**: Photos get width proportional to their aspect ratio within available space  
- **Constraints**: Min height 80px, max height 200px per row
- **Time-based stacking**: Photos grouped by 10-minute intervals, max 3 photos per stack

### Photo Selection System
- **Full selection**: All photos in stack selected (blue checkmark)
- **Partial selection**: Some photos in stack selected (orange minus icon)
- **No selection**: Gray circle outline
- **Visual indicators**: Enhanced visibility with white background and shadow

## Important Notes

### PHOTO SYSTEM IS COMPLETE
**DO NOT ADD NEW PHOTO-RELATED CLASSES OR VIEWS**

The photo system has been unified and simplified:
- `RPhotoStack` handles both single photos and photo stacks
- `RListPhotoView` is the single view component for all photo display
- All photo functionality is contained within these two classes

### View Responsibilities
- **RListPhotoView**: Handles ALL photo display (single photos, stacks, selection, loading)
- **RRListItemDataView**: Handles ONLY pins and locations (no photo code)
- **RListRowView**: Direct integration with appropriate view types per row

### Code Guidelines
- Photo rows contain only `RPhotoStack` objects
- Pin rows contain only pins and locations
- No wrapper views needed - use components directly
- Maintain separation between photo and pin/location handling

## Key Features
- Create and manage custom lists
- Add places and photos to lists  
- Share lists with other users
- Quick List for rapid item collection
- List collaboration features
- Search and filter list items
- List templates and examples
- Integration with Core Data storage
- Unified photo stack system with smart layout
- Enhanced selection indicators and visual feedback