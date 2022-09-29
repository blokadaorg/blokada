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

package ui.home

import android.content.Context
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragment

class FlutterHomeFragment: FlutterFragment() {
    override fun onAttach(context: Context) {
        arguments = HackyCachedEngineFragmentBuilder("common").getBundle()
        super.onAttach(context)
    }
}

private class HackyCachedEngineFragmentBuilder(engineId: String):
    FlutterFragment.CachedEngineFragmentBuilder(FlutterHomeFragment::class.java, engineId) {
    fun getBundle(): Bundle {
        return createArgs()
    }
}