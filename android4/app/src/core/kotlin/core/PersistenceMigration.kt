package core

import android.widget.Toast
import java.io.File

object PersistenceMigration {

    fun setup(ktx: AndroidKontext) {
        try {
            val oldPkg = "org.blokada.origin.alarm"
            val newPkg = ktx.ctx.packageName
            if (oldPkg == newPkg) return

            val oldApkContext = ktx.ctx.createPackageContext(oldPkg, 0)
            val oldPersistencePath = oldApkContext.filesDir.absolutePath + File.separator + "io.paperdb"
            val newPersistencePath = ktx.ctx.filesDir.absolutePath + File.separator + "io.paperdb"

            val newPersistence = File(newPersistencePath)
            if (newPersistence.exists()) return

            ktx.w("Migrating persistence from old apk")

            File(oldPersistencePath).copyDirTo(newPersistence)
            val prefs = "/data/data/%1\$s/shared_prefs"
            File(prefs.format(oldPkg)).copyDirTo(File(prefs.format(newPkg)))
            val defaultPrefs = prefs + "/%1\$s_preferences.xml"
            File(defaultPrefs.format(oldPkg)).copyDirTo(File(defaultPrefs.format(newPkg)))

            Toast.makeText(ktx.ctx, "Your settings have been migrated", Toast.LENGTH_LONG).show()
        } catch (ex: Exception) {
            // Means no such package ID
        }
    }

}

private fun File.copyDirTo(dir: File) {
    if (!dir.exists()) {
        dir.mkdirs()
    }
    listFiles()?.forEach {
        if (it.isDirectory) {
            it.copyDirTo(File(dir, it.name))
        } else {
            it.copyFileTo(File(dir, it.name))
        }
    }
}

private fun File.copyFileTo(file: File) {
    inputStream().use { input ->
        file.outputStream().use { output ->
            input.copyTo(output)
        }
    }
}