import 'package:common/common/module/customlist/customlist.dart';
import 'package:common/common/navigation.dart';
import 'package:common/common/widget/common_divider.dart';
import 'package:common/common/widget/settings/exception_item.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class ExceptionsSection extends StatefulWidget {
  final bool primary;

  const ExceptionsSection({Key? key, this.primary = true}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ExceptionsSectionState();
}

class ExceptionsSectionState extends State<ExceptionsSection>
    with Logging, Disposables {
  late final _custom = Core.get<CustomlistActor>();
  late final _lists = Core.get<CustomListsValue>();

  bool _isReady = false;
  late List<CustomListEntry> _allowed;
  late List<CustomListEntry> _denied;

  @override
  void initState() {
    super.initState();
    disposeLater(_lists.onChange.listen((_) => _reload(fetch: false)));
    _reload();
  }

  @override
  void dispose() {
    disposeAll();
    super.dispose();
  }

  _reload({bool fetch = true}) async {
    if (!mounted) return;
    await log(Markers.ui).trace("fetchCustom", (m) async {
      if (fetch) await _custom.fetch(m);
      if (!mounted) return;
      setState(() {
        _isReady = true;
        _allowed = _lists.now.allowed;
        _denied = _lists.now.denied;
        _sort();
      });
    });
  }

  _sort() {
    _allowed.sort((a, b) => a.domainName.compareTo(b.domainName));
    _denied.sort((a, b) => a.domainName.compareTo(b.domainName));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: !_isReady
          ? Container()
          : SlidableAutoCloseBehavior(
              child: ListView(
                primary: widget.primary,
                children: [
                      SizedBox(height: getTopPadding(context)),
                      Container(
                        decoration: BoxDecoration(
                          color: context.theme.bgMiniCard,
                          borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12)),
                        ),
                        height: 12,
                      ),
                    ] +
                    _buildItems(context, _denied) +
                    _buildItems(context, _allowed) +
                    [
                      Container(
                        decoration: BoxDecoration(
                          color: context.theme.bgMiniCard,
                          borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(12),
                              bottomRight: Radius.circular(12)),
                        ),
                        height: 12,
                      ),
                    ],
              ),
            ),
    );
  }

  List<Widget> _buildItems(BuildContext context, List<CustomListEntry> items) {
    return items.mapIndexed((index, it) {
      //return List.generate(100, (index) {
      return Container(
        color: context.theme.bgMiniCard,
        child: Column(children: [
          ExceptionItem(
              entry: it.domainName,
              blocked: items == _denied,
              onRemove: (_) => _onRemove(it),
              onChange: (_) => _onChange(it)),
          index < (_denied.length + _allowed.length - 1)
              ? const CommonDivider(indent: 60)
              : Container(),
        ]),
      );
    }).toList();
  }

  _onRemove(CustomListEntry entry) async {
    log(Markers.userTap).trace("deleteCustom", (m) async {
      await _custom.remove(m, entry.domainName, entry.wildcard);
    });
  }

  _onChange(CustomListEntry entry) async {
    log(Markers.userTap).trace("changeCustom", (m) async {
      await _custom.toggle(m, entry.domainName, entry.wildcard);
    });
  }
}
