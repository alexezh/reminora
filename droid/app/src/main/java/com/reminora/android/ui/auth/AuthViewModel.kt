package com.reminora.android.ui.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.reminora.android.DebugConfig
import com.reminora.android.data.repository.AuthRepository
import com.reminora.android.data.model.User
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class AuthViewModel @Inject constructor(
    private val authRepository: AuthRepository
) : ViewModel() {
    
    private val _authState = MutableStateFlow(AuthState())
    val authState: StateFlow<AuthState> = _authState.asStateFlow()
    
    init {
        // Check if user is already authenticated
        viewModelScope.launch {
            _authState.value = _authState.value.copy(
                isAuthenticated = authRepository.isAuthenticated(),
                isLoading = false
            )
        }
    }
    
    fun signInWithGoogle() {
        viewModelScope.launch {
            _authState.value = _authState.value.copy(isLoading = true, error = null)
            
            try {
                val result = authRepository.signInWithGoogle()
                _authState.value = _authState.value.copy(
                    isAuthenticated = true,
                    isLoading = false,
                    user = result.user
                )
            } catch (e: Exception) {
                _authState.value = _authState.value.copy(
                    isLoading = false,
                    error = e.message
                )
            }
        }
    }
    
    fun skipAuthentication() {
        if (DebugConfig.ALLOW_SKIP_AUTH) {
            viewModelScope.launch {
                val mockUser = User(
                    id = DebugConfig.MOCK_USER_ID,
                    username = DebugConfig.MOCK_USER_HANDLE,
                    email = DebugConfig.MOCK_USER_EMAIL,
                    displayName = DebugConfig.MOCK_USER_NAME,
                    handle = DebugConfig.MOCK_USER_HANDLE,
                    avatarUrl = null
                )
                
                _authState.value = _authState.value.copy(
                    isAuthenticated = true,
                    isLoading = false,
                    user = mockUser,
                    error = null
                )
            }
        }
    }
    
    fun signOut() {
        viewModelScope.launch {
            try {
                authRepository.signOut()
                _authState.value = AuthState()
            } catch (e: Exception) {
                _authState.value = _authState.value.copy(error = e.message)
            }
        }
    }
}

data class AuthState(
    val isAuthenticated: Boolean = false,
    val isLoading: Boolean = true,
    val user: User? = null,
    val error: String? = null
)

