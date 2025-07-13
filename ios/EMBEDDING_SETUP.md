# Image Embedding Setup Instructions

## Core Data Model Update Required

To enable image similarity comparison, you need to add an `imageEmbedding` field to the Place entity in your Core Data model.

### Steps:

1. **Open Xcode**
2. **Navigate to** `places.xcdatamodeld/places.xcdatamodel`
3. **Select the Place entity**
4. **Add a new attribute:**
   - Name: `imageEmbedding`
   - Type: `Binary Data`
   - Optional: ✅ (checked)
   - Allow External Storage: ✅ (checked) - for large embedding vectors

### Alternative: Programmatic Approach

If you prefer to handle this programmatically without modifying the .xcdatamodeld file, the current implementation stores embeddings using `setValue(forKey:)` which should work with the existing Core Data infrastructure.

## Implementation Features

✅ **ImageEmbeddingService**: Uses Vision framework with VNGenerateImageFeaturePrintRequest for robust feature extraction

✅ **Automatic Embedding Computation**: New photos automatically get embeddings computed in background

✅ **Similarity Search**: Find visually similar images with adjustable thresholds

✅ **Duplicate Detection**: Identify potential duplicate photos

✅ **UI Integration**: "Similar" button in photo viewer to explore similar images

## Usage

1. **View Similar Images**: In the photo viewer, tap the "Similar" button
2. **Adjust Threshold**: Use percentage buttons to change similarity sensitivity
3. **Compute Missing**: Batch process all photos without embeddings
4. **Statistics**: View coverage of analyzed photos

## Technical Details

- **Embedding Size**: ~1280 floating-point values per image
- **Model**: Uses Apple's Vision framework (VNGenerateImageFeaturePrintRequest)
- **Storage**: Binary data in Core Data with external storage for efficiency
- **Performance**: Background computation to avoid UI blocking
- **Similarity**: Cosine similarity comparison between embedding vectors

## Benefits

- Find duplicate photos in your library
- Discover similar compositions or subjects
- Organize photos by visual similarity
- Identify patterns in your photography
- Enhanced photo discovery and browsing