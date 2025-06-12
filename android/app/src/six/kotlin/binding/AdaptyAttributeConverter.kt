/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2025 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package binding

/**
 * Utility class for converting account attributes to Adapty's custom attributes format. This class
 * handles validation, filtering, and conversion of attributes according to Adapty's requirements
 * and limitations.
 */
object AdaptyAttributeConverter {

    /**
     * Converts a map of attributes to Adapty-compatible custom attributes. Filters out invalid keys
     * and timestamp values, and converts values to appropriate formats.
     *
     * @param attributes The raw attributes map from the account
     * @return A map of processed attributes ready for Adapty
     */
    fun convertToCustomAttributes(attributes: Map<String, Any?>?): Map<String, String> {
        if (attributes == null || attributes.isEmpty()) {
            return emptyMap()
        }

        val customAttrs = mutableMapOf<String, String>()

        for ((key, value) in attributes) {
            // Validate and truncate key
            val processedKey = validateAndTruncateKey(key)
            if (processedKey.isEmpty()) continue

            // Skip timestamp values
            if (shouldSkipValue(value)) continue

            // Convert value to Adapty-compatible format
            val processedValue = convertValueForAdapty(value)
            if (processedValue != null) {
                customAttrs[processedKey] = processedValue
            }
        }

        return customAttrs
    }

    /**
     * Validates key format and truncates to 30 characters. Keys can only contain letters, numbers,
     * dashes, periods, and underscores.
     */
    private fun validateAndTruncateKey(key: String): String {
        if (key.isEmpty()) return ""

        // Check if key contains only valid characters
        val validChars = Regex("^[a-zA-Z0-9\\-._]+$")
        if (!validChars.matches(key)) return ""

        // Truncate to 30 characters
        return if (key.length > 30) key.substring(0, 30) else key
    }

    /** Returns true for timestamp values that shouldn't be sent to Adapty. */
    private fun shouldSkipValue(value: Any?): Boolean {
        if (value == null) return false

        // Skip strings that look like ISO timestamps
        if (value is String && isTimestamp(value)) return true

        return false
    }

    /** Checks if a string looks like an ISO timestamp. */
    private fun isTimestamp(value: String): Boolean {
        return try {
            // Try to parse as ISO 8601 format
            java.time.OffsetDateTime.parse(value)
            true
        } catch (e: Exception) {
            false
        }
    }

    /** Converts values to Adapty-compatible format. */
    private fun convertValueForAdapty(value: Any?): String? {
        if (value == null) return null

        return when (value) {
            is Boolean -> if (value) "true" else "false"
            is String -> {
                // Truncate string to 30 characters
                if (value.length > 30) value.substring(0, 30) else value
            }
            else -> {
                // Convert other types to string and truncate
                val str = value.toString()
                if (str.length > 30) str.substring(0, 30) else str
            }
        }
    }
}
