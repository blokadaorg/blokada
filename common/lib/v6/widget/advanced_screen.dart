import 'package:common/common/navigation.dart';
import 'package:common/common/widget/with_top_bar.dart';
import 'package:common/core/core.dart';
import 'package:common/v6/widget/filters_section.dart';
import 'package:flutter/material.dart';

class AdvancedScreen extends StatefulWidget {
  const AdvancedScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => AdvancedScreenState();
}

class AdvancedScreenState extends State<AdvancedScreen> with Logging {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = isTabletMode(context);

    if (isTablet) return _buildForTablet(context);
    return _buildForPhone(context);
  }

  Widget _buildForPhone(BuildContext context) {
    return WithTopBar(
      title: "main tab advanced".i18n,
      child: const V6FiltersSection(twoColumns: false),
    );
  }

  Widget _buildForTablet(BuildContext context) {
    return WithTopBar(
      title: "main tab advanced".i18n,
      maxWidth: maxContentWidthTablet,
      child: const Row(
        children: [
          Expanded(
            flex: 1,
            child: V6FiltersSection(twoColumns: true),
          ),
        ],
      ),
    );
  }
}
