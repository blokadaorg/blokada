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

package service

import channel.command.CommandName
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingService
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import utils.Logger
import utils.cause
import binding.CommandBinding

object FcmService {

    fun setup() {
        // Only invoked for v6 flavor (source-set scoped)
        try {
            FirebaseApp.initializeApp(ContextService.requireContext())
        } catch (ex: Exception) {
            Logger.e("FcmService", "Failed to init Firebase".cause(ex))
            return
        }

        FirebaseMessaging.getInstance().token
            .addOnSuccessListener { token ->
                if (token.isNullOrEmpty()) {
                    Logger.w("FcmService", "FCM registration token is empty")
                    return@addOnSuccessListener
                }
                logToken(token)
            }
            .addOnFailureListener {
                Logger.w("FcmService", "Failed to fetch FCM token: ${it.message}")
            }
    }

    internal fun logToken(token: String) {
        GlobalScope.launch {
            CommandBinding.execute(CommandName.FCMNOTIFICATIONTOKEN, token)
        }
    }
}

class FcmMessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        if (token.isNotEmpty()) {
            FcmService.logToken(token)
        } else {
            Logger.w("FcmService", "FCM registration token is empty (refresh)")
        }
    }

    override fun onMessageReceived(message: com.google.firebase.messaging.RemoteMessage) {
        val data = message.data
        if (data.isEmpty()) {
            Logger.w("FcmService", "FCM message has no data payload")
            return
        }

        val json = org.json.JSONObject(data as Map<*, *>).toString()
        GlobalScope.launch {
            CommandBinding.execute(CommandName.FCMEVENT, json)
        }
    }
}
