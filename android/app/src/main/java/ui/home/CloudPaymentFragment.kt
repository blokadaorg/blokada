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
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import model.AccountType
import model.NoPayments
import model.Product
import org.blokada.R
import repository.Repos
import service.AlreadyPurchasedException
import service.DialogService
import service.UserCancelledException
import ui.BottomSheetFragment
import ui.utils.cause
import utils.Logger

class CloudPaymentFragment : BottomSheetFragment() {

    private val paymentRepo by lazy { Repos.payment }
    private val accountRepo by lazy { Repos.account }

    private val dialog by lazy { DialogService }

    private lateinit var processing: View
    private lateinit var error: View

    companion object {
        fun newInstance() = CloudPaymentFragment()
    }

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
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

        val restore: View = root.findViewById(R.id.payment_restore)
        restore.setOnClickListener {
            restorePayment()
        }

        processing = root.findViewById(R.id.payment_processing_group)
        processing.visibility = View.VISIBLE

        val cloudGroup: ViewGroup = root.findViewById(R.id.payment_container_cloud)
        val plusGroup: ViewGroup = root.findViewById(R.id.payment_container_plus)

        error = root.findViewById(R.id.payment_error_group)
        val retryButton: Button = root.findViewById(R.id.payment_retry)
        retryButton.setOnClickListener {
            refreshProducts()
        }

        // Keep products up to date
        lifecycleScope.launch {
            paymentRepo.productsHot
            .collect { products ->
                cloudGroup.removeAllViews()
                plusGroup.removeAllViews()

                val cloudProducts = products.filter { it.type == "cloud" }
                val plusProducts = products.filter { it.type == "plus" }

                val accountType = accountRepo.accountTypeHot.first()
                when (accountType) {
                    // Standard case, user is purchasing Cloud or Plus
                    AccountType.Libre -> {
                        cloudProducts.forEach { p ->
                            val v = PaymentItemView(requireContext())
                            cloudGroup.addView(v)
                            v.product = p
                            v.onClick = { purchase(p) }
                        }

                        plusProducts.forEach { p ->
                            val v = PaymentItemView(requireContext())
                            plusGroup.addView(v)
                            v.product = p
                            v.onClick = { purchase(p) }
                        }
                    }
                    // User is upgrading to Plus
                    AccountType.Cloud -> {
                        cloudProducts.forEach { p ->
                            val v = PaymentItemView(requireContext())
                            cloudGroup.addView(v)
                            v.product = p.copy(trial = false, owned = true)
                            v.onClick = { purchase(p, change = true) }
                        }

                        plusProducts.forEach { p ->
                            val v = PaymentItemView(requireContext())
                            plusGroup.addView(v)
                            v.product = p.copy(trial = false)
                            v.onClick = { purchase(p, change = true) }
                        }
                    }
                    // User is downgrading to Cloud or changing sub period
                    AccountType.Plus -> {
                        val activeSub = paymentRepo.activeSubHot.first()
                        cloudProducts.forEach { p ->
                            val v = PaymentItemView(requireContext())
                            cloudGroup.addView(v)
                            v.product = p.copy(trial = false, owned = false)
                            v.onClick = { purchase(p, change = true) }
                        }

                        plusProducts.forEach { p ->
                            val v = PaymentItemView(requireContext())
                            plusGroup.addView(v)
                            v.product = p.copy(trial = false, owned = p.id == activeSub)
                            v.onClick = { purchase(p, change = true) }
                        }
                    }
                }

                hideProcessing()
                if (products.isEmpty()) showError() else hideError()
            }
        }

        // On successful purchase
        lifecycleScope.launch {
            paymentRepo.successfulPurchasesHot
            .collect {
                dismiss()
            }
        }

        refreshProducts()

        return root
    }

    private fun refreshProducts() {
        lifecycleScope.launch {
            try {
                showProcessing()
                hideError()
                paymentRepo.refresh()
            } catch (ex: NoPayments) {
                hideProcessing()
                delay(500)
                if (paymentRepo.productsHot.first().isEmpty()) {
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
            try {
                if (!change) paymentRepo.buyProduct(p.id)
                else paymentRepo.changeProduct(p.id)
            } catch (ex: UserCancelledException) {
                hideProcessing()
            } catch (ex: AlreadyPurchasedException) {
                // User already made the purchase, try to restore instead
                try {
                    paymentRepo.restorePurchase()
                } catch (ex: Exception) {
                    hideProcessing()
                    dialog.showAlert(getString(R.string.error_payment_inactive_after_restore))
                    .collect {}
                }
            } catch (ex: Exception) {
                Logger.e("CloudPayment", "Payment failed with error".cause(ex))
                hideProcessing()
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
                hideProcessing()
                dialog.showAlert(getString(R.string.error_payment_inactive_after_restore))
                .collect {}
            }
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