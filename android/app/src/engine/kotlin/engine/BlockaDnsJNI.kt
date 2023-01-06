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

package com.blocka.dns

class BlockaDnsJNI {
    companion object {
        external fun create_new_dns(
            listen_addr: String,
            dns_ips: String,
            dns_name: String,
            dns_path: String
        ): Long

        external fun dns_close(
            handle: Long
        )

        external fun engine_logger(level: String)
    }
}
