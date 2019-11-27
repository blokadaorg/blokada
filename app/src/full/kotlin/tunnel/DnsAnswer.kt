package tunnel

import core.get
import org.xbill.DNS.*
import java.net.InetAddress

/*
persistence for the setting, which determines which type of answer Blokada will give if a domain is blocked.
If hostNotFoundAnswer is true it will send the "classic" deny response. If it's false Blokada will instead
send a answer resolving the blocked domain to 127.1.1.1 .
*/
data class DnsAnswerState(
        val hostNotFoundAnswer: Boolean
)

fun generateDnsAnswer(dnsMessage: Message, denyResponse: SOARecord){
    if(get(DnsAnswerState::class.java).hostNotFoundAnswer){
        dnsMessage.addRecord(denyResponse, Section.AUTHORITY)
    }else{
        dnsMessage.addRecord(
                ARecord(Name(dnsMessage.question.name.toString(false)),
                        DClass.IN,
                        5, //5 sec ttl
                        InetAddress.getByAddress(byteArrayOf(127, 1, 1, 1))),
                Section.ANSWER
        )
    }
}