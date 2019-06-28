package core

import gs.presentation.NamedViewBinder


internal class DashboardNavigationModel(
        val sections: List<NamedViewBinder>,
        val menu: NamedViewBinder,
        val onChangeSection: (NamedViewBinder, sectionIndex: Int) -> Unit = { _, _ -> },
        val onChangeMenu: (NamedViewBinder?, NamedViewBinder?) -> Unit = { _, _ -> },
        val onBackSubmenu: () -> Unit = {},
        val onMenuClosed: (Int) -> Unit = {},
        val onOpenMenu: () -> Unit = {},
        val onCloseMenu: () -> Unit = {}
) {

    private var sectionIndex = 0
    private var section = sections[sectionIndex]

    private var menuOpened: NamedViewBinder? = null
    private var submenuOpened: NamedViewBinder? = null
    private var secondarySubmenuOpened: NamedViewBinder? = null

    private var slotSelected: Navigable? = null
    private var slotOpened = false

    init {
        (section as? ListSection)?.run {
            setOnSelected { slot ->
                slotSelected = slot
                slotOpened = false
            }
        }
    }

    fun menuClosed() {
        menuOpened = null
        submenuOpened = null
        secondarySubmenuOpened = null
        onMenuClosed(sectionIndex)
    }

    fun menuOpened() {
        menuOpened = menu

        val activeMenu = secondarySubmenuOpened ?: submenuOpened ?: menu
        slotOpened = false
        slotSelected = null
        (activeMenu as? ListSection)?.run {
            setOnSelected { slot ->
                slotSelected = slot
                slotOpened = false
            }
        }

        onChangeMenu(submenuOpened, secondarySubmenuOpened)
    }

    fun menuItemClicked(item: NamedViewBinder) {
        when {
            menuOpened == null -> {
                menuOpened = menu
                submenuOpened = item
                secondarySubmenuOpened = null
                onChangeMenu(submenuOpened, secondarySubmenuOpened)
            }
            submenuOpened == null || submenuOpened == item -> {
                submenuOpened = item
                secondarySubmenuOpened = null
//                onOpenSubmenu(item)
                onChangeMenu(submenuOpened, secondarySubmenuOpened)
            }
            else -> {
                secondarySubmenuOpened = item
//                onOpenSubmenu(item)
                onChangeMenu(submenuOpened, secondarySubmenuOpened)
            }
        }

        val activeMenu = secondarySubmenuOpened ?: submenuOpened ?: menu
        slotOpened = false
        slotSelected = null
        (activeMenu as? ListSection)?.run {
            setOnSelected { slot ->
                slotSelected = slot
                slotOpened = false
            }
        }

    }

    fun mainViewPagerSwiped(position: Int) {
        if (position != sectionIndex) {
            sectionIndex = position
            setNewSection(sections[sectionIndex])
        }
    }

    fun mainViewPagerSwipedRight() {
        if (sectionIndex < sections.size - 2) mainViewPagerSwiped(sectionIndex + 1)
    }

    fun mainViewPagerSwipedLeft() {
        if (sectionIndex > 0) mainViewPagerSwiped(sectionIndex - 1)
    }

    fun menuViewPagerSwiped(position: Int) {
        when {
            position == 0 && submenuOpened != null -> {
                submenuOpened = null
                secondarySubmenuOpened = null
                onChangeMenu(submenuOpened, secondarySubmenuOpened)
//                onBackSubmenu()
            }
            position == 1 && secondarySubmenuOpened != null -> {
                secondarySubmenuOpened = null
                onChangeMenu(submenuOpened, secondarySubmenuOpened)
//                onBackSubmenu()
            }
        }
    }

    fun selectKey() {
        val item = slotSelected
        when {
            item is SlotVB && !slotOpened -> {
                setSlotOpened(true)
            }
            item is SlotVB -> {
                setSlotOpened(false)
            }
            item is Navigable -> {
                // Immediately "click" on the non-foldable items
                item.enter()
            }
            menuOpened == null -> {
                onOpenMenu()
            }
        }
    }

    fun backPressed(): Boolean {
        val item = slotSelected
        return when {
            item is Navigable && slotOpened -> {
                setSlotOpened(false)
                true
            }
            item is Navigable -> {
                setSlotUnselected()
                true
            }
            secondarySubmenuOpened != null -> {
                onBackSubmenu()
                true
            }
            submenuOpened != null -> {
                onBackSubmenu()
                true
            }
            menuOpened != null -> {
                onCloseMenu()
                true
            }
            sectionIndex > 0 -> {
                setNewSection(sections[--sectionIndex])
                true
            }
            else -> {
                false
            }
        }
    }

    fun leftKey() {
        val item = slotSelected
        when {
            item is Navigable && slotOpened -> {
                setSlotOpened(false)
                item.left()
            }
            item is Navigable -> {
                setSlotUnselected()
            }
            secondarySubmenuOpened != null -> {
                onBackSubmenu()
            }
            submenuOpened != null -> {
                onBackSubmenu()
            }
            menuOpened != null -> {
                onCloseMenu()
            }
            menuOpened == null && sectionIndex > 0 -> {
                sectionIndex--
                val newSection = sections[sectionIndex]
                setNewSection(newSection)
                section = newSection
            }
        }
    }

    fun rightKey() {
        val item = slotSelected
        when {
            item is Navigable && slotOpened -> {
                setSlotOpened(false)
                item.right()
            }
            menuOpened == null && sectionIndex < sections.size - 1 -> {
                sectionIndex++
                val newSection = sections[sectionIndex]
                setNewSection(newSection)
                section = newSection
            }
        }
    }

    fun upKey() {
        val item = slotSelected
        val menu = secondarySubmenuOpened ?: submenuOpened ?: menuOpened
        when {
            item is Navigable && slotOpened -> {
                setSlotOpened(false)
                item.up()
            }
            menu != null -> {
                (menu as? ListSection)?.apply {
                    selectPrevious()
                }
            }
            else -> {
                (section as? ListSection)?.apply {
                    selectPrevious()
                }
            }
        }
    }

    fun downKey() {
        val item = slotSelected
        val menu = secondarySubmenuOpened ?: submenuOpened ?: menuOpened
        when {
            item is Navigable && slotOpened -> {
                setSlotOpened(false)
                item.down()
            }
            menu != null -> {
                (menu as? ListSection)?.apply {
                    selectNext()
                }
            }
            else -> {
                (section as? ListSection)?.apply {
                    selectNext()
                }
            }
        }
    }

    private fun setNewSection(section: NamedViewBinder) {
        this.section = section
        slotOpened = false
        slotSelected = null
        (section as? ListSection)?.run {
            setOnSelected { slot ->
                slotSelected = slot
                slotOpened = false
            }
        }
        onChangeSection(section, sectionIndex)
    }

    private fun setSlotOpened(opened: Boolean) {
        slotOpened = opened
        if (opened) {
            slotSelected?.enter()
            val menu = secondarySubmenuOpened ?: submenuOpened ?: menuOpened
            if (menu != null) {
                (menu as? ListSection)?.run {
                    scrollToSelected()
                }
            } else {
                (section as? ListSection)?.run {
                    scrollToSelected()
                }
            }
        } else {
            slotSelected?.exit()
        }
    }

    private fun setSlotUnselected() {
        val menu = secondarySubmenuOpened ?: submenuOpened ?: menuOpened
        if (menu != null) {
            (menu as? ListSection)?.run {
                unselect()
            }
        } else {
            (section as? ListSection)?.run {
                unselect()
            }
        }
        slotSelected = null
        slotOpened = false
    }

    fun getOpenedSection() = section

    fun getOpenedSectionIndex() = {
        val section = getOpenedSection()
        when (section) {
            null -> -1
            else -> sections.indexOf(section)
        }
    }()

}
