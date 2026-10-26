/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2026 Blocka AB. All rights reserved.
 */

package service

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.core.content.edit
import com.google.android.gms.auth.blockstore.Blockstore
import com.google.android.gms.auth.blockstore.DeleteBytesRequest
import com.google.android.gms.auth.blockstore.RetrieveBytesRequest
import com.google.android.gms.auth.blockstore.StoreBytesData
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withTimeoutOrNull
import model.BlokadaException
import org.json.JSONObject
import utils.Logger
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Stores the values the app asks to keep secure (the account, the WireGuard
 * keypair, the Family link token, the lock PIN) encrypted with a key held in
 * the Android Keystore, instead of in plain SharedPreferences.
 *
 * The encrypted file is excluded from Auto Backup (see the backup rules in
 * res/xml): the key never leaves the device, so a restored copy could not be
 * read anyway. The account still has to come back on a reinstall or a new
 * phone, since the account ID is the only login, so values that are also
 * marked for backup get a copy in Block Store, which Google Play services
 * keeps across reinstalls. It goes to the cloud only when that copy would be
 * end-to-end encrypted, which needs a screen lock.
 */
object SecureStorageService {

    private val log = Logger("SecureStorage")
    private val context = ContextService

    private const val keyAlias = "blokada_secure_storage"
    private const val transformation = "AES/GCM/NoPadding"
    private const val ivSize = 12
    private const val tagBits = 128
    private const val blockStoreTimeoutMs = 5_000L

    private val prefs by lazy {
        context.requireContext().getSharedPreferences("secure", Context.MODE_PRIVATE)
    }

    private val blockStore by lazy { Blockstore.getClient(context.requireContext()) }

    fun save(key: String, value: String) {
        val cipher = Cipher.getInstance(transformation)
        cipher.init(Cipher.ENCRYPT_MODE, secretKey())
        val encrypted = cipher.iv + cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        val ok = prefs.edit().putString(key, Base64.encodeToString(encrypted, Base64.NO_WRAP))
            .commit()
        if (!ok) throw BlokadaException("Could not save $key to secure storage")
    }

    /**
     * Returns null when nothing is stored, or when it can no longer be
     * decrypted (the Keystore key was lost), so callers can fall back.
     */
    fun load(key: String): String? {
        val stored = prefs.getString(key, null) ?: return null
        return try {
            val bytes = Base64.decode(stored, Base64.NO_WRAP)
            val cipher = Cipher.getInstance(transformation)
            cipher.init(
                Cipher.DECRYPT_MODE, secretKey(),
                GCMParameterSpec(tagBits, bytes, 0, ivSize)
            )
            String(cipher.doFinal(bytes, ivSize, bytes.size - ivSize), Charsets.UTF_8)
        } catch (e: Exception) {
            log.w("Could not decrypt $key: ${e.message}")
            null
        }
    }

    fun delete(key: String) {
        prefs.edit(commit = true) { remove(key) }
    }

    private var cachedKey: SecretKey? = null

    // Synchronized so two first uses cannot each generate a key, which would
    // leave values encrypted with the first one unreadable.
    @Synchronized
    private fun secretKey(): SecretKey {
        cachedKey?.let { return it }
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (keyStore.getKey(keyAlias, null) as? SecretKey)?.let {
            cachedKey = it
            return it
        }

        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(
                keyAlias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build()
        )
        return generator.generateKey().also { cachedKey = it }
    }

    // Block Store keys allow a narrower character set than our persistence keys.
    private fun blockStoreKey(key: String) = key.replace(Regex("[^A-Za-z0-9_-]"), "_")

    // Set when a restore read failed, so Block Store may still hold an
    // account this install never saw. Kept in the secure file, which is local.
    private fun unverifiedKey(key: String) = "blockstore_unverified:$key"
    private fun isUnverified(key: String) = prefs.getBoolean(unverifiedKey(key), false)
    private fun setUnverified(key: String, unverified: Boolean, migrated: String? = null) {
        prefs.edit(commit = true) {
            if (unverified) putBoolean(unverifiedKey(key), true)
            else remove(unverifiedKey(key)).remove(migratedKey(key))
        }
        // Encrypted like the values: the account ID is the login.
        migrated?.let {
            try {
                save(migratedKey(key), it)
            } catch (e: Exception) {
                log.w("Could not save the moved $key: ${e.message}")
            }
        }
    }

    // The account ID moved from a plain copy while Block Store was unreadable.
    // That copy may be an old Auto Backup, so it being active does not let it
    // replace Block Store the way a restore or purchase does.
    private fun migratedKey(key: String) = "blockstore_migrated:$key"

    /**
     * Whether a write may replace what Block Store holds. After a failed
     * restore the app runs on a fallback account, and writing it would
     * destroy the one in Block Store, possibly a paid one. So the entry is
     * read again first. It is replaced when it is empty, the same account, or
     * not active, or when the new value is an active account (a restore or a
     * purchase the user made) other than one moved from a plain copy. Only an
     * inactive fallback or a moved plain copy is kept from replacing an active
     * account, which stays for a later reinstall to find.
     */
    private suspend fun mayReplace(key: String, value: String?): Boolean {
        if (!isUnverified(key)) return true
        val stored = try {
            retrieve(key)
        } catch (e: Exception) {
            log.w("Block Store still unreadable, keeping its $key: ${e.message}")
            return false
        }
        val newId = value?.let(::accountId)
        val migrated = load(migratedKey(key))
        val replace = stored == null || stored == value ||
            accountId(stored) != null && accountId(stored) == newId ||
            !isActiveAccount(stored) ||
            value != null && isActiveAccount(value) && (migrated == null || newId != migrated)
        if (replace) setUnverified(key, false)
        else log.w("Block Store holds an active $key from before, keeping it")
        return replace
    }

    private fun accountId(json: String) =
        try { JSONObject(json).optString("id").ifEmpty { null } } catch (e: Exception) { null }

    private fun isActiveAccount(json: String) =
        try { JSONObject(json).optBoolean("active", false) } catch (e: Exception) { false }

    suspend fun saveToBlockStore(key: String, value: String) {
        try {
            if (!mayReplace(key, value)) return
            val data = StoreBytesData.Builder()
                .setKey(blockStoreKey(key))
                .setBytes(value.toByteArray(Charsets.UTF_8))
                .setShouldBackupToCloud(isEndToEndEncryptionAvailable())
                .build()
            // No timeout: the queue stays ordered only if each write has
            // really finished before the next one starts.
            blockStore.storeBytes(data).await()
        } catch (e: Exception) {
            // Play services may be missing or outdated. The local copy still
            // works, only the restore on reinstall is lost.
            log.w("Could not save $key to Block Store: ${e.message}")
        }
    }

    // Without a screen lock the cloud copy would not be end-to-end encrypted,
    // so the entry stays on this device. A later save re-checks.
    private suspend fun isEndToEndEncryptionAvailable() = try {
        withTimeoutOrNull(blockStoreTimeoutMs) {
            blockStore.isEndToEndEncryptionAvailable().await()
        } ?: false
    } catch (e: Exception) {
        log.w("Could not check Block Store encryption: ${e.message}")
        false
    }

    /** Returns null when Block Store holds nothing, throws when it cannot tell. */
    private suspend fun retrieve(key: String): String? {
        val request = RetrieveBytesRequest.Builder()
            .setKeys(listOf(blockStoreKey(key)))
            .build()
        val response = withTimeoutOrNull(blockStoreTimeoutMs) {
            blockStore.retrieveBytes(request).await()
        } ?: throw BlokadaException("Timed out")
        return response.blockstoreDataMap[blockStoreKey(key)]?.bytes
            ?.toString(Charsets.UTF_8)
            ?.takeIf { it.isNotEmpty() }
    }

    /**
     * Returns null when Block Store holds nothing, or cannot be read after a
     * second try. The caller then creates a new account, or moves [plain]
     * over, so a failed read is remembered and keeps that account from
     * replacing the entry (mayReplace).
     */
    suspend fun loadFromBlockStore(key: String, plain: String? = null): String? {
        repeat(2) { attempt ->
            try {
                return retrieve(key)
            } catch (e: Exception) {
                log.w("Could not load $key from Block Store, attempt ${attempt + 1}: ${e.message}")
            }
        }
        log.w("Gave up loading $key from Block Store")
        setUnverified(key, true, plain?.let(::accountId))
        return null
    }

    suspend fun deleteFromBlockStore(key: String) {
        try {
            val request = DeleteBytesRequest.Builder()
                .setKeys(listOf(blockStoreKey(key)))
                .build()
            if (!mayReplace(key, null)) return
            blockStore.deleteBytes(request).await()
        } catch (e: Exception) {
            log.w("Could not delete $key from Block Store: ${e.message}")
        }
    }
}
