package gs

import gs.environment.generateIdentity
import gs.environment.identityFrom
import org.junit.Assert
import org.junit.Test

/**
 *
 */
class IdentityTest {
    @Test fun version0_isTrivial() {
        val id = generateIdentity(0)
        Assert.assertEquals("00-anonymous", id.toString())
    }
    @Test fun version0_identityFrom() {
        val id = identityFrom("99-magic")
        Assert.assertEquals("99-magic", id.toString())
        val id2 = identityFrom("")
        Assert.assertEquals("00-anonymous", id2.toString())
    }

    @Test fun version1_isUuid() {
        val id = generateIdentity(1)
        Assert.assertEquals(id.toString().length, 36)
    }
}
