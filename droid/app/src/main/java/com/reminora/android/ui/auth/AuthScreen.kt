package com.reminora.android.ui.auth

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.reminora.android.DebugConfig

@Composable
fun AuthScreen(
    onAuthenticated: () -> Unit,
    authViewModel: AuthViewModel = hiltViewModel()
) {
    val authState by authViewModel.authState.collectAsState()
    
    // Handle authentication success
    LaunchedEffect(authState) {
        if (authState.isAuthenticated) {
            onAuthenticated()
        }
    }
    
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                brush = Brush.linearGradient(
                    colors = listOf(
                        Color(0xFF4A90E2),
                        Color(0xFF8E44AD)
                    )
                )
            )
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            // App Logo and Title
            Icon(
                painter = painterResource(id = android.R.drawable.ic_menu_camera),
                contentDescription = "Reminora Logo",
                tint = Color.White,
                modifier = Modifier.size(80.dp)
            )
            
            Spacer(modifier = Modifier.height(16.dp))
            
            Text(
                text = "Reminora",
                color = Color.White,
                fontSize = 32.sp,
                fontWeight = FontWeight.Bold
            )
            
            Spacer(modifier = Modifier.height(8.dp))
            
            Text(
                text = "Share moments, follow friends",
                color = Color.White.copy(alpha = 0.9f),
                fontSize = 18.sp
            )
            
            Spacer(modifier = Modifier.height(48.dp))
            
            // Loading indicator
            if (authState.isLoading) {
                CircularProgressIndicator(
                    color = Color.White,
                    modifier = Modifier.size(48.dp)
                )
            } else {
                // Sign in options
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    // Google Sign In
                    Button(
                        onClick = { authViewModel.signInWithGoogle() },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(50.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = Color.White,
                            contentColor = Color.Black
                        ),
                        shape = RoundedCornerShape(25.dp)
                    ) {
                        Icon(
                            painter = painterResource(id = android.R.drawable.ic_dialog_email),
                            contentDescription = "Google",
                            modifier = Modifier.size(20.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = "Continue with Google",
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                    
                    // GitHub Sign In (placeholder)
                    Button(
                        onClick = { /* TODO: GitHub OAuth */ },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(50.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = Color.Black,
                            contentColor = Color.White
                        ),
                        shape = RoundedCornerShape(25.dp)
                    ) {
                        Icon(
                            painter = painterResource(id = android.R.drawable.ic_dialog_info),
                            contentDescription = "GitHub",
                            modifier = Modifier.size(20.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = "Continue with GitHub",
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                    
                    // Debug Skip Authentication button (only in debug builds)
                    if (DebugConfig.ALLOW_SKIP_AUTH) {
                        Spacer(modifier = Modifier.height(8.dp))
                        
                        OutlinedButton(
                            onClick = { authViewModel.skipAuthentication() },
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(40.dp),
                            colors = ButtonDefaults.outlinedButtonColors(
                                contentColor = Color.White.copy(alpha = 0.9f)
                            ),
                            border = androidx.compose.foundation.BorderStroke(
                                1.dp, 
                                Color.White.copy(alpha = 0.5f)
                            ),
                            shape = RoundedCornerShape(20.dp)
                        ) {
                            Icon(
                                painter = painterResource(id = android.R.drawable.ic_media_play),
                                contentDescription = "Skip Auth",
                                modifier = Modifier.size(16.dp)
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "Skip Authentication (Debug)",
                                fontSize = 14.sp,
                                fontWeight = FontWeight.Medium
                            )
                        }
                    }
                }
            }
            
            Spacer(modifier = Modifier.height(48.dp))
            
            // Terms and Privacy
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    text = "New to Reminora? We'll create your account automatically.",
                    color = Color.White.copy(alpha = 0.9f),
                    fontSize = 12.sp,
                    textAlign = TextAlign.Center
                )
                
                Text(
                    text = "By continuing, you agree to our Terms of Service and Privacy Policy",
                    color = Color.White.copy(alpha = 0.8f),
                    fontSize = 12.sp,
                    textAlign = TextAlign.Center
                )
            }
        }
        
        // Error handling
        authState.error?.let { error ->
            LaunchedEffect(error) {
                // Show error snackbar or handle error
            }
        }
    }
}