package filter

interface IHostlineProcessor {
    fun process(line: String): String?
}

class DefaultHostlineProcessor: IHostlineProcessor {
    override fun process(line: String): String? {
        var l = line
        if (l.startsWith("#")) return null
        if (l.startsWith("<")) return null
        l = l.replaceFirst(Regex("0\\.0\\.0\\.0[ \\t]"), "")
        l = l.replaceFirst(Regex("127\\.0\\.0\\.1[ \\t]"), "")
        l = l.substringBefore('#').trim()
        if (l.isEmpty()) return null
        if (!hostnameRegex.containsMatchIn(l)) return null
        return l
    }
}

