import 'package:common/common/navigation.dart';
import 'package:common/common/widget/common_divider.dart';
import 'package:common/common/widget/settings/exception_item.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/custom/custom.dart';
import 'package:common/util/mobx.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';

class ExceptionsSection extends StatefulWidget {
  final bool primary;

  const ExceptionsSection({Key? key, this.primary = true}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ExceptionsSectionState();
}

class ExceptionsSectionState extends State<ExceptionsSection> with Logging {
  late final _custom = Core.get<CustomStore>();

  bool _isReady = false;
  late List<String> _allowed;
  late List<String> _denied;

  @override
  void initState() {
    super.initState();
    reactionOnStore((_) => _custom.allowed, (allowed) {
      setState(() {
        _isReady = true;
        _allowed = _custom.allowed.toList();
        _denied = _custom.denied.toList();
        _sort();
      });
    });
    _reload();
  }

  _reload() async {
    if (!mounted) return;
    log(Markers.ui).trace("fetchCustom", (m) async {
      await _custom.fetch(m);
      setState(() {
        _isReady = true;
        _allowed = _custom.allowed.toList();
        _denied = _custom.denied.toList();
        _sort();
      });
    });
  }

  _sort() {
    _allowed.sort();
    _denied.sort();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: !_isReady
          ? Container()
          : ListView(
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
    );
  }

  List<Widget> _buildItems(BuildContext context, List<String> items) {
    return items.mapIndexed((index, it) {
      //return List.generate(100, (index) {
      return Container(
        color: context.theme.bgMiniCard,
        child: Column(children: [
          ExceptionItem(
              entry: it,
              blocked: items == _denied,
              onRemove: _onRemove,
              onChange: _onChange),
          index < (_denied.length + _allowed.length - 1)
              ? const CommonDivider(indent: 60)
              : Container(),
        ]),
      );
    }).toList();
  }

  _onRemove(String entry) async {
    log(Markers.userTap).trace("deleteCustom", (m) async {
      setState(() {
        if (_denied.contains(entry)) {
          _denied.remove(entry);
        } else {
          _allowed.remove(entry);
        }
      });
      await _custom.delete(entry, m);
      _reload();
    });
  }

  _onChange(String entry) async {
    log(Markers.userTap).trace("changeCustom", (m) async {
      final allow = _denied.contains(entry);
      setState(() {
        if (allow) {
          _denied.remove(entry);
          _allowed.add(entry);
        } else {
          _allowed.remove(entry);
          _denied.add(entry);
        }
        _sort();
      });

      await _custom.toggle(entry, m);
      _reload();
    });
  }
}
