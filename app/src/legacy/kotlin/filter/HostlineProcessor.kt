package filter

interface IHostlineProcessor {
    fun process(listtype: Boolean, line: String): String?
}

class DefaultHostlineProcessor: IHostlineProcessor {
    override fun process(listtype: Boolean, line: String): String? {
        var l = line
        if (l.startsWith("#")) return null
        if (l.startsWith("<")) return null
        l = l.replaceFirst("0.0.0.0 ", "")
        l = l.replaceFirst("127.0.0.1 ", "")
        l = l.replaceFirst("127.0.0.1	", "")
        l = l.trim()
        if (l.isEmpty()) return null
        if (listtype == false){
            return l
        } // if it is a wildcard list don't null it for not being a full web domain name i.e. not ending in .com
        else if (!hostnameRegex.containsMatchIn(l)) {
            return null
        }
        return l
    }
}

