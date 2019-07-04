package core

import android.content.Context
import org.blokada.R
import java.text.DateFormat
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.*

object Format {

    private var format: NumberFormat = NumberFormat.getInstance(Locale.getDefault())
    private var dateFormat: DateFormat = SimpleDateFormat.getDateTimeInstance()
    private var thousand: String = "%s"
    private var million: String = "%s"

    fun setup(ctx: Context, locale: String) {
        format = NumberFormat.getInstance(Locale.forLanguageTag(locale))
        format.maximumFractionDigits = 2
        thousand = ctx.getString(R.string.core_format_thousand)
        million = ctx.getString(R.string.core_format_million)
    }

    fun counter(value: Int, round: Boolean = false): String = when {
        !round -> format.format(value)
        else -> {
            if (value > 1_000_000) million.format(format.format(value / 1_000_000.0))
            else thousand.format(format.format(value / 1_000))
        }
    }

    fun date(date: Date) = dateFormat.format(date)
}
