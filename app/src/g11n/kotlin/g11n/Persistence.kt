package g11n

import core.Result

class Persistence {
    companion object {
        val translation = TranslationPersistence()
    }
}

class TranslationPersistence {
    val load = {
        Result.of { core.Persistence.paper().read<TranslationStore>("g11n:translation:store",
                TranslationStore()) }
    }
    val save = { store: TranslationStore ->
        Result.of { core.Persistence.paper().write("g11n:translation:store", store) }
    }
}
