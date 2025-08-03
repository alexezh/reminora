# data/ Directory

## Purpose
Data layer containing Room database entities, DAOs, API services, repositories, and data models for the Android app.

## Contents

### Local Database (Room)
- **ReminoraDatabase.kt** - Main Room database configuration
- **Place.kt** - Core place/pin entity (equivalent to iOS PinData)
- **PlaceDao.kt** - Data Access Object for place operations
- **Comment.kt** - Comment entity for pin interactions
- **CommentDao.kt** - DAO for comment operations
- **UserList.kt** - User list entity (equivalent to iOS RListData)
- **UserListDao.kt** - DAO for list operations
- **ListItem.kt** - List item entity (equivalent to iOS RListItemData)
- **ListItemDao.kt** - DAO for list item operations
- **PhotoLocationCache.kt** - Photo location caching entity
- **Converters.kt** - Type converters for Room database

### Network Layer
- **api/ApiService.kt** - Retrofit service for API communication

### Data Models
- **model/PlaceAddress.kt** - Address model for places
- **model/User.kt** - User data model

### Repositories
- **repository/AuthRepository.kt** - Authentication data operations
- **repository/PhotoRepository.kt** - Photo data operations
- **repository/QuickListRepository.kt** - Quick List data operations

## Key Features

### Room Database
- **Entity Relationships**: Proper foreign key relationships between entities
- **Type Converters**: Handle complex data types (JSON, dates, coordinates)
- **Migration Support**: Database schema migration handling
- **Transaction Support**: Atomic operations for data consistency

### Repository Pattern
- **Data Abstraction**: Clean separation between UI and data layers
- **Single Source of Truth**: Repositories manage data from multiple sources
- **Caching Strategy**: Local caching with network updates
- **Error Handling**: Consistent error handling across data operations

## iOS Parity Requirements

### Missing Data Layer Features
1. **Photo Embedding System**
   - ImageEmbeddingService equivalent for AI photo similarity
   - Photo embedding storage and comparison
   - ML model integration for photo analysis

2. **Enhanced Place Data**
   - Multiple address support (locations array like iOS)
   - Photo stack grouping and management
   - Advanced place filtering and search

3. **ECard Data Models**
   - ECard template entities
   - Template configuration storage
   - SVG template management

4. **Selection Management**
   - Multi-selection state persistence
   - Selection service data layer
   - Cross-screen selection consistency

5. **Action System Data**
   - Action context storage
   - Action history and preferences
   - User action analytics

### Database Schema Updates Needed
```kotlin
// Enhanced Place entity to match iOS
@Entity(tableName = "places")
data class Place(
    @PrimaryKey val id: String,
    val imageData: ByteArray?,
    val location: String, // JSON serialized CLLocation equivalent
    val locations: String, // JSON array of PlaceAddress objects
    val dateAdded: Long,
    val post: String?,
    val url: String?,
    val cloudId: String?,
    val isPrivate: Boolean = false,
    val originalUserId: String?,
    val originalUsername: String?,
    val originalDisplayName: String?
)

// Photo embedding entity for AI features
@Entity(tableName = "photo_embeddings")
data class PhotoEmbedding(
    @PrimaryKey val photoId: String,
    val embedding: ByteArray, // Serialized embedding vector
    val lastUpdated: Long,
    val version: Int
)
```

### Repository Enhancements Needed
- **PhotoSimilarityRepository**: AI photo comparison operations
- **ECardRepository**: Template and card management
- **SelectionRepository**: Multi-selection state management
- **ActionRepository**: Action system data operations

## Architecture Patterns

### Dependency Injection
```kotlin
@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {
    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): ReminoraDatabase {
        return Room.databaseBuilder(
            context,
            ReminoraDatabase::class.java,
            "reminora_database"
        ).build()
    }
}
```

### Repository Implementation
```kotlin
@Singleton
class PhotoRepository @Inject constructor(
    private val photoDao: PhotoDao,
    private val apiService: ApiService
) {
    suspend fun getPhotos(): Flow<List<PhotoEntity>> {
        return photoDao.getAllPhotos()
    }
    
    suspend fun syncWithCloud() {
        // Sync logic
    }
}
```

## Data Consistency

### Synchronization Strategy
- **Local-First**: Prioritize local data for immediate UI updates
- **Background Sync**: Sync with cloud in background
- **Conflict Resolution**: Handle data conflicts between local and cloud
- **Offline Support**: Full offline functionality with sync when available

### Transaction Management
- **Atomic Operations**: Use Room transactions for data consistency
- **Batch Operations**: Efficient bulk data operations
- **Error Recovery**: Proper rollback on operation failures