package filter

import android.content.Context
import android.net.Uri
import android.util.Base64
import com.github.salomonbrys.kodein.instance
import core.Filters
import core.IFilterSource
import gs.environment.Journal
import gs.environment.inject
import gs.environment.load
import gs.environment.openUrl
import java.net.URL

/**
 *
 */
class FilterSourceLink(
        private val timeoutMillis: Int,
        private val processor: IHostlineProcessor,
        var source: URL? = null,
        var backupSource: URL? = null
) : IFilterSource {

    override fun id(): String {
        return "link"
    }

    override fun fetch(): List<String> {
        return try {
            load({ openUrl(source!!, timeoutMillis) }, { processor.process(it) })
        } catch (e: Exception) { try {
            load({ openUrl(backupSource!!, timeoutMillis) }, { processor.process(it) })
        } catch (e: Exception) { emptyList() }}
    }

    override fun fromUserInput(vararg string: String): Boolean {
        val ret = try {
            source = URL(string[0])
            true
        } catch (e: Exception) { false }
        try { backupSource = URL(string[1]) } catch (e: Exception) {}
        return ret
    }

    override fun toUserInput(): String {
        return source?.toExternalForm() ?: ""
    }

    override fun serialize(): String {
        return Base64.encodeToString(source!!.toExternalForm().toByteArray(), Base64.NO_WRAP)
    }

    override fun deserialize(string: String, version: Int): FilterSourceLink {
        val bytes = Base64.decode(string, if (version >= 10) Base64.NO_WRAP else Base64.DEFAULT)
        source = URL(String(bytes))
        return this
    }

    override fun equals(other: Any?): Boolean {
        if (other !is FilterSourceLink) return false
        return source?.equals(other.source) ?: false
    }

    override fun hashCode(): Int {
        return source?.hashCode() ?: 0
    }
}

class FilterSourceUri(
        private val ctx: Context,
        private val processor: IHostlineProcessor,
        var source: Uri? = null,
        var flags: Int = 0
) : IFilterSource {

    override fun id(): String {
        return "file"
    }

    override fun fetch(): List<String> {
        return try {
            load({
                ctx.contentResolver.takePersistableUriPermission(source!!, flags)
                openFile(ctx, source!!)
            }, { processor.process(it) })
        } catch (e: Exception) {
            ctx.inject().instance<Journal>().log(Exception("source file load failed", e))
            emptyList()
        }
    }

    override fun fromUserInput(vararg string: String): Boolean {
        return try {
            source = Uri.parse(string[0])
            true
        } catch (e: Exception) { false }
    }

    override fun toUserInput(): String {
        return source?.toString() ?: ""
    }

    override fun serialize(): String {
        return source.toString()
    }

    override fun deserialize(string: String, version: Int): FilterSourceUri {
        source = Uri.parse(string)
        return this
    }

    override fun equals(other: Any?): Boolean {
        if (other !is FilterSourceUri) return false
        return source?.equals(other.source) ?: false
    }

    override fun hashCode(): Int {
        return source?.hashCode() ?: 0
    }
}

class FilterSourceApp(
        private val ctx: Context,
        private val j: Journal,
        var source: String? = null
) : IFilterSource {

    var system: Boolean = false
        private set

    private val s by lazy { ctx.inject().instance<Filters>() }

    private val apps by lazy {
        s.apps().flatMap { listOf(it.appId to it.appId, it.appId.toLowerCase() to it.appId,
                it.label to it.appId, it.label.toLowerCase() to it.label) }.toMap()
    }

    override fun id(): String {
        return "app"
    }

    override fun fetch(): List<String> {
        // This is a special type that doesn't have hosts domains
        return emptyList()
    }

    override fun fromUserInput(vararg string: String): Boolean {
        return try {
            source = apps[string[0].toLowerCase()] ?: throw Exception("unknown app: ${string[0]}")
            system = s.apps().first { it.appId == source }.system
            true
        } catch (e: Exception) {
            j.log("FilterSourceApp: fromUserInput: fail", e)
            false
        }
    }

    override fun toUserInput(): String {
        return source.toString()
    }

    override fun serialize(): String {
        return source.toString()
    }

    override fun deserialize(string: String, version: Int): FilterSourceApp {
        source = string // todo: validation
        return this
    }

    override fun equals(other: Any?): Boolean {
        if (other !is FilterSourceApp) return false
        return source?.equals(other.source) ?: false
    }

    override fun hashCode(): Int {
        return source?.hashCode() ?: 0
    }
}

private fun openFile(ctx: Context, uri: Uri): java.io.InputStream {
    return ctx.contentResolver.openInputStream(uri)
}
