package com.reminora.android.data.model

import kotlinx.serialization.Serializable

@Serializable
data class PlaceAddress(
    val coordinates: PlaceCoordinates,
    val country: String? = null,
    val city: String? = null,
    val phone: String? = null,
    val website: String? = null,
    val fullAddress: String? = null
)

@Serializable
data class PlaceCoordinates(
    val latitude: Double,
    val longitude: Double
)