package filter

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.text.Editable
import android.text.TextWatcher
import android.util.AttributeSet
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.EditText
import android.widget.ScrollView
import android.widget.TextView
import com.github.salomonbrys.kodein.instance
import core.MainActivity
import gs.environment.ComponentProvider
import gs.environment.inject
import org.blokada.R

class AFiltersAddFileView(
        ctx: Context,
        attributeSet: AttributeSet
) : ScrollView(ctx, attributeSet) {

    var text = ""
        get() { return field.trim() }
        set(value) {
            field = value
            buttonView.text = if (value.isEmpty()) context.getString(R.string.filter_edit_file_choose)
            else value
            updateError()
        }

    var comment = ""
        get() { return field.trim() }
        set(value) {
            field = value
            if (commentView.text.toString() != value) {
                commentView.setText(value)
                commentView.setSelection(value.length)
            }
            if (value.isNotEmpty()) {
                commentReadView.text = value
            } else {
                commentReadView.text = resources.getString(R.string.filter_edit_comments_none)
            }
        }

    var filters = listOf<String>()
        set(value) {
            field = value
            if (value.isEmpty()) {
                filtersGroup.visibility = View.GONE
            } else {
                filtersGroup.visibility = View.VISIBLE
                filtersView.text = value.joinToString(separator = "\n", limit = 100)
                filtersCountView.text = context.resources.getString(R.string.filter_edit_count, value.size)
            }
        }

    var showError = false
        set(value) {
            field = value
            updateError()
        }

    var correct = false
        set(value) {
            field = value
            updateError()
        }

    fun reset() {
        text = ""
        comment = ""
        showError = false
        correct = false
        filters = listOf()
        commentView.visibility = View.GONE
        commentReadView.visibility = View.VISIBLE
    }
    private val buttonView by lazy { findViewById(R.id.filter_file_button) as Button }
    private val errorView by lazy { findViewById(R.id.filter_error) as ViewGroup }
    private val commentView by lazy { findViewById(R.id.filter_comment) as EditText }
    private val commentReadView by lazy { findViewById(R.id.filter_comment_read) as TextView }
    private val filtersGroup by lazy { findViewById(R.id.filter_link_loaded_group) as View }
    private val filtersView by lazy { findViewById(R.id.filter_link_loaded) as TextView }
    private val filtersCountView by lazy { findViewById(R.id.filter_link_loaded_count) as TextView }

    private val activity by lazy { ctx.inject().instance<ComponentProvider<MainActivity>>() }
    private val processor by lazy { ctx.inject().instance<IHostlineProcessor>() }

    var uri: android.net.Uri? = null
        set(value) {
            field = value
            if (value == null) text = ""
            else try {
                text = sourceToName(context, FilterSourceUri(context, processor, value))
            } catch (e: Exception) {
                text = value.toString()
            }
        }

    var flags: Int = 0

    override fun onFinishInflate() {
        super.onFinishInflate()
        updateError()

        buttonView.setOnClickListener {
            val a = activity.get()
            if (a != null) {
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)

                intent.type = "text/plain"
                intent.addCategory(Intent.CATEGORY_OPENABLE)

                a.addOnNextActivityResultListener { result: Int, data: Intent? ->
                    if (result != Activity.RESULT_OK || data == null) {
                        uri = null
                        correct = false
                        showError = true
                    } else {
                        uri = data.data
                        correct = true
                        flags = data.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION
                    }
                }

                a.startActivityForResult(Intent.createChooser(intent,
                            context.getString(R.string.filter_edit_file_choose)), 0)
            }
        }

        commentReadView.setOnClickListener {
            commentReadView.visibility = View.GONE
            commentView.visibility = View.VISIBLE
            commentView.requestFocus()
        }

        commentView.setOnFocusChangeListener { view, focused ->
            if (!focused) {
                commentView.visibility = View.GONE
                commentReadView.visibility = View.VISIBLE
            }
        }

        commentView.addTextChangedListener(object : TextWatcher {
            override fun onTextChanged(s: CharSequence, start: Int, before: Int, count: Int) {
                comment = s.toString()
            }

            override fun afterTextChanged(s: Editable) {}
            override fun beforeTextChanged(s: CharSequence, start: Int, count: Int, after: Int) {}
        })
    }

    private fun updateError() {
        if (showError && !correct) {
            errorView.visibility = View.VISIBLE
            filters = listOf()
        }
        else {
            errorView.visibility = View.GONE
        }
    }

}
