package org.blokada.presentation

import android.util.AttributeSet
import android.content.Context
import android.text.Editable
import android.text.TextWatcher
import android.view.View
import android.view.ViewGroup
import android.widget.AutoCompleteTextView
import android.widget.EditText
import android.widget.ScrollView
import android.widget.TextView
import org.blokada.property.hostnameRegex
import org.blokada.R

class AFiltersAddSingleView(
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
        private set(value) {
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

    override fun onFinishInflate() {
        super.onFinishInflate()
        updateError()

        editView.addTextChangedListener(object : TextWatcher {
            override fun onTextChanged(s: CharSequence, start: Int, before: Int, count: Int) {
                text = s.toString()
            }

            override fun afterTextChanged(s: Editable) {}
            override fun beforeTextChanged(s: CharSequence, start: Int, count: Int, after: Int) {}
        })

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

    private fun isTextCorrect(s: CharSequence): Boolean {
        return hostnameRegex.containsMatchIn(s.trim())
    }
}
