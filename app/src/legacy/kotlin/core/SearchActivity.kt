package core

import android.app.Activity
import android.os.Bundle
import org.blokada.R
import android.os.Handler
import android.widget.FrameLayout


class SearchActivity : Activity(){
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.view_search)
        val searchVB = EnterSearchVB(this) { s -> callback(s); finish()}
        val v = findViewById<SlotView>(R.id.search_slot)
        searchVB.attach(v)
        Handler().postDelayed({ (v as SlotView).unfold() }, 150)
    }

    companion object{
        private var callback : (String) -> Unit = {}

        fun setCallback(c:(String) -> Unit){
            callback = c
        }
    }
}