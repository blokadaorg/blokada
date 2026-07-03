import 'package:common/src/app_variants/v6/widget/filters_section.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/layout/window_shape.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/with_top_bar.dart';
import 'package:flutter/material.dart';

/// v6 blocklists tab. Single build path: the content box widens on
/// expanded windows and V6FiltersSection decides its own column count
/// from the width it actually gets.
class AdvancedScreen extends StatelessWidget {
  const AdvancedScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final expanded = windowShapeOf(context) == WindowShape.expanded;
    return Semantics(
      identifier: AutomationIds.screenAdvanced,
      child: WithTopBar(
        title: "main tab advanced".i18n,
        maxWidth: expanded ? maxContentWidthTablet : maxContentWidth,
        child: const V6FiltersSection(),
      ),
    );
  }
}
