package core

import android.content.Context

enum class Product {
    A, DNS;

    companion object {
        fun current(ctx: Context): Product {
            return when(ctx.packageName) {
                "org.blokada",
                "org.blokada.origin.alarm",
                "org.blokada.alarm" -> Product.A
                "org.blokada.alarm.dns" -> Product.DNS
                else -> Product.A
            }
        }
    }
}

