package com.reminora.android.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import com.reminora.android.ui.auth.AuthScreen
import com.reminora.android.ui.auth.AuthViewModel
import com.reminora.android.ui.home.HomeScreen

@Composable
fun ReminoraApp(
    navController: NavHostController,
    authViewModel: AuthViewModel = hiltViewModel()
) {
    val authState = authViewModel.authState
    
    Scaffold(
        modifier = Modifier.fillMaxSize()
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            NavHost(
                navController = navController,
                startDestination = if (authState.value.isAuthenticated) "home" else "auth"
            ) {
                composable("auth") {
                    AuthScreen(
                        onAuthenticated = {
                            navController.navigate("home") {
                                popUpTo("auth") { inclusive = true }
                            }
                        }
                    )
                }
                
                composable("home") {
                    HomeScreen(
                        onSignOut = {
                            navController.navigate("auth") {
                                popUpTo("home") { inclusive = true }
                            }
                        }
                    )
                }
            }
        }
    }
}