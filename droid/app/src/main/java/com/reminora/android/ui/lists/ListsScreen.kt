package com.reminora.android.ui.lists

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ListsScreen(
    listsViewModel: ListsViewModel = hiltViewModel()
) {
    val listsState by listsViewModel.listsState.collectAsState()
    var showCreateDialog by remember { mutableStateOf(false) }
    
    // Quick List menu states
    var showQuickListMenu by remember { mutableStateOf(false) }
    var showCreateListFromQuickDialog by remember { mutableStateOf(false) }
    var showAddToListDialog by remember { mutableStateOf(false) }
    var showClearQuickDialog by remember { mutableStateOf(false) }
    var selectedQuickList by remember { mutableStateOf<SavedList?>(null) }
    
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text(
                    text = "My Lists",
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = "Organize your saved places",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            
            FloatingActionButton(
                onClick = { showCreateDialog = true },
                modifier = Modifier.size(48.dp)
            ) {
                Icon(Icons.Default.Add, contentDescription = "Create list")
            }
        }
        
        Spacer(modifier = Modifier.height(24.dp))
        
        // Lists
        when {
            listsState.isLoading -> {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator()
                }
            }
            
            listsState.lists.isEmpty() -> {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Icon(
                            Icons.Default.List,
                            contentDescription = "No lists",
                            modifier = Modifier.size(64.dp),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        Text(
                            text = "No lists yet",
                            style = MaterialTheme.typography.headlineSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Text(
                            text = "Create your first list to organize places",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        Button(onClick = { showCreateDialog = true }) {
                            Text("Create List")
                        }
                    }
                }
            }
            
            else -> {
                LazyColumn(
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    items(listsState.lists) { list ->
                        ListItem(
                            list = list,
                            onClick = { listsViewModel.selectList(list) },
                            onMenuClick = if (listsViewModel.isQuickList(list)) {
                                { 
                                    selectedQuickList = list
                                    showQuickListMenu = true
                                }
                            } else null
                        )
                    }
                }
            }
        }
    }
    
    // Create list dialog
    if (showCreateDialog) {
        CreateListDialog(
            onDismiss = { showCreateDialog = false },
            onCreateList = { name ->
                listsViewModel.createList(name)
                showCreateDialog = false
            }
        )
    }
    
    // Quick List menu
    if (showQuickListMenu && selectedQuickList != null) {
        QuickListMenuDialog(
            onDismiss = { 
                showQuickListMenu = false
                selectedQuickList = null
            },
            onCreateList = {
                showQuickListMenu = false
                showCreateListFromQuickDialog = true
            },
            onAddToList = {
                showQuickListMenu = false
                showAddToListDialog = true
            },
            onClearQuick = {
                showQuickListMenu = false
                showClearQuickDialog = true
            }
        )
    }
    
    // Create list from Quick List dialog
    if (showCreateListFromQuickDialog) {
        CreateListDialog(
            title = "Create List from Quick List",
            description = "Enter a name for the new list. All items from Quick List will be moved to this list.",
            onDismiss = { showCreateListFromQuickDialog = false },
            onCreateList = { name ->
                listsViewModel.createListFromQuickList(name)
                showCreateListFromQuickDialog = false
            }
        )
    }
    
    // Add to existing list dialog
    if (showAddToListDialog) {
        AddToListDialog(
            lists = listsState.lists.filter { !listsViewModel.isQuickList(it) },
            onDismiss = { showAddToListDialog = false },
            onListSelected = { listId ->
                listsViewModel.moveQuickListToExistingList(listId)
                showAddToListDialog = false
            }
        )
    }
    
    // Clear Quick List confirmation dialog
    if (showClearQuickDialog) {
        ClearQuickListDialog(
            onDismiss = { showClearQuickDialog = false },
            onConfirm = {
                listsViewModel.clearQuickList()
                showClearQuickDialog = false
            }
        )
    }
}

@Composable
fun ListItem(
    list: SavedList,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    onMenuClick: (() -> Unit)? = null
) {
    Card(
        modifier = modifier
            .fillMaxWidth()
            .clickable { onClick() },
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        shape = RoundedCornerShape(12.dp)
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // List icon
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(
                        when (list.name) {
                            "Shared" -> Color(0xFF4CAF50)
                            "Quick" -> Color(0xFF2196F3)
                            else -> MaterialTheme.colorScheme.primaryContainer
                        }
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    if (list.name == "Shared") Icons.Default.Share else Icons.Default.List,
                    contentDescription = "List",
                    tint = if (list.name == "Shared" || list.name == "Quick") 
                        Color.White else MaterialTheme.colorScheme.onPrimaryContainer
                )
            }
            
            Spacer(modifier = Modifier.width(16.dp))
            
            // Content
            Column(
                modifier = Modifier.weight(1f)
            ) {
                Text(
                    text = list.name,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )
                Text(
                    text = "${list.itemCount} places",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            
            // Special badges for system lists or menu button
            if (list.name == "Shared" || list.name == "Quick") {
                if (onMenuClick != null && list.name == "Quick") {
                    IconButton(
                        onClick = onMenuClick,
                        modifier = Modifier.size(40.dp)
                    ) {
                        Icon(
                            Icons.Default.MoreVert,
                            contentDescription = "Quick List Menu",
                            tint = MaterialTheme.colorScheme.onSurface
                        )
                    }
                } else {
                    Surface(
                        color = MaterialTheme.colorScheme.secondary.copy(alpha = 0.1f),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text(
                            text = "System",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.secondary,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun CreateListDialog(
    onDismiss: () -> Unit,
    onCreateList: (String) -> Unit,
    title: String = "Create New List",
    description: String = "Enter a name for your new list:"
) {
    var listName by remember { mutableStateOf("") }
    
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = {
            Column {
                Text(description)
                Spacer(modifier = Modifier.height(8.dp))
                OutlinedTextField(
                    value = listName,
                    onValueChange = { listName = it },
                    placeholder = { Text("List name") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
            }
        },
        confirmButton = {
            TextButton(
                onClick = { onCreateList(listName) },
                enabled = listName.isNotBlank()
            ) {
                Text("Create")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}

@Composable
fun QuickListMenuDialog(
    onDismiss: () -> Unit,
    onCreateList: () -> Unit,
    onAddToList: () -> Unit,
    onClearQuick: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Quick List Actions") },
        text = {
            Column {
                TextButton(
                    onClick = onCreateList,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(Icons.Default.Add, contentDescription = null)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Create List")
                    }
                }
                
                TextButton(
                    onClick = onAddToList,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(Icons.Default.List, contentDescription = null)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Add to List")
                    }
                }
                
                TextButton(
                    onClick = onClearQuick,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(Icons.Default.Clear, contentDescription = null)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Clear Quick")
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}

@Composable
fun AddToListDialog(
    lists: List<SavedList>,
    onDismiss: () -> Unit,
    onListSelected: (String) -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Add to Existing List") },
        text = {
            LazyColumn {
                items(lists) { list ->
                    TextButton(
                        onClick = { onListSelected(list.id) },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(Icons.Default.List, contentDescription = null)
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(list.name)
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}

@Composable
fun ClearQuickListDialog(
    onDismiss: () -> Unit,
    onConfirm: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Clear Quick List") },
        text = {
            Text("Are you sure you want to clear all items from Quick List? This action cannot be undone.")
        },
        confirmButton = {
            TextButton(
                onClick = onConfirm,
                colors = ButtonDefaults.textButtonColors(
                    contentColor = MaterialTheme.colorScheme.error
                )
            ) {
                Text("Clear")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}

// Data models
data class SavedList(
    val id: String,
    val name: String,
    val itemCount: Int,
    val createdAt: Long
)