import 'package:pigeon/pigeon.dart';

class Deck {
  final String deckId;
  final Map<String?, DeckItem?> items;
  final bool enabled;

  Deck(this.deckId, this.items, this.enabled);
}

class DeckItem {
  final String id;
  final String tag;
  final bool enabled;

  DeckItem(this.id, this.tag, this.enabled);
}

@HostApi()
abstract class DeckOps {
  @async
  void doDecksChanged(List<Deck> decks);

  @async
  void doTagMappingChanged(Map<String, String> tapMapping);
}
