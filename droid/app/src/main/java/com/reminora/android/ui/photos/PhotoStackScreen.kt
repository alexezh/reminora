package com.reminora.android.ui.photos

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import coil.compose.AsyncImage
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PhotoStackScreen(
    viewModel: PhotoStackViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        // Top app bar
        TopAppBar(
            title = {
                Text(
                    "Photos",
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold
                )
            }
        )
        
        when {
            !uiState.hasPermission -> {
                PermissionRequestContent(
                    onRequestPermission = { viewModel.requestPermission() }
                )
            }
            uiState.isLoading -> {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator()
                }
            }
            uiState.photoStacks.isEmpty() -> {
                EmptyPhotosContent()
            }
            else -> {
                Column {
                    // Filter tabs
                    FilterTabs(
                        currentFilter = uiState.currentFilter,
                        onFilterSelected = { filter ->
                            viewModel.setFilter(filter)
                        }
                    )
                    
                    PhotoStackGrid(
                        photoStacks = uiState.photoStacks,
                        onStackClick = { stack ->
                            viewModel.selectStack(stack)
                        },
                        getPhotoPreference = { photo ->
                            viewModel.getPhotoPreference(photo)
                        },
                        isPhotoInQuickList = { photo ->
                            viewModel.isPhotoInQuickList(photo)
                        },
                        onQuickListToggle = { photo ->
                            viewModel.togglePhotoInQuickList(photo)
                        }
                    )
                }
            }
        }
    }
    
    // Show photo viewer when stack is selected
    if (uiState.selectedStack != null) {
        SwipePhotoView(
            stack = uiState.selectedStack!!,
            initialIndex = uiState.selectedIndex,
            onDismiss = { viewModel.clearSelection() },
            onPin = { photo -> viewModel.pinPhoto(photo) },
            onShare = { photo -> viewModel.sharePhoto(photo) },
            onLike = { photo -> viewModel.setPhotoPreference(photo, PhotoPreferenceType.LIKE) },
            onDislike = { photo -> viewModel.setPhotoPreference(photo, PhotoPreferenceType.DISLIKE) },
            getPhotoPreference = { photo -> viewModel.getPhotoPreference(photo) },
            isPhotoInQuickList = { photo -> viewModel.isPhotoInQuickList(photo) },
            onQuickListToggle = { photo -> viewModel.togglePhotoInQuickList(photo) }
        )
    }
}

@Composable
private fun PermissionRequestContent(
    onRequestPermission: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = Icons.Default.Photo,
            contentDescription = null,
            modifier = Modifier.size(64.dp),
            tint = MaterialTheme.colorScheme.primary
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        Text(
            text = "Photo Access Required",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold
        )
        
        Spacer(modifier = Modifier.height(8.dp))
        
        Text(
            text = "Please allow access to your photo library to see your photos",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        
        Spacer(modifier = Modifier.height(24.dp))
        
        Button(
            onClick = onRequestPermission,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Grant Access")
        }
    }
}

@Composable
private fun EmptyPhotosContent() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = Icons.Default.PhotoLibrary,
            contentDescription = null,
            modifier = Modifier.size(64.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        Text(
            text = "No Photos Found",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold
        )
        
        Spacer(modifier = Modifier.height(8.dp))
        
        Text(
            text = "Your photo library appears to be empty",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun FilterTabs(
    currentFilter: PhotoFilterType,
    onFilterSelected: (PhotoFilterType) -> Unit
) {
    LazyRow(
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        items(listOf(
            PhotoFilterType.NOT_DISLIKED,
            PhotoFilterType.ALL,
            PhotoFilterType.FAVORITES,
            PhotoFilterType.DISLIKES
        )) { filter ->
            FilterChip(
                selected = currentFilter == filter,
                onClick = { onFilterSelected(filter) },
                label = { Text(filter.displayName) },
                leadingIcon = {
                    Icon(
                        imageVector = when (filter.iconName) {
                            "photo" -> Icons.Default.Photo
                            "photo_library" -> Icons.Default.PhotoLibrary
                            "favorite" -> Icons.Default.Favorite
                            "cancel" -> Icons.Default.Cancel
                            else -> Icons.Default.Photo
                        },
                        contentDescription = null,
                        modifier = Modifier.size(16.dp)
                    )
                }
            )
        }
    }
}

@Composable
private fun PhotoStackGrid(
    photoStacks: List<PhotoStack>,
    onStackClick: (PhotoStack) -> Unit,
    getPhotoPreference: (Photo) -> PhotoPreferenceType,
    isPhotoInQuickList: (Photo) -> Boolean,
    onQuickListToggle: (Photo) -> Unit
) {
    LazyVerticalGrid(
        columns = GridCells.Fixed(4), // Changed to 4 columns
        contentPadding = PaddingValues(1.dp),
        verticalArrangement = Arrangement.spacedBy(1.dp),
        horizontalArrangement = Arrangement.spacedBy(1.dp),
        modifier = Modifier.fillMaxSize()
    ) {
        items(photoStacks) { stack ->
            PhotoStackCell(
                stack = stack,
                onClick = { onStackClick(stack) },
                getPhotoPreference = getPhotoPreference,
                isPhotoInQuickList = isPhotoInQuickList,
                onQuickListToggle = onQuickListToggle
            )
        }
    }
}

@Composable
private fun PhotoStackCell(
    stack: PhotoStack,
    onClick: () -> Unit,
    getPhotoPreference: (Photo) -> PhotoPreferenceType,
    isPhotoInQuickList: (Photo) -> Boolean,
    onQuickListToggle: (Photo) -> Unit
) {
    val stackHasFavorite = stack.photos.any { getPhotoPreference(it) == PhotoPreferenceType.LIKE }
    val primaryPreference = getPhotoPreference(stack.primaryPhoto)
    val shouldShowFavoriteIcon = if (stack.isStack) stackHasFavorite else primaryPreference == PhotoPreferenceType.LIKE
    val shouldShowDislikeIcon = !stack.isStack && primaryPreference == PhotoPreferenceType.DISLIKE
    val isInQuickList = isPhotoInQuickList(stack.primaryPhoto)
    
    Box(
        modifier = Modifier
            .aspectRatio(1f)
            .clip(RoundedCornerShape(2.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .clickable { onClick() }
    ) {
        // Load actual photo thumbnail
        AsyncImage(
            model = stack.primaryPhoto.uri,
            contentDescription = null,
            modifier = Modifier.fillMaxSize(),
            contentScale = ContentScale.Crop
        )
        
        // Overlay indicators
        Column(
            modifier = Modifier.fillMaxSize()
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                // Favorite indicator (top-left)
                if (shouldShowFavoriteIcon) {
                    Box(
                        modifier = Modifier
                            .padding(4.dp)
                            .size(20.dp)
                            .background(
                                Color.Black.copy(alpha = 0.7f),
                                CircleShape
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            Icons.Default.Favorite,
                            contentDescription = "Favorite",
                            tint = Color.White,
                            modifier = Modifier.size(12.dp)
                        )
                    }
                } else {
                    Spacer(modifier = Modifier.size(28.dp))
                }
                
                // Stack indicator (top-right)
                if (stack.isStack) {
                    Box(
                        modifier = Modifier
                            .padding(4.dp)
                            .size(24.dp)
                            .background(
                                Color.Black.copy(alpha = 0.7f),
                                CircleShape
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = stack.count.toString(),
                            color = Color.White,
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Medium
                        )
                    }
                }
            }
            
            Spacer(modifier = Modifier.weight(1f))
            
            // Bottom row with Quick List FAB and Dislike indicator
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Bottom
            ) {
                // Quick List FAB (bottom-left)
                Box(
                    modifier = Modifier
                        .padding(4.dp)
                        .size(24.dp)
                        .background(
                            if (isInQuickList) MaterialTheme.colorScheme.primary else Color.Black.copy(alpha = 0.7f),
                            CircleShape
                        )
                        .clickable { onQuickListToggle(stack.primaryPhoto) },
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        if (isInQuickList) Icons.Default.Check else Icons.Default.Add,
                        contentDescription = if (isInQuickList) "Remove from Quick List" else "Add to Quick List",
                        tint = if (isInQuickList) Color.White else Color.White,
                        modifier = Modifier.size(16.dp)
                    )
                }
                
                // Dislike indicator (bottom-right)
                if (shouldShowDislikeIcon) {
                    Box(
                        modifier = Modifier
                            .padding(4.dp)
                            .size(20.dp)
                            .background(
                                Color.Black.copy(alpha = 0.7f),
                                CircleShape
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            Icons.Default.Cancel,
                            contentDescription = "Disliked",
                            tint = Color.Red,
                            modifier = Modifier.size(12.dp)
                        )
                    }
                } else {
                    Spacer(modifier = Modifier.size(28.dp))
                }
            }
        }
    }
}

// Data classes
data class PhotoStack(
    val id: String,
    val photos: List<Photo>,
    val primaryPhoto: Photo
) {
    val isStack: Boolean get() = photos.size > 1
    val count: Int get() = photos.size
}

data class Photo(
    val id: String,
    val uri: String,
    val creationDate: Long,
    val location: Location? = null
)

data class Location(
    val latitude: Double,
    val longitude: Double
)