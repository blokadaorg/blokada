package filter

interface IHostlineProcessor {
    fun process(listtype: Boolean, line: String): String?
}

class DefaultHostlineProcessor: IHostlineProcessor {
    override fun process(listtype: Boolean, line: String): String? {
        //android.util.Log.d("String124 is " , "listtype is "+listtype + " line is " + line)
        var l = line
        if (l.startsWith("#")) return null
        if (l.startsWith("<")) return null
        l = l.replaceFirst("0.0.0.0 ", "")
        l = l.replaceFirst("127.0.0.1 ", "")
        l = l.replaceFirst("127.0.0.1	", "")
        l = l.trim()
        //android.util.Log.d("String 124 is " , "l is "+l)
        if (l.isEmpty()) return null
        if (listtype == false){
            //android.util.Log.d("String128 is " , "" + l)
            return l
        } // if it is a wildcard list don't null it for not being a full web domain name i.e. not ending in .com
        else if (!hostnameRegex.containsMatchIn(l)) {
            //android.util.Log.d("String124 is " , " returning null"+l)

            return null

        }
        return l
    }
}

