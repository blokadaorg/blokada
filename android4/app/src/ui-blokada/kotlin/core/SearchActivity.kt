package core

import android.app.Activity
import android.os.Bundle
import core.bits.EnterSearchVB
import org.blokada.R


class SearchActivity : Activity(){

    private val stepView by lazy { findViewById<VBStepView>(R.id.view) }
    private val ktx = ktx("SearchActivity")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.vbstepview)

        val searchVB = EnterSearchVB(ktx) { s -> callback(s); finish() }

        stepView.pages = listOf(
                searchVB
        )
    }

    companion object{
        private var callback : (String) -> Unit = {}

        fun setCallback(c:(String) -> Unit){
            callback = c
        }
    }
}
