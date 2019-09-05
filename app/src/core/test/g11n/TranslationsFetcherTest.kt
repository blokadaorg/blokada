package g11n

import core.Kontext
import core.Result
import org.junit.Assert
import org.junit.Test

class TranslationsFetcherTest {
    @Test fun fetcher_basics() {
        var put = false
        val fetcher = TranslationsFetcher(
                urls = { mapOf("http://localhost" to "fixture") },
                doFetchTranslations = { url, prefix ->
                    Result.of { listOf("fixture_key1" to "translation1") }
                },
                doPutTranslation = { key, translation ->
                    put = true
                    Assert.assertEquals("fixture_key1", key)
                    Assert.assertEquals("translation1", translation)
                    Result.of { true }
                }
        )

        fetcher.sync(Kontext.forTest())
        Assert.assertTrue(put)
    }
}
