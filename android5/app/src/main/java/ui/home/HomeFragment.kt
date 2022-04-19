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

package ui.home

import android.os.Bundle
import android.view.*
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import androidx.navigation.fragment.findNavController
import kotlinx.coroutines.delay
import model.BlokadaException
import model.mapErrorToUserFriendly
import model.shouldShowKbLink
import org.blokada.R
import service.AlertDialogService
import service.EnvironmentService
import service.UpdateService
import ui.TunnelViewModel
import ui.settings.SettingsFragmentDirections
import utils.Links

class HomeFragment : Fragment() {

    private val alert = AlertDialogService

    private lateinit var vm: TunnelViewModel

    private lateinit var homeLibre: HomeLibreView
    private lateinit var homeCloud: HomeCloudView

    private var libreMode = EnvironmentService.getFlavor() != "six"

    override fun onCreateView(
            inflater: LayoutInflater,
            container: ViewGroup?,
            savedInstanceState: Bundle?
    ): View {
        val root = inflater.inflate(
            R.layout.fragment_home_container, container, false
        ) as ViewGroup

        homeLibre = HomeLibreView(requireContext())
        homeLibre.parentFragmentManager = parentFragmentManager
        homeLibre.viewLifecycleOwner = viewLifecycleOwner
        homeLibre.lifecycleScope = lifecycleScope
        homeLibre.showVpnPermsSheet = ::showVpnPermsSheet
        homeLibre.showLocationSheet = ::showLocationSheet
        homeLibre.showPlusSheet = ::showPlusSheet
        homeLibre.showFailureDialog = ::showFailureDialog
        homeLibre.setHasOptionsMenu = { setHasOptionsMenu(it) }
        homeLibre.setup()
        root.addView(homeLibre)

        homeCloud = HomeCloudView(requireContext())
        homeCloud.parentFragmentManager = parentFragmentManager
        homeCloud.viewLifecycleOwner = viewLifecycleOwner
        homeCloud.lifecycleScope = lifecycleScope
        homeCloud.showVpnPermsSheet = ::showVpnPermsSheet
        homeCloud.showLocationSheet = ::showLocationSheet
        homeCloud.showPlusSheet = ::showPlusSheet
        homeCloud.showFailureDialog = ::showFailureDialog
        homeCloud.setHasOptionsMenu = { setHasOptionsMenu(it) }
        homeCloud.setup()
        root.addView(homeCloud)

        lifecycleScope.launchWhenCreated {
            delay(1000)
            UpdateService.handleUpdateFlow(
                onOpenDonate = {
                    val nav = findNavController()
                    nav.navigate(R.id.navigation_home)
                    nav.navigate(
                        HomeFragmentDirections.actionNavigationHomeToWebFragment(
                            Links.donate, getString(R.string.universal_action_donate)
                        )
                    )
                },
                onOpenMore = {
                    // Display the thank you page
                    val nav = findNavController()
                    nav.navigate(R.id.navigation_home)
                    nav.navigate(
                        HomeFragmentDirections.actionNavigationHomeToWebFragment(
                            Links.updated, getString(R.string.update_label_updated)
                        )
                    )
                }
            )
        }

        updateHomeView()
        return root
    }

    private fun updateHomeView() {
        homeCloud.visibility = if (libreMode) View.GONE else View.VISIBLE
        homeLibre.visibility = if (libreMode) View.VISIBLE else View.GONE
    }

    override fun onResume() {
        super.onResume()
        homeLibre.onResume()
        homeCloud.onResume()
    }

    override fun onPause() {
        homeLibre.onPause()
        homeCloud.onPause()
        super.onPause()
    }

    private fun showVpnPermsSheet() {
        val fragment = AskVpnProfileFragment.newInstance()
        fragment.show(parentFragmentManager, null)
    }

    private fun showLocationSheet() {
        val fragment = LocationFragment.newInstance()
        fragment.show(parentFragmentManager, null)
    }

    private fun showPlusSheet() {
        val fragment = PaymentFragment.newInstance()
        fragment.show(parentFragmentManager, null)
    }

    private fun showFailureDialog(ex: BlokadaException) {
        val additional: Pair<String, () -> Unit>? =
            if (shouldShowKbLink(ex)) getString(R.string.universal_action_learn_more) to {
                val nav = findNavController()
                nav.navigate(HomeFragmentDirections.actionNavigationHomeToWebFragment(
                    Links.tunnelFailure, getString(R.string.universal_action_learn_more)
                ))
                Unit
            }
            else null

        alert.showAlert(
            message = mapErrorToUserFriendly(ex),
            onDismiss = {
                vm.setInformedUserAboutError()
            },
            additionalAction = additional
        )
    }

    override fun onCreateOptionsMenu(menu: Menu, inflater: MenuInflater) {
        inflater.inflate(R.menu.home_menu, menu)
        super.onCreateOptionsMenu(menu, inflater)
    }

    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        return when (item.itemId) {
            R.id.home_donate -> {
                val nav = findNavController()
                nav.navigate(R.id.navigation_settings)
                nav.navigate(
                    SettingsFragmentDirections.actionNavigationSettingsToWebFragment(
                        Links.donate, getString(R.string.universal_action_donate)
                    ))
                true
            }
            else -> false
        }
    }

}