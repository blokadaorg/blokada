/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2024 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package binding

import channel.family.FamilyOps
import service.FlutterService

object FamilyBinding: FamilyOps {
    private val flutter by lazy { FlutterService }

    init {
        FamilyOps.setUp(flutter.engine.dartExecutor.binaryMessenger, this)
    }

    override fun doFamilyLinkTemplateChanged(
        linkTemplate: String,
        callback: (Result<Unit>) -> Unit
    ) {
        // TODO: ignored for now
        callback(Result.success(Unit))
    }
}