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

import android.content.Context
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.View
import android.widget.FrameLayout
import android.widget.TextView
import channel.accountpayment.Product
import org.blokada.R

class PaymentItemView : FrameLayout {

    constructor(context: Context) : super(context) {
        init(null, 0)
    }

    constructor(context: Context, attrs: AttributeSet) : super(context, attrs) {
        init(attrs, 0)
    }

    constructor(context: Context, attrs: AttributeSet, defStyle: Int) : super(context, attrs, defStyle) {
        init(attrs, defStyle)
    }

    var product: Product? = null
        set(value) {
            field = value
            product?.let { refresh(it) }
        }

    var onClick: (Product) -> Any = {}

    private fun init(attrs: AttributeSet?, defStyle: Int) {
        LayoutInflater.from(context).inflate(R.layout.item_payment, this, true)
    }

    private fun refresh(product: Product) {
        val group = findViewById<View>(R.id.payment_item_group)
        group.setOnClickListener {
            if (!product.owned) {
                onClick(product)
            }
        }
        group.setBackgroundResource(
            if (product.type == "cloud") R.drawable.bg_payment_item_cloud
            else R.drawable.bg_payment_item_plus
        )
        group.alpha = if (product.owned) 0.2f else 1.0f

        val header = findViewById<TextView>(R.id.payment_item_header)
        header.text = when {
            product.trial != null -> {
                context.getString(R.string.payment_plan_cta_trial_length, product.trial.toString())
            }
            product.periodMonths == 12L -> {
                context.getString(R.string.payment_plan_cta_annual)
            }
            else -> {
                // We do not support other packages now than yearly vs monthly
                context.getString(R.string.payment_plan_cta_monthly)
            }
        }

        val text = findViewById<TextView>(R.id.payment_item_text)
        text.text = when {
            product.trial != null -> {
                context.getString(
                    R.string.payment_subscription_per_year_then, product.price
                )
            }
            product.periodMonths == 12L -> {
                context.getString(
                    R.string.payment_subscription_per_year, product.price
                )
            }
            else -> {
                // We do not support other packages now than yearly vs monthly
                context.getString(
                    R.string.payment_subscription_per_month, product.price
                )
            }
        }

        // Shows additional per-month price for annual packages
        val info = findViewById<TextView>(R.id.payment_item_info)
        when {
            product.owned -> {
                info.visibility = View.VISIBLE
                info.text = "(current plan)"
            }
            product.periodMonths == 12L -> {
                info.visibility = View.VISIBLE
                info.text = makeInfoText(product)
            }
            else -> {
                info.visibility = View.GONE
            }
        }

        // Additional info for this payment option, if any
        val detail = findViewById<TextView>(R.id.payment_item_detail)
        when {
            product.trial != null && !product.owned -> {
                detail.visibility = View.VISIBLE
                // TODO: less hardcoded payment info
                detail.text = "Pay after 7 days. Subscription auto-renews every year until canceled."
            }
            else -> {
                detail.visibility = View.GONE
            }
        }
    }

    private fun makeInfoText(p: Product): String {
        val price = p.pricePerMonth // TODO
        return if (p.type == "cloud") {
            "(%s)".format (
                context.getString(R.string.payment_subscription_per_month, price)
            )
        } else {
            "(%s. %s)".format(
                context.getString(R.string.payment_subscription_per_month, price),
                context.getString(R.string.payment_subscription_offer, "20%")
            )
        }
    }

}