package tunnel

import com.github.michaelbull.result.Result
import org.junit.Assert
import org.junit.Test

class PersistenceRollTest {
    @Test fun roll_works() {
        val inMemoryPersistence = mutableListOf<List<Request>>(
                emptyList(), emptyList(), emptyList()
        )

        val p = RequestPersistence(
                load = { batch -> Result.of { inMemoryPersistence[batch] } },
                saveBatch = { batch, list -> Result.of { inMemoryPersistence[batch] = list } }
        )

        repeat(p.batch_sizes[0]) {
            p.save(Request("example.com"))
        }

        // Cause roll
        p.save(Request("rick-rolled.com"))

        Assert.assertEquals(0, inMemoryPersistence[0].size)
        Assert.assertEquals(p.batch_sizes[0] + 1, inMemoryPersistence[1].size)
        Assert.assertEquals(0, inMemoryPersistence[2].size)

        repeat(p.batch_sizes[1] - 1 - 1) {
            p.save(Request("example.com"))
        }

        // Cause roll of first and second batch
        p.save(Request("rick-rolled.com"))

        Assert.assertEquals(0, inMemoryPersistence[0].size)
        Assert.assertEquals(0, inMemoryPersistence[1].size)
        Assert.assertEquals(p.batch_sizes[1] + p.batch_sizes[0], inMemoryPersistence[2].size)

        repeat(p.batch_sizes[2]) {
            p.save(Request("example.com"))
        }

        // Cause roll of all three batches, last one should not empty but drop oldest items
        p.save(Request("rick-rolled.com"))

        Assert.assertEquals(p.batch_sizes[2], inMemoryPersistence[2].size)
    }
}
