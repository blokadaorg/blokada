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

package ui.home

import android.os.Bundle
import android.view.*
import androidx.navigation.fragment.findNavController
import org.blokada.R
import ui.BottomSheetFragment
import utils.Links

class FirstTimeFragment : BottomSheetFragment() {

    companion object {
        fun newInstance() = FirstTimeFragment()
    }

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        val root = inflater.inflate(R.layout.fragment_firsttime, container, false)

        val back: View = root.findViewById(R.id.back)
        back.setOnClickListener {
            dismiss()
        }

        val more: View = root.findViewById(R.id.firsttime_more)
        more.setOnClickListener {
            dismiss()
            val nav = findNavController()
            nav.navigate(
                HomeFragmentDirections.actionNavigationHomeToWebFragment(
                    Links.intro, getString(R.string.intro_header)
                )
            )
        }

        val firstTimeContinue: View = root.findViewById(R.id.firsttime_continue)
        firstTimeContinue.setOnClickListener {
            dismiss()
        }

        return root
    }

}