import 'package:common/src/features/env/domain/env.dart';
import 'package:common/src/features/modal/domain/modal.dart';
import 'package:common/src/features/private_dns/domain/private_dns_setup.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/minicard/minicard.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/module/perm/perm.dart';
import 'package:common/src/platform/perm/perm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Guides Android users through Private DNS, the most asked-about step of
/// setup. It shows the hostname with a visible Copy button, steps for the
/// phone's maker, and on return from Settings it checks that DNS really goes
/// through Blokada before saying so. If it does not, it shows what to try.
class PrivateDnsSheetAndroid extends StatefulWidget {
  /// Test seams; production reads these from Core.
  final PrivateDnsSetupVerifier? verifier;
  final String? manufacturer;
  final Duration successDelay;

  const PrivateDnsSheetAndroid({
    super.key,
    this.verifier,
    this.manufacturer,
    this.successDelay = const Duration(milliseconds: 1500),
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
  var _attempted = false;
  var _copied = false;
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
      final result = await _verifier.verify(
        m,
        _provider.getDeviceTag(),
        attempted: _attempted,
        onChecking: () => _show(PrivateDnsSetupStep.checking),
      );
      log(m).pair("privateDnsSetup", result);
      _show(result.step);
      if (result.step == PrivateDnsSetupStep.success) {
        await sleepAsync(widget.successDelay);
        // Closing via the modal value lets BottomManagerSheet pop this exact
        // sheet, never an unrelated route.
        if (mounted) await _modal.change(m, null);
      }
    } catch (e, s) {
      log(m).e(msg: "Private DNS verification failed", err: e, stack: s);
      _show(_attempted ? PrivateDnsSetupStep.help : PrivateDnsSetupStep.setup);
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

  Future<void> _copy() async {
    log(Markers.userTap).t("Copying the Private DNS hostname");
    await Clipboard.setData(ClipboardData(text: _hostname));
    if (mounted) setState(() => _copied = true);
  }

  Future<void> _openSettings() async {
    log(Markers.userTap).t("Opening system Settings for Private DNS");
    _attempted = true;
    await _channel.doOpenPermSettings();
  }

  Future<void> _retry() async {
    _attempted = true;
    await _verify(Markers.userTap);
  }

  Future<void> _contactSupport() async {
    await _modal.change(Markers.userTap, null);
    Navigation.open(Paths.support);
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
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildContent(context),
                    ),
                  ),
                ),
                ..._buildActions(context),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (_step) {
      case PrivateDnsSetupStep.setup:
        return _buildSetup(context);
      case PrivateDnsSetupStep.checking:
        return _buildChecking(context);
      case PrivateDnsSetupStep.success:
        return _buildSuccess(context);
      case PrivateDnsSetupStep.help:
        return _buildHelp(context);
    }
  }

  Widget _header(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.displaySmall!.copyWith(fontWeight: FontWeight.w700),
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
        _buildHostname(context),
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
                  "private dns android hostname label".i18n,
                  style: TextStyle(fontSize: 12, color: context.theme.textSecondary),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  _hostname,
                  style: const TextStyle(fontFamily: "monospace", fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          MergeSemantics(
            child: Semantics(
              identifier: AutomationIds.dnsCopyHostname,
              button: true,
              child: TextButton.icon(
                onPressed: _copy,
                icon: Icon(_copied ? Icons.check : Icons.copy, size: 18),
                label: Text("universal action copy".i18n),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecking(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 48),
        const CircularProgressIndicator(),
        const SizedBox(height: 24),
        _secondary(context, "private dns android checking".i18n),
      ],
    );
  }

  Widget _buildSuccess(BuildContext context) {
    return Semantics(
      identifier: AutomationIds.dnsSetupSuccess,
      container: true,
      child: Column(
        children: [
          const SizedBox(height: 32),
          Icon(Icons.check_circle, size: 64, color: context.theme.accent),
          _header(context, "private dns android success header".i18n),
          _secondary(context, "private dns android success brief".i18n),
        ],
      ),
    );
  }

  Widget _buildHelp(BuildContext context) {
    final tips = [
      "private dns android help typing".i18n,
      "private dns android help network".i18n,
      if (_oem == PrivateDnsOem.samsung) "private dns android help samsung".i18n,
      "private dns android help support".i18n,
    ];
    return Semantics(
      identifier: AutomationIds.dnsSetupHelp,
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: _header(context, "private dns android help header".i18n)),
          _buildHostname(context),
          const SizedBox(height: 16),
          for (final tip in tips)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Text("•", style: TextStyle(color: context.theme.textSecondary)),
                  ),
                  Expanded(child: Text(tip)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    switch (_step) {
      case PrivateDnsSetupStep.setup:
        return [
          _primaryButton(
            context,
            "dnsprofile action open settings".i18n,
            _openSettings,
            AutomationIds.dnsOpenSettings,
          ),
        ];
      case PrivateDnsSetupStep.help:
        return [
          _primaryButton(context, "universal action try again".i18n, _retry),
          Row(
            children: [
              Expanded(
                child: _secondaryButton(
                  context,
                  "dnsprofile action open settings".i18n,
                  _openSettings,
                  AutomationIds.dnsOpenSettings,
                ),
              ),
              Expanded(
                child: _secondaryButton(context, "support action chat".i18n, _contactSupport),
              ),
            ],
          ),
        ];
      case PrivateDnsSetupStep.checking:
      case PrivateDnsSetupStep.success:
        return [];
    }
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

  Widget _secondaryButton(
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
            outlined: true,
            child: SizedBox(
              height: 32,
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.theme.accent, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
