package core

import android.content.Context
import android.graphics.Rect
import androidx.core.view.GestureDetectorCompat
import androidx.core.view.ViewCompat
import androidx.customview.widget.ViewDragHelper
import android.util.AttributeSet
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import org.blokada.R

class PanelLayout(
        ctx: Context,
        val attributeSet: AttributeSet
) : ViewGroup(ctx, attributeSet) {

    interface SwipeListener {
        fun onClosed(view: PanelLayout)
        fun onOpened(view: PanelLayout)
        fun onSlide(view: PanelLayout, slideOffset: Float)
    }

    private data class ViewRect(val closed: Rect = Rect(), val opened: Rect = Rect())

    private lateinit var mainView: View
    private lateinit var leftView: View
    private lateinit var topView: View
    private lateinit var rightView: View
    private lateinit var bottomView: View

    private val main = ViewRect()
    private val left = ViewRect()
    private val top = ViewRect()
    private val right = ViewRect()
    private val bottom = ViewRect()

    private var viewWidth: Int = 0
    private var viewHeight: Int = 0

    /**
     * The minimum distance (px) to the closest drag edge that the PanelLayout
     * will disallow the parent to intercept touch event.
     */
    private var minDistRequestDisallowParent = 0
    private var minFlingVelocity = DEFAULT_MIN_FLING_VELOCITY

    private var isOpenBeforeInit = false
    private var aborted = false
    private var isScrolling = false
    private var isDragLocked = false

    private var state = STATE_CLOSE

    private var lastMainLeft = 0
    private var lastMainTop = 0

    private var dragging = Dragging.NONE
    private var dragDist = 0f
    private var prevX = -1f
    private var prevY = -1f

    private lateinit var dragHelper: ViewDragHelper
    private lateinit var gestureDetector: GestureDetectorCompat

    private var dragStateChangeListener: DragStateChangeListener? = null // only used for ViewBindHelper
    private var swipeListener: SwipeListener? = null

    private var onLayoutCount = 0

    private val dragHelperCallback = object : ViewDragHelper.Callback() {

        private fun halfwayPivotHorizontal() = when(dragging) {
            Dragging.LEFT -> main.closed.left + viewWidth / 2
            else -> main.closed.right - viewWidth / 2
        }

        private fun halfwayPivotVertical() = when(dragging) {
            Dragging.TOP -> main.closed.top + viewHeight / 2
            else -> main.closed.bottom - viewHeight / 2
        }

        override fun tryCaptureView(child: View, pointerId: Int): Boolean {
            aborted = false
            if (isDragLocked) return false
            dragHelper.captureChildView(mainView, pointerId)
            return false
        }

        override fun clampViewPositionVertical(child: View, top: Int, dy: Int): Int {
            dragging = when {
                dragging != Dragging.NONE -> dragging
                top > 0 -> Dragging.TOP
                top < 0 -> Dragging.BOTTOM
                else -> Dragging.NONE
            }

            return when (dragging) {
                Dragging.TOP -> Math.max(
                        Math.min(top, main.closed.top + viewHeight),
                        main.closed.top
                )
                Dragging.BOTTOM -> Math.max(
                        Math.min(top, main.closed.top),
                        main.closed.top - viewHeight
                )
                else -> child.top
            }
        }

        override fun clampViewPositionHorizontal(child: View, left: Int, dx: Int): Int {
            dragging = when {
                dragging != Dragging.NONE -> dragging
                left > 0 -> Dragging.LEFT
                left < 0 -> Dragging.RIGHT
                else -> Dragging.NONE
            }

            return when (dragging) {
                Dragging.RIGHT -> Math.max(
                        Math.min(left, main.closed.left),
                        main.closed.left - viewWidth
                )
                Dragging.LEFT -> return Math.max(
                        Math.min(left, main.closed.left + viewWidth),
                        main.closed.left
                )
                else -> child.left
            }
        }

        override fun onViewReleased(releasedChild: View, xvel: Float, yvel: Float) {
            val velRightExceeded = context.pxToDp(xvel.toInt()) >= minFlingVelocity
            val velLeftExceeded = context.pxToDp(xvel.toInt()) <= -minFlingVelocity
            val velUpExceeded = context.pxToDp(yvel.toInt()) <= -minFlingVelocity
            val velDownExceeded = context.pxToDp(yvel.toInt()) >= minFlingVelocity

            val pivotHorizontal = halfwayPivotHorizontal()
            val pivotVertical = halfwayPivotVertical()

            when {
                dragging == Dragging.RIGHT && velRightExceeded -> close(true)
                dragging == Dragging.RIGHT && velLeftExceeded -> open(true)
                dragging == Dragging.RIGHT && mainView.right < pivotHorizontal -> open(true)
                dragging == Dragging.RIGHT -> close(true)

                dragging == Dragging.LEFT && velRightExceeded -> open(true)
                dragging == Dragging.LEFT && velLeftExceeded -> close(true)
                dragging == Dragging.LEFT && mainView.left < pivotHorizontal -> close(true)
                dragging == Dragging.LEFT -> open(true)

                dragging == Dragging.TOP && velUpExceeded -> close(true)
                dragging == Dragging.TOP && velDownExceeded -> open(true)
                dragging == Dragging.TOP && mainView.top < pivotVertical -> close(true)
                dragging == Dragging.TOP -> open(true)

                dragging == Dragging.BOTTOM && velUpExceeded -> open(true)
                dragging == Dragging.BOTTOM && velDownExceeded -> close(true)
                dragging == Dragging.BOTTOM && mainView.bottom < pivotVertical -> open(true)
                dragging == Dragging.BOTTOM -> close(true)
            }
        }

        override fun onEdgeDragStarted(edgeFlags: Int, pointerId: Int) {
            super.onEdgeDragStarted(edgeFlags, pointerId)
            if (isDragLocked) return

            val edgeStartLeft = dragging == Dragging.LEFT && edgeFlags == ViewDragHelper.EDGE_LEFT
            val edgeStartRight = dragging == Dragging.RIGHT && edgeFlags == ViewDragHelper.EDGE_RIGHT
            val edgeStartTop = dragging == Dragging.TOP && edgeFlags == ViewDragHelper.EDGE_TOP
            val edgeStartBottom = dragging == Dragging.BOTTOM && edgeFlags == ViewDragHelper.EDGE_BOTTOM

            if (edgeStartLeft || edgeStartRight || edgeStartTop || edgeStartBottom) {
                dragHelper.captureChildView(mainView, pointerId)
            }
        }

        override fun onViewPositionChanged(changedView: View, left: Int, top: Int, dx: Int, dy: Int) {
            super.onViewPositionChanged(changedView, left, top, dx, dy)
            when (dragging) {
                Dragging.LEFT -> leftView.offsetLeftAndRight(dx)
                Dragging.RIGHT -> rightView.offsetLeftAndRight(dx)
                Dragging.TOP -> topView.offsetTopAndBottom(dy)
                Dragging.BOTTOM -> bottomView.offsetTopAndBottom(dy)
            }

            val isMoved = mainView.left != lastMainLeft || mainView.top != lastMainTop
            if (swipeListener != null && isMoved) {
                if (mainView.left == main.closed.left && mainView.top == main.closed.top) {
                    swipeListener!!.onClosed(this@PanelLayout)
                } else if (mainView.left == main.opened.left && mainView.top == main.opened.top) {
                    swipeListener!!.onOpened(this@PanelLayout)
                } else {
                    swipeListener!!.onSlide(this@PanelLayout, getSlideOffset())
                }
            }

            lastMainLeft = mainView.left
            lastMainTop = mainView.top
            ViewCompat.postInvalidateOnAnimation(this@PanelLayout)
        }

        override fun onViewDragStateChanged(state: Int) {
            super.onViewDragStateChanged(state)
            val prevState = this@PanelLayout.state

            when (state) {
                ViewDragHelper.STATE_DRAGGING -> this@PanelLayout.state = STATE_DRAGGING
                ViewDragHelper.STATE_IDLE ->
                    this@PanelLayout.state = if (dragging in listOf(Dragging.LEFT, Dragging.RIGHT)) {
                        if (mainView.left == main.closed.left) {
                            dragging = Dragging.NONE
                            STATE_CLOSE
                        }
                        else STATE_OPEN
                    } else {
                        if (mainView.top == main.closed.top) {
                            dragging = Dragging.NONE
                            STATE_CLOSE
                        }
                        else STATE_OPEN
                    }
            }

            if (dragStateChangeListener != null && !aborted && prevState != this@PanelLayout.state) {
                dragStateChangeListener!!.onDragStateChanged(this@PanelLayout.state)
            }
        }
    }

    private val mGestureListener = object : GestureDetector.SimpleOnGestureListener() {
        internal var hasDisallowed = false

        override fun onDown(e: MotionEvent): Boolean {
            isScrolling = false
            hasDisallowed = false
            return true
        }

        override fun onFling(e1: MotionEvent, e2: MotionEvent, velocityX: Float, velocityY: Float): Boolean {
            isScrolling = true
            return false
        }

        override fun onScroll(e1: MotionEvent, e2: MotionEvent, distanceX: Float, distanceY: Float): Boolean {
            isScrolling = true

            if (parent != null) {
                val shouldDisallow: Boolean

                if (!hasDisallowed) {
//                    shouldDisallow = distToClosestEdge >= minDistRequestDisallowParent
//                    if (shouldDisallow) {
//                        hasDisallowed = true
//                    }
                    shouldDisallow = false
                } else {
                    shouldDisallow = true
                }

                // disallow parent to intercept touch event so that the layout will work
                // properly on RecyclerView or view that handles scroll gesture.
                parent.requestDisallowInterceptTouchEvent(shouldDisallow)
            }

            return false
        }
    }

    init {
        val a = context.theme.obtainStyledAttributes(
                attributeSet,
                R.styleable.PanelLayout,
                0, 0
        )

        minFlingVelocity = a.getInteger(R.styleable.PanelLayout_flingVelocity, DEFAULT_MIN_FLING_VELOCITY)

        minDistRequestDisallowParent = a.getDimensionPixelSize(
                R.styleable.PanelLayout_minDistRequestDisallowParent,
                context.dpToPx(DEFAULT_MIN_DIST_REQUEST_DISALLOW_PARENT)
        )

        dragHelper = ViewDragHelper.create(this, 1.0f, dragHelperCallback)
        dragHelper.setEdgeTrackingEnabled(ViewDragHelper.EDGE_ALL)

        gestureDetector = GestureDetectorCompat(context, mGestureListener)
    }

    override fun onFinishInflate() {
        super.onFinishInflate()

        if (childCount >= 5) {
            leftView = getChildAt(0)
            topView = getChildAt(1)
            rightView = getChildAt(2)
            bottomView = getChildAt(3)
            mainView = getChildAt(4)
        } else if (childCount == 1) {
            mainView = getChildAt(0)
        }
    }

    override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
        aborted = false

        for (index in 0 until childCount) {
            val child = getChildAt(index)
            var (left, right, top, bottom) = listOf(0, 0, 0, 0)

            val minLeft = paddingLeft
            val maxRight = Math.max(r - paddingRight - l, 0)
            val minTop = paddingTop
            val maxBottom = Math.max(b - paddingBottom - t, 0)

            var measuredChildHeight = child.measuredHeight
            var measuredChildWidth = child.measuredWidth

            // need to take account if child size is match_parent
            val childParams = child.layoutParams
            var matchParentHeight = false
            var matchParentWidth = false

            if (childParams != null) {
                matchParentHeight = childParams.height == ViewGroup.LayoutParams.MATCH_PARENT || childParams.height == ViewGroup.LayoutParams.FILL_PARENT
                matchParentWidth = childParams.width == ViewGroup.LayoutParams.MATCH_PARENT || childParams.width == ViewGroup.LayoutParams.FILL_PARENT
            }

            if (matchParentHeight) {
                measuredChildHeight = maxBottom - minTop
                childParams!!.height = measuredChildHeight
            }

            if (matchParentWidth) {
                measuredChildWidth = maxRight - minLeft
                childParams!!.width = measuredChildWidth
            }

//            when (dragEdge) {
//                DRAG_EDGE_RIGHT -> {
            left = Math.max(r - measuredChildWidth - paddingRight - l, minLeft)
            top = Math.min(paddingTop, maxBottom)
            right = Math.max(r - paddingRight - l, minLeft)
            bottom = Math.min(measuredChildHeight + paddingTop, maxBottom)
//                }
//
//                DRAG_EDGE_LEFT -> {
//                    left = Math.min(paddingLeft, maxRight)
//                    top = Math.min(paddingTop, maxBottom)
//                    right = Math.min(measuredChildWidth + paddingLeft, maxRight)
//                    bottom = Math.min(measuredChildHeight + paddingTop, maxBottom)
//                }
//
//                DRAG_EDGE_TOP -> {
//                    left = Math.min(paddingLeft, maxRight)
//                    top = Math.min(paddingTop, maxBottom)
//                    right = Math.min(measuredChildWidth + paddingLeft, maxRight)
//                    bottom = Math.min(measuredChildHeight + paddingTop, maxBottom)
//                }
//
//                DRAG_EDGE_BOTTOM -> {
//                    left = Math.min(paddingLeft, maxRight)
//                    top = Math.max(b - measuredChildHeight - paddingBottom - t, minTop)
//                    right = Math.min(measuredChildWidth + paddingLeft, maxRight)
//                    bottom = Math.max(b - paddingBottom - t, minTop)
//                }
//            }

            child.layout(left, top, right, bottom)
        }

        leftView.offsetLeftAndRight(-leftView.width)
        rightView.offsetLeftAndRight(rightView.width)
        topView.offsetTopAndBottom(-topView.height)
        bottomView.offsetTopAndBottom(bottomView.height)

        viewWidth = mainView.width
        viewHeight = mainView.height

        initRects()
        updateMainRect()
        updateLeftRect()
        updateRightRect()
        updateTopRect()
        updateBottomRect()

        if (isOpenBeforeInit) open(false)
        else close(false)

        lastMainLeft = mainView.left
        lastMainTop = mainView.top

        onLayoutCount++
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        var widthMeasureSpec = widthMeasureSpec
        var heightMeasureSpec = heightMeasureSpec
        if (childCount < 5) {
            throw RuntimeException("Layout must have five children")
        }

        val params = layoutParams

        val widthMode = View.MeasureSpec.getMode(widthMeasureSpec)
        val heightMode = View.MeasureSpec.getMode(heightMeasureSpec)

        var desiredWidth = 0
        var desiredHeight = 0

        // first find the largest child
        for (i in 0 until childCount) {
            val child = getChildAt(i)
            measureChild(child, widthMeasureSpec, heightMeasureSpec)
            desiredWidth = Math.max(child.measuredWidth, desiredWidth)
            desiredHeight = Math.max(child.measuredHeight, desiredHeight)
        }
        // create new measure spec using the largest child width
        widthMeasureSpec = View.MeasureSpec.makeMeasureSpec(desiredWidth, widthMode)
        heightMeasureSpec = View.MeasureSpec.makeMeasureSpec(desiredHeight, heightMode)

        val measuredWidth = View.MeasureSpec.getSize(widthMeasureSpec)
        val measuredHeight = View.MeasureSpec.getSize(heightMeasureSpec)

        for (i in 0 until childCount) {
            val child = getChildAt(i)
            val childParams = child.layoutParams

            if (childParams != null) {
                if (childParams.height == ViewGroup.LayoutParams.MATCH_PARENT) {
                    child.minimumHeight = measuredHeight
                }

                if (childParams.width == ViewGroup.LayoutParams.MATCH_PARENT) {
                    child.minimumWidth = measuredWidth
                }
            }

            measureChild(child, widthMeasureSpec, heightMeasureSpec)
            desiredWidth = Math.max(child.measuredWidth, desiredWidth)
            desiredHeight = Math.max(child.measuredHeight, desiredHeight)
        }

        // taking accounts of padding
        desiredWidth += paddingLeft + paddingRight
        desiredHeight += paddingTop + paddingBottom

        // adjust desired width
        if (widthMode == View.MeasureSpec.EXACTLY) {
            desiredWidth = measuredWidth
        } else {
            if (params.width == ViewGroup.LayoutParams.MATCH_PARENT) {
                desiredWidth = measuredWidth
            }

            if (widthMode == View.MeasureSpec.AT_MOST) {
                desiredWidth = if (desiredWidth > measuredWidth) measuredWidth else desiredWidth
            }
        }

        // adjust desired height
        if (heightMode == View.MeasureSpec.EXACTLY) {
            desiredHeight = measuredHeight
        } else {
            if (params.height == ViewGroup.LayoutParams.MATCH_PARENT) {
                desiredHeight = measuredHeight
            }

            if (heightMode == View.MeasureSpec.AT_MOST) {
                desiredHeight = if (desiredHeight > measuredHeight) measuredHeight else desiredHeight
            }
        }

        setMeasuredDimension(desiredWidth, desiredHeight)
    }

    private fun updateMainRect() {
        val l = when (dragging) {
            Dragging.LEFT -> main.closed.left + viewWidth
            Dragging.RIGHT -> main.closed.left - viewWidth
            else -> main.closed.left
        }

        val t= when (dragging) {
            Dragging.TOP -> main.closed.top + viewHeight
            Dragging.BOTTOM -> main.closed.top - viewHeight
            else -> main.closed.top
        }

        main.opened.left = l
        main.opened.top = t
    }

    private fun updateLeftRect() {
        val l = when (dragging) {
            Dragging.LEFT -> left.closed.left + viewWidth
            Dragging.RIGHT -> left.closed.left - viewWidth
            else -> left.closed.left
        }

        val t = when (dragging) {
            Dragging.TOP -> left.closed.top + viewHeight
            Dragging.BOTTOM -> left.closed.top - viewHeight
            else -> left.closed.top
        }

        left.opened.left = l
        left.opened.top = t
    }

    private fun updateRightRect() {
        val l = when (dragging) {
            Dragging.LEFT -> right.closed.left - viewWidth
            Dragging.RIGHT -> right.closed.left + viewWidth
            else -> right.closed.left
        }

        val t = when (dragging) {
            Dragging.TOP -> right.closed.top + viewHeight
            Dragging.BOTTOM -> right.closed.top - viewHeight
            else -> right.closed.top
        }

        right.opened.left = l
        right.opened.top = t
    }

    private fun updateTopRect() {
        val l = when (dragging) {
            Dragging.LEFT -> top.closed.left - viewWidth
            Dragging.RIGHT -> top.closed.left + viewWidth
            else -> top.closed.left
        }

        val t = when (dragging) {
            Dragging.TOP -> top.closed.top + viewHeight
            Dragging.BOTTOM -> top.closed.top - viewHeight
            else -> top.closed.top
        }

        top.opened.left = l
        top.opened.top = t
    }

    private fun updateBottomRect() {
        val l = when (dragging) {
            Dragging.LEFT -> bottom.closed.left - viewWidth
            Dragging.RIGHT -> bottom.closed.left + viewWidth
            else -> bottom.closed.left
        }

        val t = when (dragging) {
            Dragging.TOP -> bottom.closed.top + viewHeight
            Dragging.BOTTOM -> bottom.closed.top - viewHeight
            else -> bottom.closed.top
        }

        bottom.opened.left = l
        bottom.opened.top = t
    }

    private fun getSlideOffset() = when (dragging) {
        Dragging.LEFT -> (mainView.left - main.closed.left).toFloat() / viewWidth
        Dragging.RIGHT -> (main.closed.left - mainView.left).toFloat() / viewWidth
        Dragging.TOP -> (mainView.top - main.closed.top).toFloat() / viewHeight
        Dragging.BOTTOM -> (main.closed.top - mainView.top).toFloat() / viewHeight
        else -> 0f
    }

    internal interface DragStateChangeListener {
        fun onDragStateChanged(state: Int)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        gestureDetector.onTouchEvent(event)
        dragHelper.processTouchEvent(event)
        return true
    }

    override fun onInterceptTouchEvent(ev: MotionEvent): Boolean {
        if (isDragLocked) return super.onInterceptTouchEvent(ev)

        dragHelper.processTouchEvent(ev)
        gestureDetector.onTouchEvent(ev)
        accumulateDragDist(ev)

        val couldBecomeClick = couldBecomeClick(ev)
        val settling = dragHelper.viewDragState == ViewDragHelper.STATE_SETTLING
        val idleAfterScrolled = dragHelper.viewDragState == ViewDragHelper.STATE_IDLE && isScrolling

        // must be placed as the last statement
        prevX = ev.x
        prevY = ev.y

        // return true => intercept, cannot trigger onClick event
        return !couldBecomeClick && (settling || idleAfterScrolled)
    }


    override fun computeScroll() {
        if (dragHelper.continueSettling(true)) {
            ViewCompat.postInvalidateOnAnimation(this)
        }
    }

    fun open(animation: Boolean) {
        isOpenBeforeInit = true
        aborted = false

        updateMainRect()
        updateLeftRect()
        updateRightRect()
        updateTopRect()
        updateBottomRect()

        if (animation) {
            state = STATE_OPENING
            dragHelper.smoothSlideViewTo(mainView, main.opened.left, main.opened.top)
            dragStateChangeListener?.apply { onDragStateChanged(state) }
        } else {
            state = STATE_OPEN
            dragHelper.abort()

            mainView.layout(
                    main.opened.left, main.opened.top,
                    main.opened.right, main.opened.bottom
            )

            leftView.layout(
                    left.opened.left, left.opened.top,
                    left.opened.right, left.opened.bottom
            )

            rightView.layout(
                    right.opened.left, right.opened.top,
                    right.opened.right, right.opened.bottom
            )

            topView.layout(
                    top.closed.left, top.closed.top,
                    top.closed.right, top.closed.bottom
            )

            bottomView.layout(
                    bottom.closed.left, bottom.closed.top,
                    bottom.closed.right, bottom.closed.bottom
            )
        }

        ViewCompat.postInvalidateOnAnimation(this@PanelLayout)
    }

    fun close(animation: Boolean) {
        isOpenBeforeInit = false
        aborted = false

        if (animation) {
            state = STATE_CLOSING
            dragHelper.smoothSlideViewTo(mainView, main.closed.left, main.closed.top)
            dragStateChangeListener?.apply { onDragStateChanged(state) }
        } else {
            state = STATE_CLOSE
            dragHelper.abort()
            dragging = Dragging.NONE

            mainView.layout(
                    main.closed.left, main.closed.top,
                    main.closed.right, main.closed.bottom
            )

            leftView.layout(
                    left.closed.left, left.closed.top,
                    left.closed.right, left.closed.bottom
            )

            rightView.layout(
                    right.closed.left, right.closed.top,
                    right.closed.right, right.closed.bottom
            )

            topView.layout(
                    top.closed.left, top.closed.top,
                    top.closed.right, top.closed.bottom
            )

            bottomView.layout(
                    bottom.closed.left, bottom.closed.top,
                    bottom.closed.right, bottom.closed.bottom
            )
        }

        ViewCompat.postInvalidateOnAnimation(this@PanelLayout)
    }

    fun setSwipeListener(listener: SwipeListener) {
        swipeListener = listener
    }

    fun setLockDrag(lock: Boolean) {
        isDragLocked = lock
    }

    internal fun setDragStateChangeListener(listener: DragStateChangeListener) {
        dragStateChangeListener = listener
    }

    protected fun abort() {
        aborted = true
        dragHelper.abort()
    }

    /**
     * In RecyclerView/ListView, onLayout should be called 2 times to display children views correctly.
     * This method check if it've already called onLayout two times.
     *
     * @return true if you should call [.requestLayout].
     */
    protected fun shouldRequestLayout(): Boolean {
        return onLayoutCount < 2
    }

    private fun initRects() {
        main.closed.set(
                mainView.left, mainView.top,
                mainView.right, mainView.bottom
        )

        left.closed.set(
                leftView.left, leftView.top,
                leftView.right, leftView.bottom
        )

        right.closed.set(
                rightView.left, rightView.top,
                rightView.right, rightView.bottom
        )

        top.closed.set(
                topView.left, topView.top,
                topView.right, topView.bottom
        )

        bottom.closed.set(
                bottomView.left, bottomView.top,
                bottomView.right, bottomView.bottom
        )
    }

//    private fun setOpenPositions() {
//        // open position of the main view
//        mRectMainOpen.set(
//                mainOpenLeft,
//                mainOpenTop,
//                mainOpenLeft + mainView!!.width,
//                mainOpenTop + mainView!!.height
//        )
//
//        // open position of the secondary view
//        mRectSecOpen.set(
//                secOpenLeft,
//                secOpenTop,
//                secOpenLeft + leftView!!.width,
//                secOpenTop + leftView!!.height
//        )
//    }

    private fun couldBecomeClick(ev: MotionEvent): Boolean {
        return isInMainView(ev) && !shouldInitiateADrag()
    }

    private fun isInMainView(ev: MotionEvent): Boolean {
        val x = ev.x
        val y = ev.y

        val withinVertical = mainView!!.top <= y && y <= mainView!!.bottom
        val withinHorizontal = mainView!!.left <= x && x <= mainView!!.right

        return withinVertical && withinHorizontal
    }

    private fun shouldInitiateADrag(): Boolean {
        val minDistToInitiateDrag = dragHelper!!.touchSlop.toFloat()
        return dragDist >= minDistToInitiateDrag
    }

    private fun accumulateDragDist(ev: MotionEvent) {
        val action = ev.action
        if (action == MotionEvent.ACTION_DOWN) {
            dragDist = 0f
            return
        }

        val dragged = if (dragging in listOf(Dragging.LEFT, Dragging.RIGHT))
            Math.abs(ev.x - prevX)
        else Math.abs(ev.y - prevY)

        dragDist += dragged
    }

    companion object {

        // These states are used only for ViewBindHelper
        protected val STATE_CLOSE = 0
        protected val STATE_CLOSING = 1
        protected val STATE_OPEN = 2
        protected val STATE_OPENING = 3
        protected val STATE_DRAGGING = 4

        private val DEFAULT_MIN_FLING_VELOCITY = 300 // dp per second
        private val DEFAULT_MIN_DIST_REQUEST_DISALLOW_PARENT = 1 // dp

        enum class Dragging {
            NONE, LEFT, RIGHT, TOP, BOTTOM
        }

    }
}
