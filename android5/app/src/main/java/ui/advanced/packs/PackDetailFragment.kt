/*
 * This file is part of Blokada.
 *
 * Blokada is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Blokada is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Blokada.  If not, see <https://www.gnu.org/licenses/>.
 *
 * Copyright © 2020 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package ui.advanced.packs

import androidx.lifecycle.ViewModelProvider
import android.os.Bundle
import androidx.fragment.app.Fragment
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.lifecycle.Observer
import androidx.navigation.fragment.findNavController
import androidx.navigation.fragment.navArgs
import org.blokada.R
import service.tr

class PackDetailFragment : Fragment() {

    companion object {
        fun newInstance() = PackDetailFragment()
    }

    private val args: PackDetailFragmentArgs by navArgs()

    private lateinit var vm: PacksViewModel

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        activity?.let {
            vm = ViewModelProvider(it).get(PacksViewModel::class.java)
        }

        val root =  inflater.inflate(R.layout.fragment_pack_detail, container, false)
        val slugline: TextView = root.findViewById(R.id.packs_slugline)
        val description: TextView = root.findViewById(R.id.packs_description)
        val author: TextView = root.findViewById(R.id.packs_author)
        val authorGroup: View = root.findViewById(R.id.packs_authorgroup)
        val configContainer: ViewGroup = root.findViewById(R.id.packs_configcontainer)

        vm.packs.observe(viewLifecycleOwner, Observer {
            vm.get(args.packId)?.run {
                slugline.text = meta.slugline.tr()
                description.text = meta.description.tr()
                author.text = meta.creditName
                authorGroup.setOnClickListener {
                    val nav = findNavController()
                    nav.navigate(PackDetailFragmentDirections.actionPackDetailFragmentToWebFragment(meta.creditUrl, meta.creditName))
                }

                configContainer.removeAllViews()
                for (config in configs) {
                    val view = OptionView(requireContext())
                    view.name = config
                    view.active = config in status.config
                    view.setOnClickListener {
                        vm.changeConfig(pack = this, config = config)
                    }

                    configContainer.addView(view)
                }
            }
        })

        return root
    }

}