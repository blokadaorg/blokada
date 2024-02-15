import 'package:common/common/widget.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vistraced/via.dart';

import '../../../../stage/channel.pg.dart';
import '../../../../util/config.dart';
import '../../../defaults/filter_decor_defaults.dart';
import '../../../model.dart';

part 'filter_screen.g.dart';

class FilterScreen extends StatefulWidget {
  const FilterScreen({Key? key}) : super(key: key);

  @override
  State<FilterScreen> createState() => _$FilterScreenState();
}

@Injected(onlyVia: true, immediate: true)
class FilterScreenState extends State<FilterScreen>
    with ViaTools<FilterScreen> {
  late final _modal = Via.as<StageModal?>()..also(rebuild);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: context.theme.bgColor,
        child: Stack(
          children: [
            _buildFilters(context),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return ListView(
      children: [
        BackEditHeaderWidget(name: "Alva"),
        _buildProfileHeader(context),
        _buildFilter(context, 0, color: const Color(0xFFA9CCFE)),
        _buildFilter(context, 1),
        _buildFilter(context, 2, color: const Color(0xFFF4B1C6)),
        _buildFilter(context, 3, color: const Color(0XFFFDB39C)),
        _buildFilter(context, 4),
        _buildFilter(context, 5),
        _buildFilter(context, 6),
      ],
    );
  }

  Widget _buildFilter(BuildContext context, int index, {Color? color}) {
    final filter = getKnownFilters(cfg.act)[index];
    final texts = filterDecorDefaults
        .firstWhere((it) => it.filterName == filter.filterName);
    return FilterWidget(filter: filter, texts: texts, bgColor: color);
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, left: 16, right: 8),
      child: Row(
        children: [
          Text("Blocklists",
              style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
          Expanded(child: Container()),
          Touch(
            onTap: () => {_showEditProfileNameDialog(context)},
            decorationBuilder: (value) {
              return BoxDecoration(
                color: context.theme.bgMiniCard.withOpacity(value),
                borderRadius: BorderRadius.circular(4),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Text("Alva"),
                  SizedBox(width: 8),
                  Icon(CupertinoIcons.folder,
                      color: context.theme.textSecondary, size: 18),
                  SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  _showEditProfileNameDialog(BuildContext context) {
    showDefaultDialog(
      context,
      title: const Text("Profile"),
      content: (context) => Column(
        children: [
              const Text("Choose a profile to use for Alva."),
              SizedBox(height: 16),
            ] +
            ["Alva", "Adblocking only"]
                .map((it) => _buildProfileEditItem(context, it))
                .flatten()
                .toList()
                .dropLast(1),
      ),
      actions: (context) => [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            _showNameProfileDialog(context, null);
          },
          child: const Text("New profile"),
        ),
      ],
    );
  }

  List<Widget> _buildProfileEditItem(BuildContext context, String name) {
    return [
      Touch(
        onTap: () => {},
        decorationBuilder: (value) {
          return BoxDecoration(
            color: context.theme.bgMiniCard.withOpacity(value),
            borderRadius: BorderRadius.circular(4),
          );
        },
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Icon(CupertinoIcons.doc,
                      color: context.theme.textSecondary, size: 18),
                  SizedBox(width: 8),
                  Text(name,
                      style: TextStyle(
                          color: context.theme.textPrimary, fontSize: 16)),
                ],
              ),
            ),
            Expanded(child: Container()),
            Touch(
              onTap: () {
                Navigator.of(context).pop();
                _showNameProfileDialog(context, name);
              },
              decorationBuilder: (value) {
                return BoxDecoration(
                  color: context.theme.bgMiniCard.withOpacity(value),
                  borderRadius: BorderRadius.circular(4),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(CupertinoIcons.pencil,
                    color: context.theme.textSecondary, size: 18),
              ),
            ),
          ],
        ),
      ),
      Divider(
          indent: 4,
          endIndent: 4,
          thickness: 0.4,
          height: 4,
          color: context.theme.divider),
    ];
  }

  void _showNameProfileDialog(BuildContext context, String? name) {
    showDefaultDialog(
      context,
      title: Text(name == null ? "New Profile" : "Rename Profile"),
      content: (context) => Column(
        children: [
          const Text("Enter a name for your profile."),
          const SizedBox(height: 16),
          Material(
            child: TextField(
              controller: TextEditingController(text: name),
              decoration: InputDecoration(
                filled: true,
                fillColor: context.theme.panelBackground,
                focusColor: context.theme.panelBackground,
                hoverColor: context.theme.panelBackground,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                enabledBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: context.theme.divider, width: 1.0),
                  borderRadius: BorderRadius.circular(2.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: context.theme.divider, width: 1.0),
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
            ),
          ),
        ],
      ),
      actions: (context) => [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Save"),
        ),
      ],
    );
  }
}
