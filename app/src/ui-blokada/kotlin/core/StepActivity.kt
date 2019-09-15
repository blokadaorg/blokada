package core

import android.app.Activity
import android.util.Base64
import com.github.salomonbrys.kodein.instance
import core.bits.EnterDomainVB
import core.bits.EnterFileNameVB
import core.bits.EnterNameVB
import org.blokada.R
import tunnel.Filter
import tunnel.FilterSourceDescriptor
import tunnel.showSnack
import java.io.File
import java.lang.Exception


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
                EnterDomainVB(ktx, accepted = {
                    nameVB.inputForGeneratingName = if (it.size == 1) it.first().source else ""
                    sources = it
                    stepView.next()
                },
                fileImport = {
                    val path = File(getExternalPath(), "/filters/")
                    val files = path.listFiles()
                    if(files == null || files.isEmpty()){
                        showSnack(R.string.slot_enter_domain_no_file)
                    }else{
                        stepView.pages = listOf(
                        EnterFileNameVB(ktx, files) { file ->
                            val f = Filter(
                                    id(file.replace('/', '.'), whitelist = false),
                                    source = FilterSourceDescriptor("file", file),
                                    active = true,
                                    whitelist = false
                            )
                            tunnelManager.putFilter(ktx, f)
                            finish()
                        },
                        nameVB)
                    }
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
