part of 'onboard.dart';

const cmdOnboard = "onboard";

const onboardLinkBase = "https://go.blokada.org/six/onboard";
const onboardLinkTemplate = "$onboardLinkBase?screen=SCREEN";

class OnboardCommand with Command {
  late final _modal = Core.get<CurrentModalValue>();

  @override
  List<CommandSpec> onRegisterCommands() {
    return [
      registerCommand(cmdOnboard, argsNum: 1, fn: cmdLink),
    ];
  }

  Future<void> cmdLink(Marker m, dynamic args) async {
    final onboardScreen = args[0] as String;

    var modal = Modal.onboardPrivateDns;
    if (onboardScreen == "safari") {
      modal = Modal.onboardSafari;
    } else {
      throw Exception("Unknown onboard screen: $onboardScreen");
    }

    // When entering from a deep (universal) link, this will be called
    // by the OS very early, and since onStartApp is executed async to not
    // block the UI thread, we need to wait for the app to be ready.
    await sleepAsync(const Duration(seconds: 3));

    await _modal.change(m, modal);
  }
}
