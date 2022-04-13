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

import androidx.lifecycle.ViewModelProvider
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.lifecycle.Observer
import androidx.lifecycle.lifecycleScope
import androidx.navigation.fragment.findNavController
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.plus
import model.Product
import org.blokada.R
import repository.Repos
import ui.AccountViewModel
import ui.BottomSheetFragment
import ui.app
import ui.utils.getColorFromAttr
import utils.Links
import utils.Logger
import utils.withBoldSections

class CloudPaymentFragment : BottomSheetFragment() {

    private lateinit var vm: AccountViewModel

    private val paymentRepo by lazy { Repos.payment }

    private lateinit var processing: View

    companion object {
        fun newInstance() = CloudPaymentFragment()
    }

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        activity?.let {
            vm = ViewModelProvider(it.app()).get(AccountViewModel::class.java)
        }

        val root = inflater.inflate(R.layout.fragment_payment_cloud, container, false)

        vm.account.observe(viewLifecycleOwner) { account ->
            val restore: View = root.findViewById(R.id.payment_restore)
            restore.setOnClickListener {
                dismiss()
                val nav = findNavController()
                nav.navigate(
                    HomeFragmentDirections.actionNavigationHomeToWebFragment(
                        Links.howToRestore, getString(R.string.payment_action_restore)
                    )
                )
            }
        }

        val terms: View = root.findViewById(R.id.payment_terms)
        terms.setOnClickListener {
            dismiss()
            val fragment = PaymentTermsFragment.newInstance()
            fragment.show(parentFragmentManager, null)
        }

        val seeAllFeatures: View = root.findViewById(R.id.payment_allfeatures)
        seeAllFeatures.setOnClickListener {
            dismiss()
            val fragment = PaymentFeaturesFragment.newInstance()
            fragment.cloud = true
            fragment.show(parentFragmentManager, null)
        }

        val seeLocations: View = root.findViewById(R.id.payment_locations)
        seeLocations.setOnClickListener {
            dismiss()
            val fragment = LocationFragment.newInstance()
            fragment.clickable = false
            fragment.show(parentFragmentManager, null)
        }

        processing = root.findViewById(R.id.payment_processing_group)
        processing.visibility = View.VISIBLE

        val processingText: TextView = root.findViewById(R.id.payment_processing_text)

        val cloudGroup: ViewGroup = root.findViewById(R.id.payment_container_cloud)
        val plusGroup: ViewGroup = root.findViewById(R.id.payment_container_plus)

        // Keep products up to date
        lifecycleScope.launch {
            paymentRepo.productsHot
            .collect { products ->
                Logger.v("xxxx", "Received update for products")
                cloudGroup.removeAllViews()
                val cloudProducts = products.filter { it.type == "cloud" }
                cloudProducts.forEach {
                    val v = PaymentItemView(requireContext())
                    cloudGroup.addView(v)
                    v.product = it
                    v.onClick = { purchase(it) }
                }

                plusGroup.removeAllViews()
                val plusProducts = products.filter { it.type == "plus" }
                plusProducts.forEach {
                    val v = PaymentItemView(requireContext())
                    plusGroup.addView(v)
                    v.product = it
                    v.onClick = { purchase(it) }
                }

                // Hide the processing overlay with anim
                processing.animate().alpha(0.0f).withEndAction {
                    processing.visibility = View.GONE
                }
            }
        }

        // On successful purchase
        lifecycleScope.launch {
            paymentRepo.successfulPurchasesHot
            .collect {
                if (it != null) dismiss()
            }
        }

        lifecycleScope.launch {
            paymentRepo.refreshProducts()
        }

        return root
    }

    private fun purchase(p: Product) {
        // Show the processing overlay
        processing.visibility = View.VISIBLE
        processing.animate().alpha(1.0f)

        // Initiate purchase (will emit on successfulPurchasesHot)
        lifecycleScope.launch {
            paymentRepo.buyProduct(p.id)
        }
    }

}