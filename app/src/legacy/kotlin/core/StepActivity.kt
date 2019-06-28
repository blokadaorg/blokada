package core

import android.app.Activity
import android.util.Base64
import com.github.salomonbrys.kodein.instance
import core.bits.EnterDomainVB
import core.bits.EnterNameVB
import org.blokada.R
import tunnel.Filter
import tunnel.FilterSourceDescriptor


class StepActivity : Activity() {

    companion object {
        const val EXTRA_WHITELIST = "whitelist"
    }

    private val stepView by lazy { findViewById<VBStepView>(R.id.view) }
    private val ktx = ktx("StepActivity")
    private var whitelist: Boolean = false

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.vbstepview)

        whitelist = intent.getBooleanExtra(EXTRA_WHITELIST, false)

        val nameVB = EnterNameVB(ktx, accepted = {
            name = it
            saveNewFilter()
        })

        stepView.pages = listOf(
                EnterDomainVB(ktx, accepted = { it ->
                    nameVB.inputForGeneratingName = if (it.size == 1) it.first().source else ""
                    sources = it
                    stepView.next()
                }),
                nameVB
        )
    }

    override fun onBackPressed() {
//        if (!dashboardView.handleBackPressed()) super.onBackPressed()
        super.onBackPressed()
    }


    private var sources: List<FilterSourceDescriptor> = emptyList()
    private var name = ""

    private val tunnelManager by lazy { ktx.di().instance<tunnel.Main>() }

    private fun saveNewFilter() = when {
        sources.isEmpty() || name.isBlank() -> Unit
        else -> {
            sources.map {
                val name = if (sources.size == 1) this.name else this.name + " (${it.source})"
                Filter(
                        id = sourceToId(it),
                        source = it,
                        active = true,
                        whitelist = whitelist,
                        customName = name
                )
            }.apply {
                tunnelManager.putFilters(ktx, this)
            }
            finish()
        }
    }

    private fun sourceToId(source: FilterSourceDescriptor): String {
        return "custom-filter:" + Base64.encodeToString(source.source.toByteArray(), Base64.NO_WRAP)
    }

}
