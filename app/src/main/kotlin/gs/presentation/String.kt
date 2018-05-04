package gs.presentation

fun String.nullIfEmpty(): String? {
    return if (this.isEmpty()) null else this
}