package com.reminora.android.ui.map

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.reminora.android.ui.places.PlaceListItem

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MapScreen(
    MomentMainViewModel: MomentMainViewModel = hiltViewModel()
) {
    val mapState by MomentMainViewModel.mapState.collectAsState()
    var searchText by remember { mutableStateOf("") }
    
    Box(modifier = Modifier.fillMaxSize()) {
        // Map placeholder (we'll implement Google Maps later)
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color(0xFF90EE90)), // Light green to represent map
            contentAlignment = Alignment.Center
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Icon(
                    imageVector = Icons.Default.Search,
                    contentDescription = "Map",
                    modifier = Modifier.size(64.dp),
                    tint = Color.White.copy(alpha = 0.7f)
                )
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = "Map View",
                    color = Color.White.copy(alpha = 0.7f),
                    style = MaterialTheme.typography.headlineSmall
                )
                Text(
                    text = "Google Maps will be implemented here",
                    color = Color.White.copy(alpha = 0.5f),
                    style = MaterialTheme.typography.bodyMedium
                )
            }
        }
        
        // Sliding panel from bottom (like iOS)
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.BottomCenter)
        ) {
            // Search bar
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                elevation = CardDefaults.cardElevation(defaultElevation = 8.dp),
                shape = RoundedCornerShape(12.dp)
            ) {
                OutlinedTextField(
                    value = searchText,
                    onValueChange = { 
                        searchText = it
                        MomentMainViewModel.searchPlaces(it)
                    },
                    placeholder = { Text("Search places...") },
                    leadingIcon = { Icon(Icons.Default.Search, contentDescription = "Search") },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(8.dp),
                    shape = RoundedCornerShape(8.dp)
                )
            }
            
            // Places panel
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(300.dp),
                elevation = CardDefaults.cardElevation(defaultElevation = 8.dp),
                shape = RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp)
            ) {
                Column(
                    modifier = Modifier.padding(16.dp)
                ) {
                    // Panel handle
                    Box(
                        modifier = Modifier
                            .width(40.dp)
                            .height(4.dp)
                            .background(
                                Color.Gray.copy(alpha = 0.3f),
                                RoundedCornerShape(2.dp)
                            )
                            .align(Alignment.CenterHorizontally)
                    )
                    
                    Spacer(modifier = Modifier.height(16.dp))
                    
                    // Header
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "Saved Places",
                            style = MaterialTheme.typography.headlineSmall,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = "${mapState.places.size} places",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    
                    Spacer(modifier = Modifier.height(16.dp))
                    
                    // Places list
                    if (mapState.isLoading) {
                        Box(
                            modifier = Modifier.fillMaxSize(),
                            contentAlignment = Alignment.Center
                        ) {
                            CircularProgressIndicator()
                        }
                    } else if (mapState.places.isEmpty()) {
                        Box(
                            modifier = Modifier.fillMaxSize(),
                            contentAlignment = Alignment.Center
                        ) {
                            Column(
                                horizontalAlignment = Alignment.CenterHorizontally
                            ) {
                                Text(
                                    text = "No places saved yet",
                                    style = MaterialTheme.typography.bodyLarge,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                                Text(
                                    text = "Add some places to see them here",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    } else {
                        LazyColumn(
                            verticalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            items(mapState.places) { place ->
                                PlaceListItem(
                                    place = place,
                                    onClick = { MomentMainViewModel.selectPlace(place) }
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}