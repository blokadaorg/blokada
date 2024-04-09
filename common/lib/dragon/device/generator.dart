import 'package:unique_names_generator/unique_names_generator.dart' as names;

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
