package com.reminora.android.ui.profile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.reminora.android.DebugConfig
import com.reminora.android.data.repository.AuthRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class ProfileViewModel @Inject constructor(
    private val authRepository: AuthRepository
) : ViewModel() {
    
    private val _profileState = MutableStateFlow(ProfileState())
    val profileState: StateFlow<ProfileState> = _profileState.asStateFlow()
    
    init {
        loadProfile()
    }
    
    private fun loadProfile() {
        viewModelScope.launch {
            // TODO: Get current user from auth repository
            // For now, use debug user data
            _profileState.value = ProfileState(
                displayName = DebugConfig.MOCK_USER_NAME,
                handle = DebugConfig.MOCK_USER_HANDLE,
                email = DebugConfig.MOCK_USER_EMAIL,
                placesCount = 0, // TODO: Get actual count from repository
                listsCount = 2, // Shared and Quick lists
                sharedCount = 0
            )
        }
    }
}

data class ProfileState(
    val displayName: String = "",
    val handle: String = "",
    val email: String = "",
    val placesCount: Int = 0,
    val listsCount: Int = 0,
    val sharedCount: Int = 0,
    val isLoading: Boolean = false
)