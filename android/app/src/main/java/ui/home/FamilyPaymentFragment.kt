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
import android.widget.Button
import androidx.lifecycle.lifecycleScope
import binding.AccountPaymentBinding
import channel.payment.Product
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.launch
import model.NoPayments
import org.blokada.R
import service.DialogService
import service.Sheet
import ui.BottomSheetFragment

class FamilyPaymentFragment : BottomSheetFragment() {
    override val modal: Sheet = Sheet.Payment

    private val payment by lazy { AccountPaymentBinding }

    private val dialog by lazy { DialogService }

    private lateinit var processing: View
    private lateinit var error: View

    companion object {
        fun newInstance() = FamilyPaymentFragment()
    }

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        val root = inflater.inflate(R.layout.fragment_payment_family, container, false)

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
            fragment.family = true
            fragment.show(parentFragmentManager, null)
        }

        val restore: View = root.findViewById(R.id.payment_restore)
        restore.setOnClickListener {
            restorePayment()
        }

        processing = root.findViewById(R.id.payment_processing_group)
        processing.visibility = View.VISIBLE

        val cloudGroup: ViewGroup = root.findViewById(R.id.payment_container_cloud)

        error = root.findViewById(R.id.payment_error_group)
        val retryButton: Button = root.findViewById(R.id.payment_retry)
        retryButton.setOnClickListener {
            refreshProducts()
        }

        // Keep products up to date
        lifecycleScope.launch {
            payment.products.filterNotNull()
            .collect { products ->
                cloudGroup.removeAllViews()

                val cloudProducts = products.filter { it.type == "family" }

                val accountType = payment.accountType
//                when (accountType) {
                    // Standard case
                    cloudProducts.forEach { p ->
                        val v = PaymentItemView(requireContext())
                        cloudGroup.addView(v)
                        v.product = p
                        v.onClick = { purchase(p) }
                    }

//                    // User is downgrading to Cloud or changing sub period
//                    AccountType.Plus -> {
//                        val activeSub = payment.activeSub.value
//                        cloudProducts.forEach { p ->
//                            val v = PaymentItemView(requireContext())
//                            cloudGroup.addView(v)
//                            v.product = p.copy(trial = null, owned = false)
//                            v.onClick = { purchase(p, change = true) }
//                        }
//                    }
//                }

                hideProcessing()
                if (products.isEmpty()) showError() else hideError()
            }
        }

        // On successful purchase
//        lifecycleScope.launch {
//            paymentRepo.successfulPurchasesHot
//            .collect {
//                dismiss()
//            }
//        }

        refreshProducts()

        return root
    }

    private fun refreshProducts() {
        lifecycleScope.launch {
            try {
                showProcessing()
                hideError()
                payment.refreshProducts()
            } catch (ex: NoPayments) {
                hideProcessing()
                delay(500)
                if (payment.products.value.isNullOrEmpty()) {
                    dialog.showAlert(getString(R.string.error_payment_not_available),
                        okText = getString(R.string.universal_action_continue),
                        okAction = {
                            dismiss()
                        })
                        .collect {}
                }
            }
            hideProcessing()
        }
    }

    private fun purchase(p: Product, change: Boolean = false) {
        showProcessing()

        // Initiate purchase (will emit on successfulPurchasesHot)
        lifecycleScope.launch {
            if (!change) payment.buyProduct(p.id)
            else payment.changeProduct(p.id)
            hideProcessing()
        }
    }

    private fun restorePayment() {
        // Show the processing overlay
        processing.visibility = View.VISIBLE
        processing.animate().alpha(1.0f)

        lifecycleScope.launch {
            payment.restorePurchase()
            dismiss()
        }
    }

    private fun showProcessing() {
        // Show the processing overlay
        processing.visibility = View.VISIBLE
        processing.animate().alpha(1.0f)
    }

    private fun hideProcessing() {
        processing.animate().alpha(0.0f).withEndAction {
            processing.visibility = View.GONE
        }
    }

    private fun showError() {
        // Show the error overlay
        error.visibility = View.VISIBLE
        error.alpha = 1.0f
    }

    private fun hideError() {
        error.animate().setDuration(1000).alpha(0.0f).withEndAction {
            error.visibility = View.GONE
        }
    }

}