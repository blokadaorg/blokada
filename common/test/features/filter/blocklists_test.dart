import 'package:common/src/features/filter/domain/filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final filters = KnownFilters(isFamily: false).get();
  final keys = blocklistKeys(filters);

  group("v6 blocklists", () {
    test("every main list is a known option", () {
      for (final key in v6MainBlocklists) {
        expect(keys, contains(key));
      }
    });

    test("every option has a group by what it blocks", () {
      for (final key in keys) {
        expect(v6BlocklistGroup(key), isNot(BlocklistGroup.other), reason: "$key has no group");
      }
    });

    test("an unknown option still shows up, under other lists", () {
      expect(v6BlocklistGroup(const BlocklistKey("new", "list")), BlocklistGroup.other);
    });

    test("main is the first general list on, in main order", () {
      final selected = [
        FilterSelection("hblock", ["standard"]),
        FilterSelection("oisd", ["nsfw", "big"]),
      ];
      expect(v6MainBlocklist(selected), const BlocklistKey("oisd", "big"));
    });

    test("a saved pick wins only while it is on", () {
      final selected = [
        FilterSelection("oisd", ["small"]),
        FilterSelection("stevenblack", ["unified"]),
      ];
      const unified = BlocklistKey("stevenblack", "unified");
      expect(v6MainBlocklist(selected, pick: unified), unified);
      expect(
        v6MainBlocklist(selected, pick: const BlocklistKey("1hosts", "pro")),
        const BlocklistKey("oisd", "small"),
      );
      // An extra can't be main, even if it was saved as the pick.
      expect(
        v6MainBlocklist([
          FilterSelection("oisd", ["nsfw"]),
        ], pick: const BlocklistKey("oisd", "nsfw")),
        isNull,
      );
    });

    test("no general list on means no main list", () {
      expect(
        v6MainBlocklist([
          FilterSelection("adaway", ["standard"]),
        ]),
        isNull,
      );
      expect(v6MainBlocklist([]), isNull);
    });

    test("withBlocklist adds and removes one option", () {
      const big = BlocklistKey("oisd", "big");
      final on = withBlocklist(
        [
          FilterSelection("oisd", ["small"]),
        ],
        big,
        true,
      );
      expect(selectedBlocklists(on), {const BlocklistKey("oisd", "small"), big});
      expect(selectedBlocklists(withBlocklist(on, big, false)), {
        const BlocklistKey("oisd", "small"),
      });
      expect(selectedBlocklists(withBlocklist([], big, true)), {big});
    });

    test("names say the provider and, when it has several, the list", () {
      expect(blocklistName(const BlocklistKey("oisd", "small"), filters), "OISD Small");
      expect(blocklistName(const BlocklistKey("1hosts", "pro"), filters), "1Hosts Pro");
      expect(blocklistName(const BlocklistKey("hblock", "standard"), filters), "hBlock");
      expect(blocklistName(const BlocklistKey("goodbyeads", "standard"), filters), "Goodbye ads");
      expect(
        blocklistName(const BlocklistKey("goodbyeads", "youtube"), filters),
        "Goodbye ads YouTube",
      );
    });

    test("tags round trip, and bad ones read as no pick", () {
      const key = BlocklistKey("stevenblack", "fake news");
      expect(BlocklistKey.fromTag(key.tag), key);
      expect(BlocklistKey.fromTag(null), isNull);
      expect(BlocklistKey.fromTag("oisd"), isNull);
      expect(BlocklistKey.fromTag("/small"), isNull);
      expect(BlocklistKey.fromTag("oisd/"), isNull);
    });
  });
}
