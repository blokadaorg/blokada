package filter

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.content.pm.PackageManager
import android.view.ContextThemeWrapper
import android.view.LayoutInflater
import android.view.WindowManager
import com.github.salomonbrys.kodein.instance
import core.Filter
import core.IFilterSource
import core.LocalisedFilter
import core.Product
import gs.environment.ComponentProvider
import gs.environment.Journal
import gs.environment.inject
import gs.presentation.nullIfEmpty
import nl.komponents.kovenant.task
import nl.komponents.kovenant.ui.failUi
import nl.komponents.kovenant.ui.successUi
import org.blokada.R

/**
 * TODO: This poor thing needs love (like me)
 */
class AFilterAddDialog(
        private val ctx: Context,
        var sourceProvider: (String) -> IFilterSource
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
            filter?.source is FilterSourceLink -> AFiltersAddView.Tab.LINK
            filter?.source is FilterSourceUri -> AFiltersAddView.Tab.FILE
            filter?.source is FilterSourceSingle -> AFiltersAddView.Tab.SINGLE
            filter?.source is FilterSourceApp -> AFiltersAddView.Tab.APP
            Product.current(ctx) == Product.DNS -> AFiltersAddView.Tab.APP
            else -> null
        }

        if (filter != null) when (view.forceType) {
            AFiltersAddView.Tab.SINGLE -> {
                view.singleView.text = filter.source.toUserInput()
                view.singleView.comment = filter.localised?.comment ?: ""
            }
            AFiltersAddView.Tab.LINK -> {
                view.linkView.text = filter.source.toUserInput()
                view.linkView.correct = true
                view.linkView.comment = filter.localised?.comment ?: ""
                view.linkView.filters = filter.hosts
            }
            AFiltersAddView.Tab.FILE -> {
                val source = filter.source as FilterSourceUri
                view.fileView.uri = source.source
                view.fileView.correct = true
                view.fileView.comment = filter.localised?.comment ?: ""
                view.fileView.filters = filter.hosts
            }
            AFiltersAddView.Tab.APP -> {
                view.appView.text = filter.source.toUserInput()
                view.appView.comment = filter.localised?.comment ?: ""
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
                            id = filter?.id ?: view.singleView.text,
                            source = FilterSourceSingle(view.singleView.text),
                            active = true,
                            whitelist = filter?.whitelist ?: whitelist,
                            localised = LocalisedFilter(view.singleView.text,
                                    view.singleView.comment.nullIfEmpty())
                    ))
                }
            }
            AFiltersAddView.Tab.LINK -> {
                if (!view.linkView.correct) view.linkView.showError = true
                else {
                    task {
                        val source = sourceProvider("link")
                        if (!source.fromUserInput(view.linkView.text))
                            throw Exception("invalid source")
                        val hosts = source.fetch()
                        if (hosts.isEmpty()) throw Exception("source with no hosts")
                        source to hosts
                    } successUi {
                        dialog.dismiss()
                        onSave(Filter(
                                id = filter?.id ?: it.first.serialize(),
                                source = it.first,
                                hosts = it.second,
                                active = true,
                                whitelist = filter?.whitelist ?: whitelist,
                                localised = LocalisedFilter(sourceToName(ctx, it.first),
                                        view.linkView.comment.nullIfEmpty())
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
                        val source = sourceProvider("file") as FilterSourceUri
                        source.source = view.fileView.uri
                        source.flags = view.fileView.flags
                        val hosts = source.fetch()
                        if (hosts.isEmpty()) throw Exception("source with no hosts")
                        source to hosts
                    } successUi {
                        dialog.dismiss()
                        onSave(Filter(
                                id = filter?.id ?: it.first.serialize(),
                                source = it.first,
                                hosts = it.second,
                                active = true,
                                whitelist = filter?.whitelist ?: whitelist,
                                localised = LocalisedFilter(sourceToName(ctx, it.first),
                                        view.fileView.comment.nullIfEmpty())
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
                        val source = sourceProvider("app")
                        if (!source.fromUserInput(view.appView.text))
                            throw Exception("invalid source")
                        source
                    } successUi {
                        dialog.dismiss()
                        onSave(Filter(
                                id = filter?.id ?: it.serialize(),
                                source = it,
                                active = true,
                                whitelist = true,
                                localised = LocalisedFilter(sourceToName(ctx, it),
                                        view.appView.comment.nullIfEmpty())
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

internal fun sourceToName(ctx: android.content.Context, source: IFilterSource): String {
    val name = when (source) {
        is FilterSourceLink -> {
            ctx.getString(R.string.filter_name_link, source.source?.host
                    ?: ctx.getString(R.string.filter_name_link_unknown))
        }
        is FilterSourceUri -> {
            ctx.getString(R.string.filter_name_file, source.source?.lastPathSegment
                    ?: ctx.getString(R.string.filter_name_file_unknown))
        }
        is FilterSourceApp -> { try {
            ctx.packageManager.getApplicationLabel(
                    ctx.packageManager.getApplicationInfo(source.source, PackageManager.GET_META_DATA)
            ).toString()
        } catch (e: Exception) { source.toUserInput() }}
        else -> null
    }

    return name ?: source.toString()
}

