import 'dart:async';

import 'package:common/common/widget/minicard/minicard.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/family/family.dart';
import 'package:common/platform/family/family.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QrScanSheetMacos extends StatefulWidget {
  const QrScanSheetMacos({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => QrScanSheetMacosState();
}

class QrScanSheetMacosState extends State<QrScanSheetMacos> with Logging {
  late final _familyLink = Core.get<LinkActor>();
  late final _channel = Core.get<FamilyChannel>();
  late final _linkedMode = Core.get<FamilyLinkedMode>();

  final _linkController = TextEditingController();
  bool _isProcessing = false;
  String? _errorMessage;
  bool _hasText = false;
  StreamSubscription? _linkedModeSubscription;

  @override
  void initState() {
    super.initState();
    _linkController.addListener(_onTextChanged);

    // Listen to linkedMode changes and pop when linked
    _linkedModeSubscription = _linkedMode.onChange.listen((event) {
      if (event.now == true && mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _linkedModeSubscription?.cancel();
    _linkController.removeListener(_onTextChanged);
    _linkController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _linkController.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  Future<void> _handleLink(String url) async {
    if (url.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      await log(Markers.userTap).trace("macosLinkSubmit", (m) async {
        await _familyLink.link(url, m);
      });

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Invalid link. Please check and try again.".i18n;
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null) {
      _linkController.text = clipboardData!.text!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: context.theme.bgColorCard,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      Text(
                        "family account attach header".i18n,
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall!
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Text(
                          "Our Mac app cannot scan QR codes. Instead, please link it to your parent app like this:"
                              .i18n,
                          softWrap: true,
                          textAlign: TextAlign.left,
                          style: TextStyle(color: context.theme.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInstructionStep(
                              "1",
                              "On the parent device, open Blokada Family app".i18n,
                            ),
                            const SizedBox(height: 8),
                            _buildInstructionStep(
                              "2",
                              "Tap 'Add new device' or the '+' button".i18n,
                            ),
                            const SizedBox(height: 8),
                            _buildInstructionStep(
                              "3",
                              "Tap the Share button next to the QR code".i18n,
                            ),
                            const SizedBox(height: 8),
                            _buildInstructionStep(
                              "4",
                              "Share via AirDrop to this Mac, or copy and paste the link below"
                                  .i18n,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Manual link input section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: context.theme.bgColor.withAlpha(120),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _errorMessage != null
                                      ? Colors.red.withOpacity(0.5)
                                      : context.theme.divider.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _linkController,
                                      enabled: !_isProcessing,
                                      decoration: InputDecoration(
                                        hintText: "Paste link here...".i18n,
                                        hintStyle: TextStyle(
                                          color: context.theme.textSecondary.withOpacity(0.5),
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 14,
                                        ),
                                      ),
                                      style: TextStyle(
                                        color: context.theme.textPrimary,
                                        fontSize: 14,
                                      ),
                                      onSubmitted: _handleLink,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _isProcessing ? null : _pasteFromClipboard,
                                    icon: Icon(
                                      CupertinoIcons.doc,
                                      color: context.theme.accent,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Info box
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        decoration: BoxDecoration(
                          color: context.theme.bgColor.withAlpha(50),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              CupertinoIcons.info_circle_fill,
                              color: context.theme.textSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Make sure AirDrop is enabled on this Mac to receive links directly."
                                    .i18n,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.theme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              // Action buttons
              if (_isProcessing)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CupertinoActivityIndicator(),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: MiniCard(
                          onTap: _hasText ? () => _handleLink(_linkController.text) : null,
                          color: _hasText
                              ? context.theme.accent
                              : context.theme.accent.withOpacity(0.5),
                          child: SizedBox(
                            height: 44,
                            child: Center(
                              child: Text(
                                "family cta action link".i18n,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: MiniCard(
                          onTap: () => Navigator.of(context).pop(),
                          color: context.theme.bgColor,
                          child: SizedBox(
                            height: 44,
                            child: Center(
                              child: Text(
                                "universal action cancel".i18n,
                                style: TextStyle(
                                  color: context.theme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$number. ",
          style: TextStyle(
            color: context.theme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: context.theme.textSecondary),
          ),
        ),
      ],
    );
  }
}
