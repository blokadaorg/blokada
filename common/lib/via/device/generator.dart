import 'package:unique_names_generator/unique_names_generator.dart' as names;
import 'package:vistraced/via.dart';

import '../actions.dart';

part 'generator.g.dart';

@Module([
  ViaMatcher<String>(GeneratorVia, of: ofGenerator),
])
class GeneratorModule extends _$GeneratorModule {}

@Injected()
class GeneratorVia extends HandleVia<String> {
  final _generator = names.UniqueNamesGenerator(
    config: names.Config(
      length: 1,
      seperator: " ",
      style: names.Style.capital,
      dictionaries: [names.animals],
    ),
  );

  @override
  Future<String> get() async => _generator.generate();
}
