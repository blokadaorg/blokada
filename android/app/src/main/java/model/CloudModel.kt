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

typealias CloudDnsProfileActivated = Boolean
typealias CloudDeviceTag = String
typealias CloudBlocklists = List<String>
typealias CloudActivityRetention = String

enum class PrivateDnsConfigured {
    CORRECT, INCORRECT, NONE;
}