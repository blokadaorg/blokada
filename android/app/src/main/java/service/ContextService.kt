/*
 * This file is part of Blokada.
 *
 * Blokada is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Blokada is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Blokada.  If not, see <https://www.gnu.org/licenses/>.
 *
 * Copyright © 2020 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package service

import android.app.Activity
import android.content.Context
import java.lang.ref.WeakReference

object ContextService {

    private var context = WeakReference<Context?>(null)
    private var activityContext = WeakReference<Activity?>(null)

    fun setContext(context: Context) {
        this.context = WeakReference(context)
    }

    fun setActivityContext(context: Activity) {
        this.activityContext = WeakReference(context)
    }

    fun requireContext(): Context {
        return activityContext.get() ?: context.get() ?: throw Exception("No context set in ContextService")
    }

    fun requireAppContext(): Context {
        return context.get() ?: throw Exception("No context set in ContextService")
    }

    fun hasActivityContext(): Boolean {
        return activityContext.get() != null
    }

}