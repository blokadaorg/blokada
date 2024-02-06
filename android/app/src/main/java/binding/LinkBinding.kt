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

import channel.link.Link
import channel.link.LinkOps
import service.FlutterService

object LinkBinding: LinkOps {
    private val flutter by lazy { FlutterService }

    init {
        LinkOps.setUp(flutter.engine.dartExecutor.binaryMessenger, this)
    }

    override fun doLinksChanged(links: List<Link>, callback: (Result<Unit>) -> Unit) {
        // TODO: ignored for now
        callback(Result.success(Unit))
    }
}