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

package ui.journal

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import binding.StageBinding
import org.blokada.R
import utils.Links

class RetentionFragment : Fragment() {
    private val stage by lazy { StageBinding }

    override fun onCreateView(
            inflater: LayoutInflater,
            container: ViewGroup?,
            savedInstanceState: Bundle?
    ): View? {
        val root = inflater.inflate(R.layout.fragment_retention, container, false)

        // TODO: same code in StatsFragment
        val retention: RetentionView = root.findViewById(R.id.activity_retention)
        retention.lifecycleScope = lifecycleScope
        retention.openPolicy = {
            stage.setRoute(Links.privacy(false))
        }
        retention.setup()

        return root
    }
}
