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
import io.flutter.embedding.android.RenderMode
import utils.Logger

class FlutterHomeFragment: FlutterFragment() {

    private var argumentsSet = false

    override fun onAttach(context: Context) {
        if (!argumentsSet || arguments == null) {
            Logger.w("Flutter", "Attaching fragment ${this.hashCode()}")
            arguments = HackyCachedEngineFragmentBuilder("common").getBundle()
            argumentsSet = true
        }
        super.onAttach(context)
    }
}

private class HackyCachedEngineFragmentBuilder(engineId: String):
    FlutterFragment.CachedEngineFragmentBuilder(FlutterHomeFragment::class.java, engineId) {

    init {
        renderMode(RenderMode.texture)
    }

    fun getBundle(): Bundle {
        return createArgs()
    }
}