package filter

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.view.ContextThemeWrapper
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import com.github.salomonbrys.kodein.instance
import core.Product
import gs.environment.ComponentProvider
import gs.environment.Journal
import gs.environment.inject
import gs.presentation.LayoutViewBinder
import gs.presentation.nullIfEmpty
import nl.komponents.kovenant.task
import nl.komponents.kovenant.ui.failUi
import nl.komponents.kovenant.ui.successUi
import org.blokada.R
import tunnel.Filter
import tunnel.FilterSourceDescriptor

class EditFilterDash(
        private val filter: Filter? = null,
        private var whitelist: Boolean = false
) : LayoutViewBinder(R.layout.view_filtersadd) {

    override fun attach(view: View) {
        view as AFiltersAddView
        view.showApp = whitelist
        view.forceType = when {
            filter?.source?.id == "link" -> AFiltersAddView.Tab.LINK
            filter?.source?.id == "file" -> AFiltersAddView.Tab.FILE
            filter?.source?.id == "single" -> AFiltersAddView.Tab.SINGLE
            filter?.source?.id == "app" -> AFiltersAddView.Tab.APP
            Product.current(view.context) == Product.DNS -> AFiltersAddView.Tab.APP
            else -> null
        }

        if (filter != null) when (view.forceType) {
            AFiltersAddView.Tab.SINGLE -> {
                view.singleView.text = filter.source.source
                view.singleView.comment = filter.customComment ?: ""
            }
            AFiltersAddView.Tab.LINK -> {
                view.linkView.text = filter.source.source
                view.linkView.correct = true
                view.linkView.comment = filter.customComment ?: ""
            }
            AFiltersAddView.Tab.FILE -> {
                val source = filter.source
                view.fileView.uri = Uri.parse(source.source)
                view.fileView.correct = true
                view.fileView.comment = filter.customComment ?: ""
            }
            AFiltersAddView.Tab.APP -> {
                view.appView.text = filter.source.source
                view.appView.comment = filter.customComment ?: ""
            }
        }
    }

    override fun detach(view: View) {
    }
}

/**
 * TODO: This poor thing needs love (like me)
 */
class AFilterAddDialog(
        private val ctx: Context,
        var sourceProvider: DefaultSourceProvider
) {
    var onSave = { filter: Filter -> }

    private val activity by lazy { ctx.inject().instance<ComponentProvider<Activity>>().get() }
    private val j by lazy { ctx.inject().instance<Journal>() }
    private val themedContext by lazy { ContextThemeWrapper(ctx, R.style.BlokadaColors_Dialog) }
    private val view = LayoutInflater.from(themedContext)
            .inflate(R.layout.view_filtersadd, null, false) as AFiltersAddView
    private val dialog: AlertDialog
    private var whitelist: Boolean = false

    init {
        val d = AlertDialog.Builder(activity)
        d.setView(view)
        d.setPositiveButton(R.string.filter_edit_save, { dia, int -> })
        d.setNegativeButton(R.string.filter_edit_cancel, { dia, int -> })
        dialog = d.create()
    }

    fun show(filter: Filter?, whitelist: Boolean = false) {
        this.whitelist = whitelist

        view.showApp = whitelist
        view.forceType = when {
            filter?.source?.id == "link" -> AFiltersAddView.Tab.LINK
            filter?.source?.id == "file" -> AFiltersAddView.Tab.FILE
            filter?.source?.id == "single" -> AFiltersAddView.Tab.SINGLE
            filter?.source?.id == "app" -> AFiltersAddView.Tab.APP
            Product.current(ctx) == Product.DNS -> AFiltersAddView.Tab.APP
            else -> null
        }

        if (filter != null) when (view.forceType) {
            AFiltersAddView.Tab.SINGLE -> {
                view.singleView.text = filter.source.source
                view.singleView.comment = filter.customComment ?: ""
            }
            AFiltersAddView.Tab.LINK -> {
                view.linkView.text = filter.source.source
                view.linkView.correct = true
                view.linkView.comment = filter.customComment ?: ""
            }
            AFiltersAddView.Tab.FILE -> {
                val source = filter.source
                view.fileView.uri = Uri.parse(source.source)
                view.fileView.correct = true
                view.fileView.comment = filter.customComment ?: ""
            }
            AFiltersAddView.Tab.APP -> {
                view.appView.text = filter.source.source
                view.appView.comment = filter.customComment ?: ""
            }
        }

        if (dialog.isShowing) return
        try {
            dialog.show()
            dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener { handleSave(filter) }
            dialog.window.clearFlags(
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                            WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM
            )
        } catch (e: Exception) {
            j.log(e)
        }
    }

    private fun handleSave(filter: Filter?) {
        when (view.currentTab) {
            AFiltersAddView.Tab.SINGLE -> {
                if (!view.singleView.correct) view.singleView.showError = true
                else {
                    dialog.dismiss()
                    onSave(Filter(
                            id = filter?.id ?: id(view.singleView.text, whitelist),
                            source = FilterSourceDescriptor("single", view.singleView.text),
                            active = true,
                            whitelist = filter?.whitelist ?: whitelist,
                            customName = filter?.customName,
                            customComment = view.singleView.comment.nullIfEmpty()
                    ))
                }
            }
            AFiltersAddView.Tab.LINK -> {
                if (!view.linkView.correct) view.linkView.showError = true
                else {
                    task {
                        val source = sourceProvider.from("link")
                        if (!source.fromUserInput(view.linkView.text))
                            throw Exception("invalid source")
                        val hosts = source.fetch()
                        if (hosts.isEmpty()) throw Exception("source with no hosts")
                        source to hosts
                    } successUi {
                        dialog.dismiss()
                        onSave(Filter(
                                id = filter?.id ?: id(it.first.serialize(), whitelist),
                                source = FilterSourceDescriptor("link", view.linkView.text),
                                active = true,
                                whitelist = filter?.whitelist ?: whitelist,
                                customName = filter?.customName,
                                customComment = view.linkView.comment.nullIfEmpty()
                        ))
                        view.linkView.correct = true
                    } failUi {
                        view.linkView.correct = false
                        view.linkView.showError = true
                    }
                }
            }
            AFiltersAddView.Tab.FILE -> {
                if (!view.fileView.correct) view.fileView.showError = true
                else {
                    task {
                        val source = sourceProvider.from("file") as FilterSourceUri
                        source.source = view.fileView.uri
                        source.flags = view.fileView.flags
                        val hosts = source.fetch()
                        if (hosts.isEmpty()) throw Exception("source with no hosts")
                        source to hosts
                    } successUi {
                        dialog.dismiss()
                        onSave(Filter(
                                id = filter?.id ?: id(it.first.serialize(), whitelist),
                                source = FilterSourceDescriptor("file", view.fileView.text),
                                active = true,
                                whitelist = filter?.whitelist ?: whitelist,
                                customName = filter?.customName,
                                customComment = view.fileView.comment.nullIfEmpty()
                        ))
                        view.fileView.correct = true
                    } failUi {
                        view.fileView.correct = false
                        view.fileView.showError = true
                    }
                }
            }
            AFiltersAddView.Tab.APP -> {
                if (!view.appView.correct) view.appView.showError = true
                else {
                    task {
                        val source = sourceProvider.from("app")
                        if (!source.fromUserInput(view.appView.text))
                            throw Exception("invalid source")
                        source
                    } successUi {
                        dialog.dismiss()
                        onSave(Filter(
                                id = filter?.id ?: id(it.serialize(), whitelist),
                                source = FilterSourceDescriptor("app", view.appView.text),
                                active = true,
                                whitelist = true,
                                customName = filter?.customName,
                                customComment = view.appView.comment.nullIfEmpty()
                        ))
                        view.appView.correct = true
                    } failUi {
                        view.appView.correct = false
                        view.appView.showError = true
                    }
                }
            }
        }
    }

}

internal fun id(name: String, whitelist: Boolean): String {
    return if(whitelist) "${name}_wl" else name
}

internal fun sourceToName(ctx: android.content.Context, source: FilterSourceDescriptor): String {
    val name = when (source.id) {
        "link" -> {
            ctx.getString(R.string.filter_name_link, source.source)
        }
        "file" -> {
            val source = try { Uri.parse(source.source) } catch (e: Exception) { null }
            ctx.getString(R.string.filter_name_file, source?.lastPathSegment
                    ?: ctx.getString(R.string.filter_name_file_unknown))
        }
        "app" -> { try {
            ctx.packageManager.getApplicationLabel(
                    ctx.packageManager.getApplicationInfo(source.source, PackageManager.GET_META_DATA)
            ).toString()
        } catch (e: Exception) { source.source }}
        else -> null
    }

    return name ?: source.source
}
