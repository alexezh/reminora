package com.reminora.android.ui.photos

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
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
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
fun SwipePhotoView(
    stack: PhotoStack,
    initialIndex: Int = 0,
    onDismiss: () -> Unit,
    onPin: (Photo) -> Unit,
    onShare: (Photo) -> Unit,
    onLike: (Photo) -> Unit,
    onDislike: (Photo) -> Unit,
    getPhotoPreference: (Photo) -> PhotoPreferenceType,
    isPhotoInQuickList: ((Photo) -> Boolean)? = null,
    onQuickListToggle: ((Photo) -> Unit)? = null
) {
    val pagerState = rememberPagerState(
        initialPage = initialIndex,
        pageCount = { stack.photos.size }
    )
    val density = LocalDensity.current
    var dragOffsetY by remember { mutableFloatStateOf(0f) }
    val scope = rememberCoroutineScope()
    
    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(
            usePlatformDefaultWidth = false,
            decorFitsSystemWindows = false
        )
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black)
                .offset(y = with(density) { dragOffsetY.toDp() })
                .pointerInput(Unit) {
                    detectDragGestures(
                        onDragEnd = {
                            if (dragOffsetY > 150.dp.toPx()) {
                                onDismiss()
                            } else {
                                dragOffsetY = 0f
                            }
                        }
                    ) { _, dragAmount ->
                        if (dragAmount.y > 0) {
                            dragOffsetY += dragAmount.y
                        }
                    }
                }
        ) {
            Column(
                modifier = Modifier.fillMaxSize()
            ) {
                // Top toolbar
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp)
                        .statusBarsPadding(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    IconButton(
                        onClick = onDismiss
                    ) {
                        Icon(
                            Icons.Default.Close,
                            contentDescription = "Close",
                            tint = Color.White,
                            modifier = Modifier
                                .background(
                                    Color.Black.copy(alpha = 0.6f),
                                    CircleShape
                                )
                                .padding(8.dp)
                        )
                    }
                    
                    Spacer(modifier = Modifier.weight(1f))
                    
                    // Action buttons
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        val currentPhoto = stack.photos[pagerState.currentPage]
                        val currentPreference = getPhotoPreference(currentPhoto)
                        
                        IconButton(
                            onClick = { 
                                onDislike(currentPhoto)
                                // Auto-dismiss after dislike
                                scope.launch {
                                    kotlinx.coroutines.delay(300)
                                    onDismiss()
                                }
                            }
                        ) {
                            Icon(
                                if (currentPreference == PhotoPreferenceType.DISLIKE) {
                                    Icons.Default.Cancel
                                } else {
                                    Icons.Default.Cancel
                                },
                                contentDescription = "Dislike",
                                tint = if (currentPreference == PhotoPreferenceType.DISLIKE) Color.Red else Color.White
                            )
                        }
                        
                        IconButton(
                            onClick = { onLike(currentPhoto) }
                        ) {
                            Icon(
                                if (currentPreference == PhotoPreferenceType.LIKE) {
                                    Icons.Default.Favorite
                                } else {
                                    Icons.Default.FavoriteBorder
                                },
                                contentDescription = "Like",
                                tint = Color.White
                            )
                        }
                        
                        IconButton(
                            onClick = {
                                val currentPhoto = stack.photos[pagerState.currentPage]
                                onShare(currentPhoto)
                            }
                        ) {
                            Icon(
                                Icons.Default.Share,
                                contentDescription = "Share",
                                tint = Color.White
                            )
                        }
                        
                        Button(
                            onClick = {
                                val currentPhoto = stack.photos[pagerState.currentPage]
                                onPin(currentPhoto)
                            },
                            colors = ButtonDefaults.buttonColors(
                                containerColor = MaterialTheme.colorScheme.primary
                            ),
                            modifier = Modifier.height(36.dp)
                        ) {
                            Text("Pin")
                        }
                    }
                }
                
                // Photo pager
                HorizontalPager(
                    state = pagerState,
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f)
                ) { page ->
                    val photo = stack.photos[page]
                    PhotoView(
                        photo = photo,
                        isPhotoInQuickList = isPhotoInQuickList,
                        onQuickListToggle = onQuickListToggle
                    )
                }
                
                // Navigation dots for stacks
                if (stack.isStack) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        horizontalArrangement = Arrangement.Center
                    ) {
                        repeat(stack.photos.size) { index ->
                            Box(
                                modifier = Modifier
                                    .size(8.dp)
                                    .clip(CircleShape)
                                    .background(
                                        if (index == pagerState.currentPage) {
                                            Color.White
                                        } else {
                                            Color.White.copy(alpha = 0.4f)
                                        }
                                    )
                            )
                            if (index < stack.photos.size - 1) {
                                Spacer(modifier = Modifier.width(8.dp))
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun PhotoView(
    photo: Photo,
    isPhotoInQuickList: ((Photo) -> Boolean)? = null,
    onQuickListToggle: ((Photo) -> Unit)? = null
) {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        // TODO: Load actual photo
        Card(
            modifier = Modifier
                .fillMaxWidth(0.9f)
                .aspectRatio(1f),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceVariant
            )
        ) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Icon(
                        Icons.Default.Photo,
                        contentDescription = null,
                        modifier = Modifier.size(64.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "Photo ${photo.id}",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
        
        // Quick List FAB (bottom-right)
        if (isPhotoInQuickList != null && onQuickListToggle != null) {
            val isInQuickList = isPhotoInQuickList(photo)
            FloatingActionButton(
                onClick = { onQuickListToggle(photo) },
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .padding(24.dp),
                containerColor = if (isInQuickList) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surface,
                contentColor = if (isInQuickList) Color.White else MaterialTheme.colorScheme.onSurface
            ) {
                Icon(
                    if (isInQuickList) Icons.Default.Check else Icons.Default.Add,
                    contentDescription = if (isInQuickList) "Remove from Quick List" else "Add to Quick List"
                )
            }
        }
    }
}