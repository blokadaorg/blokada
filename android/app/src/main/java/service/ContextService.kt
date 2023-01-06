/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2021 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package service

import android.app.Activity
import android.app.Application
import android.content.Context
import java.lang.ref.WeakReference

object ContextService {

    private var app: Application? = null
    private var context: Context? = null
    private var activityContext = WeakReference<Activity?>(null)

    fun setApp(app: Application) {
        /**
         * I assume it's ok to keep a strong reference to the app context (and not activity context),
         * since its lifespan is same as app's.
         */
        this.app = app
        this.context = app.applicationContext
    }

    // Used only for BackupAgent
    fun setAppContext(appContext: Context) {
        this.context = appContext
    }

    fun setActivityContext(context: Activity) {
        this.activityContext = WeakReference(context)
    }

    fun requireContext(): Context {
        return activityContext.get() ?: context ?: throw Exception("No context set in ContextService")
    }

    fun requireActivity(): Activity {
        return activityContext.get() ?: throw Exception("No activity context set in ContextService")
    }

    fun requireAppContext(): Context {
        return context ?: throw Exception("No context set in ContextService")
    }

    fun hasActivityContext(): Boolean {
        return activityContext.get() != null
    }

    fun requireApp(): Application {
        return app ?: throw Exception("No app set in ContextService")
    }

}