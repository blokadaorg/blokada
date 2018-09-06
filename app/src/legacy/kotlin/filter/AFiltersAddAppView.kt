package filter

import android.content.Context
import android.text.Editable
import android.text.TextWatcher
import android.util.AttributeSet
import android.view.View
import android.view.ViewGroup
import android.widget.*
import com.github.salomonbrys.kodein.instance
import core.Filters
import gs.environment.inject
import org.blokada.R

class AFiltersAddAppView(
        ctx: Context,
        attributeSet: AttributeSet
) : ScrollView(ctx, attributeSet) {

    var text = ""
        get() { return field.trim() }
        set(value) {
            field = value
            if (editView.text.toString() != value) {
                editView.setText(value)
                editView.setSelection(value.length)
            }
            correct = isTextCorrect(value)
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
        commentView.visibility = View.GONE
        commentReadView.visibility = View.VISIBLE
    }

    private val editView by lazy { findViewById(R.id.filter_edit) as AutoCompleteTextView }
    private val errorView by lazy { findViewById(R.id.filter_error) as ViewGroup }
    private val commentView by lazy { findViewById(R.id.filter_comment) as EditText }
    private val commentReadView by lazy { findViewById(R.id.filter_comment_read) as TextView }
    private val commentGroupView by lazy { findViewById(R.id.filter_comment_group) as ViewGroup }

    private val adapter by lazy { ArrayAdapter<String>(ctx, android.R.layout.simple_dropdown_item_1line, appNames)}

    override fun onFinishInflate() {
        super.onFinishInflate()
        updateError()

        editView.addTextChangedListener(object : TextWatcher {
            override fun onTextChanged(s: CharSequence, start: Int, before: Int, count: Int) {
                if (s.contains(" | ")) text = s.substring(s.lastIndexOf(" | ") + 3)
                else text = s.toString()
            }

            override fun afterTextChanged(s: Editable) {}
            override fun beforeTextChanged(s: CharSequence, start: Int, count: Int, after: Int) {}
        })
        editView.setAdapter(adapter)

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
            commentGroupView.visibility = View.GONE
        }
        else {
            errorView.visibility = View.GONE
            commentGroupView.visibility = View.VISIBLE
        }
    }

    private val s by lazy { ctx.inject().instance<Filters>() }

    private val appNames by lazy {
        s.apps.refresh(blocking = true)
        s.apps().map { "${it.label} | ${it.appId}" }
    }

    private val appSearch by lazy {
        s.apps().flatMap { listOf(it.appId.toLowerCase(), it.label.toLowerCase()) }
    }

    private fun isTextCorrect(s: CharSequence): Boolean {
        return s.toString().toLowerCase() in appSearch
    }
}
