import 'package:common/src/features/env/domain/env.dart';
import 'package:common/src/features/modal/domain/modal.dart';
import 'package:common/src/features/private_dns/domain/private_dns_setup.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/ui/minicard/minicard.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/module/perm/perm.dart';
import 'package:common/src/platform/perm/perm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Guides Android users through Private DNS, the most asked-about step of
/// setup. It shows steps for the phone's maker and the hostname with a
/// visible copy button, and on return from Settings it closes itself once
/// Private DNS holds this device's hostname.
class PrivateDnsSheetAndroid extends StatefulWidget {
  /// Test seams; production reads these from Core.
  final PrivateDnsSetupVerifier? verifier;
  final String? manufacturer;
  final Duration successDelay;
  final Duration copiedBeforeSettingsDelay;

  const PrivateDnsSheetAndroid({
    super.key,
    this.verifier,
    this.manufacturer,
    this.successDelay = const Duration(milliseconds: 1500),
    this.copiedBeforeSettingsDelay = const Duration(milliseconds: 800),
  });

  @override
  State<StatefulWidget> createState() => PrivateDnsSheetAndroidState();
}

class PrivateDnsSheetAndroidState extends State<PrivateDnsSheetAndroid>
    with Logging, WidgetsBindingObserver {
  late final _channel = Core.get<PermChannel>();
  late final _provider = Core.get<PrivateDnsStringProvider>();
  late final _modal = Core.get<CurrentModalValue>();
  late final _verifier = widget.verifier ?? PrivateDnsSetupVerifier();
  late final _appName = Core.act.isFamily ? "Blokada Family" : "Blokada 6";
  late final _oem = privateDnsOemFor(widget.manufacturer ?? _readManufacturer());
  late final _hostname = _provider.getAndroidDnsString();

  var _step = PrivateDnsSetupStep.setup;
  var _copied = false;
  // Set when Open Settings did the copy, to tell the user what happened.
  var _copiedBySettings = false;
  var _verifying = false;
  // A resume during a running check would otherwise be lost, leaving a
  // result from before the user's latest change in Settings.
  var _verifyAgain = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _verify(Markers.ui);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // The user comes back here from system Settings, so check on every resume.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _verify(Markers.ui);
  }

  String? _readManufacturer() {
    try {
      return Core.get<EnvActor>().info.deviceBrand;
    } catch (e) {
      log(Markers.ui).e(msg: "Private DNS sheet: no device maker", err: e);
      return null;
    }
  }

  Future<void> _verify(Marker m) async {
    if (_verifying) {
      _verifyAgain = true;
      return;
    }
    _verifying = true;
    try {
      final step = await _verifier.verify(_provider.getDeviceTag());
      log(m).pair("privateDnsSetup", step);
      _show(step);
      if (step == PrivateDnsSetupStep.success) {
        await sleepAsync(widget.successDelay);
        // Closing via the modal value lets BottomManagerSheet pop this exact
        // sheet, never an unrelated route.
        if (mounted) await _modal.change(m, null);
      }
    } catch (e, s) {
      log(m).e(msg: "Private DNS verification failed", err: e, stack: s);
      _show(PrivateDnsSetupStep.setup);
    } finally {
      _verifying = false;
    }
    if (_verifyAgain && mounted) {
      _verifyAgain = false;
      await _verify(m);
    }
  }

  void _show(PrivateDnsSetupStep step) {
    if (!mounted || step == _step) return;
    setState(() => _step = step);
  }

  /// Returns false when the clipboard refused the hostname; it stays on screen
  /// to type by hand.
  Future<bool> _copy() async {
    log(Markers.userTap).t("Copying the Private DNS hostname");
    try {
      await Clipboard.setData(ClipboardData(text: _hostname));
    } catch (e, s) {
      log(Markers.userTap).e(msg: "Private DNS sheet: copy failed", err: e, stack: s);
      return false;
    }
    if (mounted) setState(() => _copied = true);
    return true;
  }

  // Copies for users who skip Copy, but visibly: the button flips and a line
  // says so, and the sheet waits a moment so it is seen before Settings opens.
  Future<void> _openSettings() async {
    log(Markers.userTap).t("Opening system Settings for Private DNS");
    if (!_copied && await _copy()) {
      if (mounted) setState(() => _copiedBySettings = true);
      await sleepAsync(widget.copiedBeforeSettingsDelay);
    }
    try {
      await _channel.doOpenPermSettings();
    } catch (e, s) {
      // The sheet keeps the steps on screen, so Settings can still be opened
      // by hand.
      log(Markers.userTap).e(msg: "Private DNS sheet: opening Settings failed", err: e, stack: s);
    }
  }

  List<String> get _oemSteps {
    switch (_oem) {
      case PrivateDnsOem.samsung:
        return [
          "private dns android step samsung connections".i18n,
          "private dns android step samsung more".i18n,
          "private dns android step choose hostname".i18n,
          "private dns android step paste".i18n,
        ];
      case PrivateDnsOem.pixel:
        return [
          "private dns android step pixel network".i18n,
          "private dns android step tap private dns".i18n,
          "private dns android step choose hostname".i18n,
          "private dns android step paste".i18n,
        ];
      case PrivateDnsOem.xiaomi:
        return [
          "private dns android step connection sharing".i18n,
          "private dns android step tap private dns".i18n,
          "private dns android step choose hostname".i18n,
          "private dns android step paste".i18n,
        ];
      case PrivateDnsOem.oneplus:
        return [
          "private dns android step connection sharing".i18n,
          "private dns android step tap private dns".i18n,
          "private dns android step choose designated".i18n,
          "private dns android step paste".i18n,
        ];
      case PrivateDnsOem.other:
        return [
          "private dns android step search".i18n,
          "private dns android step choose hostname".i18n,
          "private dns android step paste".i18n,
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final setup = _step == PrivateDnsSetupStep.setup;
    return Semantics(
      identifier: AutomationIds.dnsOnboardingSheet,
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        body: Container(
          color: context.theme.bgColorCard,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: setup ? _buildSetup(context) : _buildSuccess(context),
                    ),
                  ),
                ),
                // The steps scroll; the hostname and Open Settings stay at
                // the bottom.
                if (setup) ...[
                  const SizedBox(height: 16),
                  if (_copiedBySettings)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Text(
                        "private dns android copied hint".i18n,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.theme.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _buildHostname(context),
                  ),
                  const SizedBox(height: 6),
                  _primaryButton(
                    context,
                    "dnsprofile action open settings".i18n,
                    _openSettings,
                    AutomationIds.dnsOpenSettings,
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      // One line on narrow phones: shrink rather than wrap.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall!.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _secondary(BuildContext context, String text) {
    return Text(text, softWrap: true, style: TextStyle(color: context.theme.textSecondary));
  }

  Widget _buildSetup(BuildContext context) {
    final steps = _oemSteps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: _header(context, "private dns android header".i18n)),
        _secondary(context, "private dns android brief".i18n.withParams(_appName)),
        const SizedBox(height: 16),
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Text("${i + 1}.", style: TextStyle(color: context.theme.textSecondary)),
                ),
                Expanded(child: Text(steps[i])),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHostname(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.theme.panelBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "private dns android blokada hostname label".i18n,
                  style: TextStyle(fontSize: 12, color: context.theme.textSecondary),
                ),
                const SizedBox(height: 2),
                // Not selectable: a manual copy would carry the display-only
                // break characters into Settings.
                Text(
                  privateDnsDisplayHostname(_hostname),
                  style: const TextStyle(fontFamily: "monospace", fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          MergeSemantics(
            child: Semantics(
              identifier: AutomationIds.dnsCopyHostname,
              label: "universal action copy".i18n,
              button: true,
              child: IconButton(
                onPressed: _copy,
                color: context.theme.accent,
                icon: Icon(_copied ? Icons.check : Icons.copy, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    return Semantics(
      identifier: AutomationIds.dnsSetupSuccess,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Icon(Icons.check_circle, size: 64, color: context.theme.accent),
          _header(context, "private dns android success header".i18n),
          Center(child: _secondary(context, "private dns android success brief".i18n)),
        ],
      ),
    );
  }

  Widget _primaryButton(
    BuildContext context,
    String label,
    VoidCallback onTap, [
    String? automationId,
  ]) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: MergeSemantics(
        child: Semantics(
          identifier: automationId,
          button: true,
          child: MiniCard(
            onTap: onTap,
            color: context.theme.accent,
            child: SizedBox(
              height: 32,
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(color: context.theme.onAccent, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The hostname as shown, so it wraps only after a dot: a zero-width space
/// follows each dot and hyphens are non-breaking. Copies use the real one.
String privateDnsDisplayHostname(String hostname) =>
    hostname.replaceAll("-", "‑").replaceAll(".", ".​");
