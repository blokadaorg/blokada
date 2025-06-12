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

import org.junit.Assert.*
import org.junit.Test

class AdaptyAttributeConverterTest {

    @Test
    fun `converts valid attributes correctly`() {
        val attributes =
                mapOf(
                        "feature_enabled" to true,
                        "user_level" to 5,
                        "score" to 99.5,
                        "username" to "john_doe"
                )

        val result = AdaptyAttributeConverter.convertToCustomAttributes(attributes)

        assertEquals(4, result.size)
        assertEquals("true", result["feature_enabled"])
        assertEquals("5", result["user_level"])
        assertEquals("99.5", result["score"])
        assertEquals("john_doe", result["username"])
    }

    @Test
    fun `filters out timestamp values`() {
        val attributes =
                mapOf(
                        "freemium" to true,
                        "freemium_youtube_until" to "2025-06-16T10:04:25.74971924Z",
                        "created_at" to "2025-01-01T00:00:00Z",
                        "valid_field" to "keep_this"
                )

        val result = AdaptyAttributeConverter.convertToCustomAttributes(attributes)

        assertEquals(2, result.size)
        assertTrue(result.containsKey("freemium"))
        assertTrue(result.containsKey("valid_field"))
        assertFalse(result.containsKey("freemium_youtube_until"))
        assertFalse(result.containsKey("created_at"))
        assertEquals("true", result["freemium"])
        assertEquals("keep_this", result["valid_field"])
    }

    @Test
    fun `converts false boolean to string`() {
        val attributes = mapOf("disabled" to false)

        val result = AdaptyAttributeConverter.convertToCustomAttributes(attributes)

        assertEquals(1, result.size)
        assertEquals("false", result["disabled"])
    }

    @Test
    fun `truncates long keys to 30 characters`() {
        val attributes =
                mapOf(
                        "this_is_a_very_long_key_name_that_exceeds_thirty_characters" to "value",
                        "short_key" to "value2"
                )

        val result = AdaptyAttributeConverter.convertToCustomAttributes(attributes)

        assertEquals(2, result.size)

        val truncatedKey = "this_is_a_very_long_key_name_t"
        assertTrue(result.containsKey(truncatedKey))
        assertEquals(30, truncatedKey.length)
        assertEquals("value", result[truncatedKey])
        assertEquals("value2", result["short_key"])
    }

    @Test
    fun `truncates long string values to 30 characters`() {
        val attributes =
                mapOf(
                        "description" to
                                "This is a very long description that definitely exceeds thirty characters"
                )

        val result = AdaptyAttributeConverter.convertToCustomAttributes(attributes)

        assertEquals(1, result.size)
        val truncatedValue = result["description"]
        assertEquals("This is a very long descriptio", truncatedValue)
        assertEquals(30, truncatedValue?.length)
    }

    @Test
    fun `filters out invalid keys`() {
        val attributes =
                mapOf(
                        "valid_key" to "value1",
                        "invalid key with spaces" to "value2",
                        "invalid@key#with\$symbols" to "value3",
                        "" to "value4", // empty key
                        "valid.key_with-chars123" to "value5"
                )

        val result = AdaptyAttributeConverter.convertToCustomAttributes(attributes)

        assertEquals(2, result.size)
        assertTrue(result.containsKey("valid_key"))
        assertTrue(result.containsKey("valid.key_with-chars123"))
        assertFalse(result.containsKey("invalid key with spaces"))
        assertFalse(result.containsKey("invalid@key#with\$symbols"))
        assertFalse(result.containsKey(""))
    }

    @Test
    fun `handles null and empty input`() {
        assertTrue(AdaptyAttributeConverter.convertToCustomAttributes(null).isEmpty())
        assertTrue(AdaptyAttributeConverter.convertToCustomAttributes(emptyMap()).isEmpty())
    }

    @Test
    fun `converts various number types to string`() {
        val attributes =
                mapOf("int_value" to 42, "double_value" to 3.14, "negative_int" to -10, "zero" to 0)

        val result = AdaptyAttributeConverter.convertToCustomAttributes(attributes)

        assertEquals(4, result.size)
        assertEquals("42", result["int_value"])
        assertEquals("3.14", result["double_value"])
        assertEquals("-10", result["negative_int"])
        assertEquals("0", result["zero"])
    }

    @Test
    fun `converts non-string non-number values to strings`() {
        val attributes =
                mapOf("list_value" to listOf(1, 2, 3), "object_value" to mapOf("nested" to "value"))

        val result = AdaptyAttributeConverter.convertToCustomAttributes(attributes)

        assertEquals(2, result.size)
        assertEquals("[1, 2, 3]", result["list_value"])
        assertTrue(result["object_value"]?.contains("nested") == true)
    }

    @Test
    fun `handles null values by excluding them`() {
        val attributes = mapOf("null_value" to null, "valid_value" to "test")

        val result = AdaptyAttributeConverter.convertToCustomAttributes(attributes)

        assertEquals(1, result.size)
        assertFalse(result.containsKey("null_value"))
        assertEquals("test", result["valid_value"])
    }

    @Test
    fun `real world freemium example`() {
        val attributes =
                mapOf(
                        "freemium" to true,
                        "freemium_youtube_until" to "2025-06-16T10:04:25.74971924Z",
                        "user_level" to 3,
                        "premium_user" to false
                )

        val result = AdaptyAttributeConverter.convertToCustomAttributes(attributes)

        assertEquals(3, result.size)
        assertEquals("true", result["freemium"])
        assertEquals("3", result["user_level"])
        assertEquals("false", result["premium_user"])
        // Timestamp should be filtered out
        assertFalse(result.containsKey("freemium_youtube_until"))
    }

    @Test
    fun `validates key character restrictions`() {
        val attributes =
                mapOf(
                        "valid_key123" to "value1",
                        "valid.key" to "value2",
                        "valid-key" to "value3",
                        "valid_key" to "value4",
                        "invalid key" to "should_be_filtered", // space
                        "invalid@key" to "should_be_filtered", // @
                        "invalid#key" to "should_be_filtered", // #
                        "invalid\$key" to "should_be_filtered", // $
                        "invalid/key" to "should_be_filtered" // /
                )

        val result = AdaptyAttributeConverter.convertToCustomAttributes(attributes)

        assertEquals(4, result.size)
        assertTrue(result.containsKey("valid_key123"))
        assertTrue(result.containsKey("valid.key"))
        assertTrue(result.containsKey("valid-key"))
        assertTrue(result.containsKey("valid_key"))
    }

    @Test
    fun `recognizes various timestamp formats`() {
        val attributes =
                mapOf(
                        "iso_timestamp1" to "2025-06-16T10:04:25.74971924Z",
                        "iso_timestamp2" to "2025-01-01T00:00:00+00:00",
                        "iso_timestamp3" to "2025-12-31T23:59:59-05:00",
                        "not_timestamp" to "2025-invalid-date",
                        "regular_string" to "normal_value"
                )

        val result = AdaptyAttributeConverter.convertToCustomAttributes(attributes)

        assertEquals(2, result.size)
        assertTrue(result.containsKey("not_timestamp"))
        assertTrue(result.containsKey("regular_string"))
        assertFalse(result.containsKey("iso_timestamp1"))
        assertFalse(result.containsKey("iso_timestamp2"))
        assertFalse(result.containsKey("iso_timestamp3"))
    }
}
