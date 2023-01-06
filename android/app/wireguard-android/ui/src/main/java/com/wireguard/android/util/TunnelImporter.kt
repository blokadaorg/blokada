/*
 * Copyright © 2017-2021 WireGuard LLC. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

package com.wireguard.android.util

import android.app.Application
import android.content.ContentResolver
import android.net.Uri
import android.provider.OpenableColumns
import android.util.Log
import androidx.fragment.app.FragmentManager
import com.wireguard.config.Config
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.withContext
import org.blokada.R
import org.pcap4j.util.IpV4Helper.fragment
import ui.MainApplication
import ui.MainApplication.Companion.getTunnelManager
import java.io.BufferedReader
import java.io.ByteArrayInputStream
import java.io.InputStreamReader
import java.nio.charset.StandardCharsets
import java.util.ArrayList
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream

//object TunnelImporter {
//    suspend fun importTunnel(contentResolver: ContentResolver, uri: Uri, messageCallback: (CharSequence) -> Unit) = withContext(Dispatchers.IO) {
//        val context = MainApplication.get().applicationContext
//        val futureTunnels = ArrayList<Deferred<ObservableTunnel>>()
//        val throwables = ArrayList<Throwable>()
//        try {
//            val columns = arrayOf(OpenableColumns.DISPLAY_NAME)
//            var name = ""
//            contentResolver.query(uri, columns, null, null, null)?.use { cursor ->
//                if (cursor.moveToFirst() && !cursor.isNull(0)) {
//                    name = cursor.getString(0)
//                }
//            }
//            if (name.isEmpty()) {
//                name = Uri.decode(uri.lastPathSegment)
//            }
//            var idx = name.lastIndexOf('/')
//            if (idx >= 0) {
//                require(idx < name.length - 1) { context.getString(R.string.illegal_filename_error, name) }
//                name = name.substring(idx + 1)
//            }
//            val isZip = name.lowercase().endsWith(".zip")
//            if (name.lowercase().endsWith(".conf")) {
//                name = name.substring(0, name.length - ".conf".length)
//            } else {
//                require(isZip) { context.getString(R.string.bad_extension_error) }
//            }
//
//            if (isZip) {
//                ZipInputStream(contentResolver.openInputStream(uri)).use { zip ->
//                    val reader = BufferedReader(InputStreamReader(zip, StandardCharsets.UTF_8))
//                    var entry: ZipEntry?
//                    while (true) {
//                        entry = zip.nextEntry ?: break
//                        name = entry.name
//                        idx = name.lastIndexOf('/')
//                        if (idx >= 0) {
//                            if (idx >= name.length - 1) {
//                                continue
//                            }
//                            name = name.substring(name.lastIndexOf('/') + 1)
//                        }
//                        if (name.lowercase().endsWith(".conf")) {
//                            name = name.substring(0, name.length - ".conf".length)
//                        } else {
//                            continue
//                        }
//                        try {
//                            Config.parse(reader)
//                        } catch (e: Throwable) {
//                            throwables.add(e)
//                            null
//                        }?.let {
//                            val nameCopy = name
//                            futureTunnels.add(async(SupervisorJob()) { Application.getTunnelManager().create(nameCopy, it) })
//                        }
//                    }
//                }
//            } else {
//                futureTunnels.add(async(SupervisorJob()) { Application.getTunnelManager().create(name, Config.parse(contentResolver.openInputStream(uri)!!)) })
//            }
//
//            if (futureTunnels.isEmpty()) {
//                if (throwables.size == 1) {
//                    throw throwables[0]
//                } else {
//                    require(throwables.isNotEmpty()) { context.getString(R.string.no_configs_error) }
//                }
//            }
//            val tunnels = futureTunnels.mapNotNull {
//                try {
//                    it.await()
//                } catch (e: Throwable) {
//                    throwables.add(e)
//                    null
//                }
//            }
//            withContext(Dispatchers.Main.immediate) { onTunnelImportFinished(tunnels, throwables, messageCallback) }
//        } catch (e: Throwable) {
//            withContext(Dispatchers.Main.immediate) { onTunnelImportFinished(emptyList(), listOf(e), messageCallback) }
//        }
//    }
//
//    fun importTunnel(parentFragmentManager: FragmentManager, configText: String, messageCallback: (CharSequence) -> Unit) {
//        try {
//            // Ensure the config text is parseable before proceeding…
//            Config.parse(ByteArrayInputStream(configText.toByteArray(StandardCharsets.UTF_8)))
//
//            // Config text is valid, now create the tunnel…
//            ConfigNamingDialogFragment.newInstance(configText).show(parentFragmentManager, null)
//        } catch (e: Throwable) {
//            onTunnelImportFinished(emptyList(), listOf<Throwable>(e), messageCallback)
//        }
//    }
//
//    private fun onTunnelImportFinished(tunnels: List<ObservableTunnel>, throwables: Collection<Throwable>, messageCallback: (CharSequence) -> Unit) {
//        val context = Application.get().applicationContext
//        var message = ""
//        for (throwable in throwables) {
//            val error = ErrorMessages[throwable]
//            message = context.getString(R.string.import_error, error)
//            Log.e(TAG, message, throwable)
//        }
//        if (tunnels.size == 1 && throwables.isEmpty())
//            message = context.getString(R.string.import_success, tunnels[0].name)
//        else if (tunnels.isEmpty() && throwables.size == 1)
//        else if (throwables.isEmpty())
//            message = context.resources.getQuantityString(R.plurals.import_total_success,
//                    tunnels.size, tunnels.size)
//        else if (!throwables.isEmpty())
//            message = context.resources.getQuantityString(R.plurals.import_partial_success,
//                    tunnels.size + throwables.size,
//                    tunnels.size, tunnels.size + throwables.size)
//
//        messageCallback(message)
//    }
//
//    private const val TAG = "WireGuard/TunnelImporter"
//}