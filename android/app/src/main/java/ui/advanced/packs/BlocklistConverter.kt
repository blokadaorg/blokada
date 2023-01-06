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

package ui.advanced.packs

import model.Blocklist
import model.MappedBlocklist

fun convertBlocklists(blocklists: List<Blocklist>): List<MappedBlocklist> {
    return blocklists.mapNotNull { blocklist ->
        getPackIdAndConfig(blocklist.id, pathName = blocklist.name)
    }
}

private fun getPackIdAndConfig(id: String, pathName: String): MappedBlocklist? {
    var packId: String? = null
    var packConfig: String? = null

    namePattern.matchEntire(pathName)?.let {
        if (it.groupValues.count() == 3) {
            packId = it.groupValues[1]
            packConfig = it.groupValues[2].replaceFirstChar { it.uppercase() }
        }
    }

    return if (packId != null && packConfig != null) {
        MappedBlocklist(id, packId = packId!!, packConfig = packConfig!!)
    } else {
        null
    }
}

private val namePattern = Regex("mirror\\/v5\\/(\\w+)\\/([a-zA-Z0-9_ \\(\\)]+)\\/hosts\\.txt")