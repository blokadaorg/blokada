import 'package:common/common/widget/common_clickable.dart';
import 'package:common/common/widget/common_divider.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/custom/custom.dart';
import 'package:common/dragon/widget/dialog.dart';
import 'package:common/dragon/widget/exceptions/exception_item.dart';
import 'package:common/dragon/widget/home/top_bar.dart';
import 'package:common/util/di.dart';
import 'package:common/util/trace.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ExceptionsScreen extends StatefulWidget {
  const ExceptionsScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ExceptionsScreenState();
}

class ExceptionsScreenState extends State<ExceptionsScreen> with TraceOrigin {
  final ScrollController _scrollController = ScrollController();
  late final _custom = dep<CustomStore>();

  bool _isReady = false;
  late List<String> _allowed;
  late List<String> _denied;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateTopBar);
    _reload();
  }

  _reload() async {
    traceAs("fetchCustom", (trace) async {
      await _custom.fetch(trace);
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

  void _updateTopBar() {
    Provider.of<TopBarController>(context, listen: false)
        .updateScrollPos(_scrollController.offset);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateTopBar);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: context.theme.bgColor,
        child: PrimaryScrollController(
          controller: _scrollController,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: !_isReady
                    ? Container()
                    : ListView(
                        primary: true,
                        children: [
                              const SizedBox(height: 60),
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
              TopBar(
                  title: "My exceptions",
                  trailing: CommonClickable(
                      onTap: () {
                        showAddExceptionDialog(context, onConfirm: (entry) {
                          traceAs("addCustom", (trace) async {
                            await _custom.allow(trace, entry);
                            _reload();
                          });
                        });
                      },
                      child: Text(
                        "Add",
                        style: TextStyle(
                          color: context.theme.accent,
                          fontSize: 17,
                        ),
                      ))),
            ],
          ),
        ),
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
    traceAs("deleteCustom", (trace) async {
      setState(() {
        if (_denied.contains(entry)) {
          _denied.remove(entry);
        } else {
          _allowed.remove(entry);
        }
      });
      await _custom.delete(trace, entry);
      _reload();
    });
  }

  _onChange(String entry) async {
    traceAs("changeCustom", (trace) async {
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

      await _custom.toggle(trace, entry);
      _reload();
    });
  }
}
