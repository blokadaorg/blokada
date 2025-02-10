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

package model


enum class Tab {
    Home, Activity, Advanced, Settings, Web;

    companion object {
        fun fromRoute(route: String): Tab {
            return when (route.split("/").first().toLowerCase()) {
                "home" -> Home
                "activity" -> Activity
                "advanced" -> Advanced
                "settings" -> Settings
                else -> Web
            }
        }
    }
}