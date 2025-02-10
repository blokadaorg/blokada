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

import binding.BackNav
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import utils.Logger

object FlutterService {
    lateinit var engine: FlutterEngine

    private val ctx by lazy { ContextService }

    fun setup() {
        engine = FlutterEngine(ctx.requireAppContext())
        Flavor.attach(engine.dartExecutor.binaryMessenger)
        BackNav.attach(engine.dartExecutor.binaryMessenger)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
        FlutterEngineCache.getInstance().put("common", engine);

        Logger.v("Flutter", "FlutterEngine initialized")
    }
}