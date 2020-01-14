package core.bits.menu

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import blocka.blokadaUserAgent
import com.github.salomonbrys.kodein.instance
import core.*
import core.bits.UpdateVB
import core.bits.openWebContent
import gs.presentation.NamedViewBinder
import org.blokada.R
import java.io.File
import androidx.core.app.ShareCompat
import android.app.Activity
import gs.environment.ComponentProvider


fun createLearnMoreMenuItem(ktx: AndroidKontext): NamedViewBinder {
    return MenuItemVB(ktx,
            label = R.string.menu_learn_more.res(),
            icon = R.drawable.ic_help_outline.res(),
            opens = createLearnMoreMenu(ktx)
    )
}

fun createLearnMoreMenu(ktx: AndroidKontext): MenuItemsVB {
    return MenuItemsVB(ktx,
            items = listOf(
                    LabelVB(ktx, label = R.string.menu_knowledge.res()),
                    createHelpMenuItem(ktx),
                    createTelegramMenuItem(ktx),
                    LabelVB(ktx, label = R.string.menu_get_involved.res()),
                    if (Product.current(ktx.ctx) == Product.FULL) createBlogMenuItem(ktx) else null,
                    createCtaMenuItem(ktx),
                    createLogMenuItem(ktx)
            ).filterNotNull(),
            name = R.string.menu_learn_more.res()
    )
}

fun createHelpMenuItem(ktx: AndroidKontext): NamedViewBinder {
    val helpPage = ktx.di().instance<Pages>().help
    return SimpleMenuItemVB(ktx,
            label = R.string.panel_section_home_help.res(),
            icon = R.drawable.ic_help_outline.res(),
            action = { openWebContent(ktx.ctx, helpPage()) }
    )
}

fun createCtaMenuItem(ktx: AndroidKontext): NamedViewBinder {
    val page = ktx.di().instance<Pages>().cta
    return SimpleMenuItemVB(ktx,
            label = R.string.main_cta.res(),
            icon = R.drawable.ic_feedback.res(),
            action = { openWebContent(ktx.ctx, page()) }
    )
}

fun createDonateMenuItem(ktx: AndroidKontext): NamedViewBinder {
    val page = ktx.di().instance<Pages>().donate
    return SimpleMenuItemVB(ktx,
            label = R.string.slot_donate_action.res(),
            icon = R.drawable.ic_heart_box.res(),
            action = { openWebContent(ktx.ctx, page()) }
    )
}

fun createTelegramMenuItem(ktx: AndroidKontext): NamedViewBinder {
    val page = ktx.di().instance<Pages>().chat
    return SimpleMenuItemVB(ktx,
            label = R.string.menu_telegram.res(),
            icon = R.drawable.ic_comment_multiple_outline.res(),
            action = { openWebContent(ktx.ctx, page()) }
    )
}

fun createBlogMenuItem(ktx: AndroidKontext): NamedViewBinder {
    val page = ktx.di().instance<Pages>().news
    return SimpleMenuItemVB(ktx,
            label = R.string.main_blog_text.res(),
            icon = R.drawable.ic_earth.res(),
            action = { openWebContent(ktx.ctx, page()) }
    )
}

fun createAboutMenuItem(ktx: AndroidKontext): NamedViewBinder {
    return MenuItemVB(ktx,
            label = R.string.slot_about.res(),
            icon = R.drawable.ic_info.res(),
            opens = createAboutMenu(ktx)
    )
}

fun createAboutMenu(ktx: AndroidKontext): MenuItemsVB {
    return MenuItemsVB(ktx,
            items = listOf(
                    LabelVB(ktx, label = blokadaUserAgent(ktx.ctx).res()),
                    UpdateVB(ktx, onTap = defaultOnTap),
                    LabelVB(ktx, label = R.string.menu_share_log_label.res()),
                    createLogMenuItem(ktx),
                    LabelVB(ktx, label = R.string.menu_other.res()),
                    createAppDetailsMenuItem(ktx),
                    if (Product.current(ktx.ctx) == Product.FULL) createChangelogMenuItem(ktx) else null,
                    if (Product.current(ktx.ctx) == Product.FULL) createCreditsMenuItem(ktx) else null,
                    createLegalMenuItem(ktx)
            ).filterNotNull(),
            name = R.string.slot_about.res()
    )
}

fun createCreditsMenuItem(ktx: AndroidKontext): NamedViewBinder {
    val page = ktx.di().instance<Pages>().credits
    return SimpleMenuItemVB(ktx,
            label = R.string.main_credits.res(),
            icon = R.drawable.ic_earth.res(),
            action = { openWebContent(ktx.ctx, page()) }
    )
}

fun createChangelogMenuItem(ktx: AndroidKontext): NamedViewBinder {
    val page = ktx.di().instance<Pages>().changelog
    return SimpleMenuItemVB(ktx,
            label = R.string.main_changelog.res(),
            icon = R.drawable.ic_code_tags.res(),
            action = { openWebContent(ktx.ctx, page()) }
    )
}

fun createLogMenuItem(ktx: AndroidKontext): NamedViewBinder {
    return SimpleMenuItemVB(ktx,
            label = R.string.main_log.res(),
            icon = R.drawable.ic_bug_report_black_24dp.res(),
            action = { shareLog(ktx.ctx) }
    )
}

fun createLegalMenuItem(ktx: AndroidKontext): NamedViewBinder {
    return MenuItemVB(ktx,
            label = R.string.main_legal.res(),
            icon = R.drawable.ic_scale_balance.res(),
            opens = createLegalMenu(ktx)
    )
}
fun createLegalMenu(ktx: AndroidKontext): MenuItemsVB {
    return MenuItemsVB(ktx,
            items = listOf(
                    LabelVB(ktx, label = R.string.main_legal.res()),
                    createPrivacyMenuItem(ktx),
                    createTermsMenuItem(ktx),
                    createLicensesMenuItem(ktx)
            ),
            name = R.string.main_legal.res()
    )
}

fun createLicensesMenuItem(ktx: AndroidKontext): NamedViewBinder {
    val page = ktx.di().instance<Pages>().licenses
    return SimpleMenuItemVB(ktx,
            label = R.string.main_licenses.res(),
            icon = R.drawable.ic_book_open_page_variant.res(),
            action = { openWebContent(ktx.ctx, page()) }
    )
}

fun createTermsMenuItem(ktx: AndroidKontext): NamedViewBinder {
    val page = ktx.di().instance<Pages>().tos
    return SimpleMenuItemVB(ktx,
            label = R.string.main_terms.res(),
            icon = R.drawable.ic_book_open_page_variant.res(),
            action = { openWebContent(ktx.ctx, page()) }
    )
}

fun createPrivacyMenuItem(ktx: AndroidKontext): NamedViewBinder {
    val page = ktx.di().instance<Pages>().privacy
    return SimpleMenuItemVB(ktx,
            label = R.string.main_privacy.res(),
            icon = R.drawable.ic_book_open_page_variant.res(),
            action = { openWebContent(ktx.ctx, page()) }
    )
}

fun shareLog(ctx: Context) {
    //                    if (askForExternalStoragePermissionsIfNeeded(activity)) {
    val uri = File(ctx.filesDir, "/blokada.log")
    val actualUri = FileProvider.getUriForFile(ctx, "${ctx.packageName}.files", uri)

    val provider = ctx.ktx("share").di().instance<ComponentProvider<Activity>>()
    val activity = provider.get()

    if (activity != null) {
        val intent = ShareCompat.IntentBuilder.from(activity)
                .setStream(actualUri)
                .setType("text/*")
                .intent
                .setAction(Intent.ACTION_SEND)
                .setDataAndType(actualUri, "text/*")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        ctx.startActivity(intent)
    } else {
        val openFileIntent = Intent(Intent.ACTION_SEND)
        openFileIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        openFileIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        openFileIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        openFileIntent.type = "plain/*"
        openFileIntent.putExtra(Intent.EXTRA_STREAM, actualUri)
        ctx.startActivity(openFileIntent)
    }
//                    }
}

fun createAppDetailsMenuItem(ktx: AndroidKontext): NamedViewBinder {
    return SimpleMenuItemVB(ktx,
            label = R.string.update_button_appinfo.res(),
            icon = R.drawable.ic_info.res(),
            action = {
                try {
                    ktx.ctx.startActivity(newAppDetailsIntent(ktx.ctx.packageName))
                } catch (e: Exception) {
                }
            }
    )
}

fun newAppDetailsIntent(packageName: String): Intent {
    val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
    intent.data = Uri.parse("package:$packageName")
    return intent
}
