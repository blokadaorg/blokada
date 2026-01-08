import 'package:common/src/shared/ui/dialog.dart';
import 'package:common/src/shared/ui/common_clickable.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/plus/domain/bypass/bypass.dart';
import 'package:common/src/features/plus/ui/vpn_bypass_item.dart';
import 'package:flutter/material.dart';

class BypassAddDialog with Logging {
  late final _bypass = Core.get<BypassActor>();

  late final TextEditingController _ctrl = TextEditingController(text: "");

  Widget? getBypassAction(BuildContext context) {
    return CommonClickable(
        onTap: () {
          _showAddBypassDialog(context, apps: _bypass.allApps,
              onConfirm: (entry) async {
            // Let the dialog close
            await sleepAsync(const Duration(seconds: 1));
            await log(Markers.userTap).trace("addBypass", (m) async {
              await _bypass.setAppBypass(m, entry, true);
            });
          });
        },
        child: Text(
          "universal action add".i18n,
          style: TextStyle(
            color: context.theme.accent,
            fontSize: 17,
          ),
        ));
  }

  // Shows a dialog with TextField to enter app name or package name.
  // Shows also suggestions based on installed apps.
  // Does a search on installed apps to filter suggestions.
  void _showAddBypassDialog(
    BuildContext context, {
    required Function(String) onConfirm,
    List<InstalledApp> apps = const [],
  }) {
    final suggestions = ValueNotifier<List<InstalledApp>>([]);

    // Function to update filtered suggestions based on input
    void updateSuggestions(String query) {
      if (query.length < 2) {
        suggestions.value = [];
      } else {
        suggestions.value = _bypass.find(query);
      }
    }

    // Initialize with all suggestions
    updateSuggestions("");

    showDefaultDialog(
      context,
      title: Text("bypass action add".i18n),
      content: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("bypass dialog add brief".i18n),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12.0),
            child: Material(
              child: TextField(
                controller: _ctrl,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: context.theme.bgColor,
                  focusColor: context.theme.bgColor,
                  hoverColor: context.theme.bgColor,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  enabledBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: context.theme.bgColor, width: 0.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: context.theme.bgColor, width: 0.0),
                  ),
                ),
                onChanged: updateSuggestions,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Suggestions list
          ValueListenableBuilder<List<InstalledApp>>(
            valueListenable: suggestions,
            builder: (context, suggestions, _) {
              return Container(
                decoration: BoxDecoration(
                  color: context.theme.bgMiniCard,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                constraints: BoxConstraints(
                  maxHeight: 200,
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                ),
                child: suggestions.isEmpty
                    ? const SizedBox.shrink()
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: suggestions
                              .map((suggestion) => AppBypassItem(
                                    app: suggestion,
                                    icon: null,
                                    showIcon: false,
                                    showChevron: false,
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      onConfirm(suggestion.packageName);
                                      _ctrl.text = "";
                                    },
                                  ))
                              .toList(),
                        ),
                      ),
              );
            },
          ),
        ],
      ),
      actions: (context) => [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            _ctrl.text = "";
            suggestions.value = [];
          },
          child: Text("universal action cancel".i18n),
        ),
      ],
    );
  }
}
