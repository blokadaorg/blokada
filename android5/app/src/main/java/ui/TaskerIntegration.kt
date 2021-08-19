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

import android.content.Context
import android.os.Bundle
import android.widget.Button
import android.widget.EditText
import android.widget.Toast
import com.twofortyfouram.locale.sdk.client.receiver.AbstractPluginSettingReceiver
import com.twofortyfouram.locale.sdk.client.ui.activity.AbstractPluginActivity
import org.blokada.R
import ui.utils.cause
import utils.Logger

private const val EVENT_KEY_COMMAND = "command"

class TaskerActivity : AbstractPluginActivity() {

    private lateinit var command: EditText

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_tasker)
        command = findViewById(R.id.tasker_command)

        findViewById<Button>(R.id.tasker_done).setOnClickListener { finish() }
    }

    override fun onPostCreateWithPreviousResult(previousBundle: Bundle, previousBlurp: String) {
        when {
            previousBundle.containsKey(EVENT_KEY_COMMAND) -> {
                command.setText(previousBundle.getString(EVENT_KEY_COMMAND))
            }
        }
    }

    override fun getResultBundle() = Bundle().apply {
        putString(EVENT_KEY_COMMAND, command.text.toString())
    }

    override fun isBundleValid(bundle: Bundle) = bundle.containsKey(EVENT_KEY_COMMAND)

    override fun getResultBlurb(bundle: Bundle): String {
        val command = bundle.getString(EVENT_KEY_COMMAND)
        return "%s: %s".format("Blokada", command)
    }

}


class TaskerReceiver : AbstractPluginSettingReceiver() {

    private val log = Logger("TaskerReceiver")

    init {
        log.v("TaskerReceiver created")
    }

    override fun isAsync(): Boolean {
        return false
    }

    override fun firePluginSetting(ctx: Context, bundle: Bundle) {
        when {
            bundle.containsKey(EVENT_KEY_COMMAND) -> cmd(ctx, bundle.getString(EVENT_KEY_COMMAND)!!)
            else -> log.e("unknown app intent")
        }
    }

    private fun cmd(ctx: Context, command: String) {
        try {
            log.v("Executing command from Tasker: $command")
            val intent = getIntentForCommand(command)
            ctx.startService(intent)
            Toast.makeText(ctx, "Tasker: Blokada ($command)", Toast.LENGTH_SHORT).show()
        } catch (ex: Exception) {
            log.e("Invalid switch app intent".cause(ex))
        }
    }

    override fun isBundleValid(bundle: Bundle) = bundle.containsKey(EVENT_KEY_COMMAND)

}