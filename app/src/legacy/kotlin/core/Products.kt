package core

import android.content.Context
import org.blokada.BuildConfig

enum class Product {
    A, DNS;

    companion object {
        fun current(ctx: Context): Product {
            return when(ctx.packageName) {
                "org.blokada",
                "org.blokada.origin.alarm",
                "org.blokada.alarm" -> Product.A
                "org.blokada.alarm.dnschanger" -> Product.DNS
                else -> Product.A
            }
        }
    }
}

enum class ProductType {
    DEBUG, RELEASE, OFFICIAL, BETA;

    companion object {
        fun current(): ProductType {
            return when(BuildConfig.BUILD_TYPE.toLowerCase()) {
                "debug" -> DEBUG
                "official" -> OFFICIAL
                "beta" -> BETA
                else -> RELEASE
            }
        }

        fun isPublic(): Boolean {
            return current() in listOf(RELEASE, OFFICIAL)
        }
    }
}
