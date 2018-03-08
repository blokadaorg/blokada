package filter

interface IHostlineProcessor {
    fun process(line: String): String?
}

class DefaultHostlineProcessor: IHostlineProcessor {
    override fun process(line: String): String? {
        var l = line
        if (l.startsWith("#")) return null
        if (l.startsWith("<")) return null
        l = l.replaceFirst("0.0.0.0 ", "")
        l = l.replaceFirst("127.0.0.1 ", "")
        l = l.replaceFirst("127.0.0.1	", "")
        l = l.trim()
        if (l.isEmpty()) return null
        if (!hostnameRegex.containsMatchIn(l)) return null
        return l
    }
}

