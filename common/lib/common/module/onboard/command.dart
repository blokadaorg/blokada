part of 'onboard.dart';

const cmdOnboard = "onboard";
const cmdOnboardReset = "onboardReset";

const onboardLinkBase = "https://go.blokada.org/six/onboard";
const onboardLinkTemplate = "$onboardLinkBase?screen=SCREEN";

class OnboardCommand with Command {
  late final _modal = Core.get<CurrentModalValue>();

  late final _onboardIntro = Core.get<OnboardIntroValue>();
  late final _onboardSafariYoutube = Core.get<OnboardSafariValue>();
  late final _weekly = Core.get<WeeklyRefreshActor>();

  @override
  List<CommandSpec> onRegisterCommands() {
    return [
      registerCommand(cmdOnboard, argsNum: 1, fn: commandOnboard),
      registerCommand(cmdOnboardReset, argsNum: 1, fn: commandReset),
    ];
  }

  // Opens the given onboarding directly, used by deep links.
  Future<void> commandOnboard(Marker m, dynamic args) async {
    final onboardScreen = args[0] as String;

    var modal = Modal.onboardPrivateDns;
    if (onboardScreen == "safari") {
      _ensureIos();
      modal = Modal.onboardSafari;
    } else if (onboardScreen == "youtube") {
      _ensureIos();
      modal = Modal.onboardSafariYoutube;
    } else if (onboardScreen == "weekly") {
      _ensureIos();
      modal = Modal.weeklyRefresh;
    } else {
      throw Exception("Unknown onboard screen: $onboardScreen");
    }

    // When entering from a deep (universal) link, this will be called
    // by the OS very early, and since onStartApp is executed async to not
    // block the UI thread, we need to wait for the app to be ready.
    await sleepAsync(const Duration(seconds: 3));

    await _modal.change(m, modal);
  }

  Future<void> commandReset(Marker m, dynamic args) async {
    final onboardScreen = args[0] as String;

    if (onboardScreen == "intro") {
      _ensureIos();
      await _onboardIntro.change(m, null);
    } else if (onboardScreen == "youtube") {
      _ensureIos();
      await _onboardSafariYoutube.change(m, false);
    } else if (onboardScreen == "weekly") {
      _ensureIos();
      // No await because user will see OK and go to background, before it triggers
      _weekly.testFlow(m);
    } else {
      throw Exception("Unknown onboard screen: $onboardScreen");
    }
  }

  _ensureIos() {
    if (Core.act.platform != PlatformType.iOS) throw Exception("This is iOS only onboard");
  }
}
