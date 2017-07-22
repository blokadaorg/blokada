package org.blokada.framework.android

import android.content.Context
import com.github.salomonbrys.kodein.Kodein
import com.github.salomonbrys.kodein.KodeinAware
import org.blokada.framework.IEnvironment

val Context.di: () -> Kodein get() = { (applicationContext as KodeinAware).kodein }

class AEnvironment : IEnvironment {
    override fun now(): Long {
        return System.currentTimeMillis()
    }
}

