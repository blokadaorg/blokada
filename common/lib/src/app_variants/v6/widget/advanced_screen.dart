import 'package:common/src/app_variants/v6/widget/filters_section.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/payment/domain/payment.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/layout/window_shape.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/freemium_screen.dart';
import 'package:common/src/shared/ui/with_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';

/// v6 blocklists tab. Single build path: the content box widens on
/// expanded windows and V6FiltersSection decides its own column count
/// from the width it actually gets. Owns the freemium gate overlay so it
/// covers the whole body, not just the section.
class AdvancedScreen extends StatefulWidget {
  const AdvancedScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => AdvancedScreenState();
}

class AdvancedScreenState extends State<AdvancedScreen> with Logging {
  late final _account = Core.get<AccountStore>();

  var _isFreemium = false;

  @override
  void initState() {
    super.initState();

    autorun((_) {
      setState(() {
        _isFreemium = _account.isFreemium;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final expanded = windowShapeOf(context) == WindowShape.expanded;
    return Semantics(
      identifier: AutomationIds.screenAdvanced,
      child: WithTopBar(
        title: "main tab advanced".i18n,
        maxWidth: expanded ? maxContentWidthTwoPane : maxContentWidth,
        overlay: _isFreemium
            ? FreemiumScreen(
                title: "freemium filters cta header".i18n,
                subtitle: "freemium filters cta desc".i18n,
                placement: Placement.freemiumFilters,
              )
            : null,
        child: const V6FiltersSection(),
      ),
    );
  }
}
