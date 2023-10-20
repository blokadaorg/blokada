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

package ui.advanced.decks

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.fragment.app.Fragment
import androidx.lifecycle.ViewModelProvider
import binding.StageBinding
import org.blokada.R
import service.tr
import ui.app

class PackDetailFragment : Fragment() {

    companion object {
        fun newInstance() = PackDetailFragment()
    }

    private lateinit var vm: PacksViewModel
    private val stage by lazy { StageBinding }

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        activity?.let {
            vm = ViewModelProvider(it.app()).get(PacksViewModel::class.java)
        }

        val root =  inflater.inflate(R.layout.fragment_pack_detail, container, false)
        val slugline: TextView = root.findViewById(R.id.packs_slugline)
        val description: TextView = root.findViewById(R.id.packs_description)
        val author: TextView = root.findViewById(R.id.packs_author)
        val authorGroup: View = root.findViewById(R.id.packs_authorgroup)
        val configContainer: ViewGroup = root.findViewById(R.id.packs_configcontainer)

        val packId = arguments?.getString("id") ?: throw Exception("No pack id provided")

        vm.packs.observe(viewLifecycleOwner) {
            vm.get(packId)?.run {
                slugline.text = meta.slugline.tr()
                description.text = meta.description.tr()
                author.text = meta.creditName
                authorGroup.setOnClickListener {
                    stage.setRoute(meta.creditUrl)
                }

                configContainer.removeAllViews()
                for (config in configs) {
                    val view = OptionView(requireContext())
                    view.name = config
                    view.active = config in status.config
                    view.alpha = 1.0f
                    view.setOnClickListener {
                        view.alpha = 0.5f
                        vm.changeConfig(pack = this, config = config)
                    }

                    configContainer.addView(view)
                }
            }
        }

        return root
    }

}