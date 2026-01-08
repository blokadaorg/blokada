/// Public surface of the Blokada Flutter module.
/// Keep additions minimal; prefer exposing stable entrypoints only.
library common;

export 'modules.dart';
export 'src/core/core.dart'
    show Act, ActScenario, ActScreenplay, PlatformType, CoreConfig, Core, Logging;
export 'src/shared/navigation.dart';
export 'src/shared/ui/app.dart' show BlokadaApp;
export 'src/shared/ui/top_bar.dart' show TopBarController;
