package org.blokada.framework

import android.content.Context
import com.github.salomonbrys.kodein.Kodein
import com.github.salomonbrys.kodein.KodeinAware
import gs.environment.Time

val Context.di: () -> Kodein get() = { (applicationContext as KodeinAware).kodein }

class AEnvironment : Time {
    override fun now(): Long {
        return System.currentTimeMillis()
    }
}

