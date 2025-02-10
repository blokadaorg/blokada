part of 'device.dart';

class NameGenerator {
  final _generator = names.UniqueNamesGenerator(
    config: names.Config(
      length: 1,
      seperator: " ",
      style: names.Style.capital,
      dictionaries: [names.animals],
    ),
  );

  get() => _generator.generate();
}
