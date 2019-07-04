package core

import gs.presentation.ViewTypeGenerator
import org.junit.Test

class ViewBinderTest {
    @Test fun viewTypeGenerator_basics() {
        val viewBinder1 = "vb1"
        val viewBinder2 = "vb2"
        val payload1 = "1"
        val payload2 = "2"
        val payload3 = 1

        val type1 = ViewTypeGenerator.get(viewBinder1)
        val type2 = ViewTypeGenerator.get(viewBinder2)
        val type11 = ViewTypeGenerator.get(viewBinder1, payload1)
        val type11_2 = ViewTypeGenerator.get(viewBinder1, payload1)
        val type12 = ViewTypeGenerator.get(viewBinder1, payload2)
        val type13 = ViewTypeGenerator.get(viewBinder1, payload3)
        val type21 = ViewTypeGenerator.get(viewBinder2, payload1)

        assert(type1 != type2)
        assert(type1 != type11)
        assert(type2 != type11)

        assert(type11 != type12)
        assert(type11 != type13)
        assert(type21 != type11)

        assert(type11 == type11_2)
    }
}
