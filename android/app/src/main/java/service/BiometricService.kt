/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2022 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package service

import android.content.Context
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_WEAK
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.suspendCancellableCoroutine
import model.BlokadaException
import org.blokada.R
import kotlin.coroutines.resumeWithException

object BiometricService {
    private var ongoingPrompt: CancellableContinuation<BiometricPrompt.AuthenticationResult>? = null
        @Synchronized set
        @Synchronized get

    suspend fun auth(ctx: Fragment): BiometricPrompt.AuthenticationResult {
        val executor = ContextCompat.getMainExecutor(ctx.requireContext())

        val callback = object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationError(errorCode: Int,
                                               errString: CharSequence) {
                super.onAuthenticationError(errorCode, errString)
                ongoingPrompt?.resumeWithException(Exception("biometric: error: $errorCode: $errString"))
                ongoingPrompt = null
            }

            override fun onAuthenticationSucceeded(
                result: BiometricPrompt.AuthenticationResult) {
                super.onAuthenticationSucceeded(result)
                ongoingPrompt?.resume(result, {})
                ongoingPrompt = null
            }

            override fun onAuthenticationFailed() {
                super.onAuthenticationFailed()
                ongoingPrompt?.resumeWithException(BlokadaException("biometric: failed: unknown"))
                ongoingPrompt = null
            }
        }

        val biometricPrompt = BiometricPrompt(ctx, executor, callback)

        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle(ctx.getString(R.string.account_label_id))
            .setSubtitle(ctx.getString(R.string.universal_status_confirm))
            .setNegativeButtonText(ctx.getString(R.string.universal_action_cancel))
            .setAllowedAuthenticators(BIOMETRIC_STRONG or BIOMETRIC_WEAK)
            .build()

        return suspendCancellableCoroutine { cont ->
            ongoingPrompt = cont
            biometricPrompt.authenticate(promptInfo)
        }
    }

    private fun hasBiometricCapability(ctx: Context): Int {
        val biometricManager = BiometricManager.from(ctx)
        return biometricManager.canAuthenticate()
    }

    fun isBiometricReady(context: Context) =
        hasBiometricCapability(context) == BiometricManager.BIOMETRIC_SUCCESS

}