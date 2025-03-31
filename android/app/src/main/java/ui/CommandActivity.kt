/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2021 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package ui

import android.app.IntentService
import android.content.Intent
import android.content.Intent.ACTION_VIEW
import android.net.Uri
import android.os.Bundle
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import binding.AppBinding
import binding.CommandBinding
import channel.command.CommandName
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import model.BlokadaException
import service.ContextService
import service.NotificationService
import utils.cause
import utils.ExecutingCommandNotification
import utils.Logger
import java.util.Locale

enum class Command {
    OFF, ON, FAMILY_LINK
}

private typealias Param = String

class CommandActivity : AppCompatActivity() {
    private val app by lazy { AppBinding }
    private val log = Logger("Command")
    private val cmd by lazy { CommandBinding }
    private val scope by lazy { CoroutineScope(Dispatchers.Main) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        interpretCommand(intent.data.toString())?.let {
            val (cmd, param) = it
            log.w("Received command: $cmd")
            try {
                execute(cmd, param)
                log.v("Command executed successfully")
            } catch (ex: Exception) {
                log.e("Could not execute command".cause(ex))
            }
        } ?: run {
            log.e("Received unknown command: ${intent.data}")
        }

        finish()
    }

    private fun execute(command: Command, param: Param?) {
        when (command) {
            Command.OFF -> {
                scope.launch { app.pause() }
            }

            Command.ON -> {
                scope.launch { app.unpause() }
            }

            Command.FAMILY_LINK -> {
                // Now bring the MainActivity to the foreground
                val intent = Intent(this, MainActivity::class.java).apply {
                    flags =
                        Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
                startActivity(intent)

                if (param?.isBlank() != false) {
                    throw BlokadaException("Family link param not provided")
                }

                Toast.makeText(this, "Linking device ...", Toast.LENGTH_LONG).show()

                scope.launch {
                    cmd.execute(CommandName.FAMILYLINK, param)
                }
            }
        }
    }

    private fun interpretCommand(input: String): Pair<Command, Param?>? {
        return when {
            // Family link command
            input.startsWith("https://go.blokada.org/family/link_device") -> {
                input.replace("https://go.blokada.org/family/link_device", "")
                    .replace("?token=", "")
                    .trimEnd('/')
                    .let {
                        try {
                            Command.FAMILY_LINK to it
                        } catch (ex: Exception) {
                            null
                        }
                    }
            }

            else -> null
        }
    }
}