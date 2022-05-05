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
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch
import model.Product
import org.blokada.R
import repository.Repos
import service.AlreadyPurchasedException
import service.DialogService
import service.UserCancelledException
import ui.AccountViewModel
import ui.BottomSheetFragment
import ui.app
import utils.Logger

class CloudPaymentFragment : BottomSheetFragment() {

    private lateinit var vm: AccountViewModel

    private val paymentRepo by lazy { Repos.payment }
    private val dialog by lazy { DialogService}

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

        val restore: View = root.findViewById(R.id.payment_restore)
        restore.setOnClickListener {
            restorePayment()
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

                hideOverlay()
            }
        }

        // On successful purchase
        lifecycleScope.launch {
            paymentRepo.successfulPurchasesHot
            .collect {
                dismiss()
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
            try {
                paymentRepo.buyProduct(p.id)
            } catch (ex: UserCancelledException) {
                hideOverlay()
            } catch (ex: AlreadyPurchasedException) {
                // User already made the purchase, try to restore instead
                try {
                    paymentRepo.restorePurchase()
                } catch (ex: Exception) {
                    hideOverlay()
                    dialog.showAlert(getString(R.string.error_payment_inactive_after_restore))
                    .collect {}
                }
            } catch (ex: Exception) {
                hideOverlay()
                dialog.showAlert(getString(R.string.error_payment_failed_alternative))
                .collect {}
            }
        }
    }

    private fun restorePayment() {
        // Show the processing overlay
        processing.visibility = View.VISIBLE
        processing.animate().alpha(1.0f)

        lifecycleScope.launch {
            try {
                paymentRepo.restorePurchase()
            } catch (ex: Exception) {
                hideOverlay()
                dialog.showAlert(getString(R.string.error_payment_inactive_after_restore))
                .collect {}
            }
        }
    }

    private fun hideOverlay() {
        processing.animate().alpha(0.0f).withEndAction {
            processing.visibility = View.GONE
        }
    }

}