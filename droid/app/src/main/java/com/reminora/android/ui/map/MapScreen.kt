package com.reminora.android.ui.map

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
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
    pinBrowserViewModel: PinBrowserViewModel = hiltViewModel()
) {
    val uiState by pinBrowserViewModel.uiState.collectAsState()
    var searchText by remember { mutableStateOf("") }
    var selectedListId by remember { mutableStateOf("all") }
    
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
                        pinBrowserViewModel.searchPlaces(it)
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
                    
                    // Header with list combo box and add button
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        // List combo box
                        var expanded by remember { mutableStateOf(false) }
                        
                        ExposedDropdownMenuBox(
                            expanded = expanded,
                            onExpandedChange = { expanded = !expanded }
                        ) {
                            OutlinedTextField(
                                value = uiState.selectedListName,
                                onValueChange = {},
                                readOnly = true,
                                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
                                modifier = Modifier
                                    .menuAnchor()
                                    .width(150.dp),
                                textStyle = MaterialTheme.typography.bodyMedium
                            )
                            
                            ExposedDropdownMenu(
                                expanded = expanded,
                                onDismissRequest = { expanded = false }
                            ) {
                                uiState.availableLists.forEach { list ->
                                    DropdownMenuItem(
                                        text = { Text(list.name) },
                                        onClick = {
                                            selectedListId = list.id
                                            pinBrowserViewModel.selectList(list.id)
                                            expanded = false
                                        }
                                    )
                                }
                            }
                        }
                        
                        // Add button
                        Button(
                            onClick = { pinBrowserViewModel.showAddPhoto() },
                            modifier = Modifier.height(36.dp)
                        ) {
                            Icon(
                                Icons.Default.Add,
                                contentDescription = "Add",
                                modifier = Modifier.size(16.dp)
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Add")
                        }
                    }
                    
                    Spacer(modifier = Modifier.height(16.dp))
                    
                    // Places list
                    if (uiState.isLoading) {
                        Box(
                            modifier = Modifier.fillMaxSize(),
                            contentAlignment = Alignment.Center
                        ) {
                            CircularProgressIndicator()
                        }
                    } else if (uiState.filteredPlaces.isEmpty()) {
                        Box(
                            modifier = Modifier.fillMaxSize(),
                            contentAlignment = Alignment.Center
                        ) {
                            Column(
                                horizontalAlignment = Alignment.CenterHorizontally
                            ) {
                                Text(
                                    text = "No places found",
                                    style = MaterialTheme.typography.bodyLarge,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                                Text(
                                    text = "Try a different list or add some places",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    } else {
                        LazyColumn(
                            verticalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            items(uiState.filteredPlaces) { place ->
                                PlaceListItem(
                                    place = place,
                                    onClick = { pinBrowserViewModel.selectPlace(place) }
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}