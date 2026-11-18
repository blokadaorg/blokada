import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Per-element ceilings on the system text scale.
///
/// Reading text, captions and action labels follow the system size all the
/// way (#1410). Text that is already display-sized does not need to: at the
/// largest accessibility sizes (about 3.1x on iOS) a 34 pt number becomes
/// over 100 pt and pushes everything else off a small screen, without being
/// any easier to read than at half that size. iOS does the same for its own
/// large titles. These ceilings apply only to such elements.
class TextScaleCeiling {
  TextScaleCeiling._();

  /// Big numbers ([BlokadaTypeScale.display]), such as the Home counter.
  static const display = 1.5;

  /// Screen and sheet headlines ([BlokadaTypeScale.hero] and larger), which
  /// should still wrap rather than be cut.
  static const headline = 2.0;

  /// The system text scale at which a screen should switch to its compact
  /// arrangement (stacked actions, smaller decoration): the iOS accessibility
  /// sizes start a little above it.
  static const compactFrom = 1.6;
}

/// Whether the system text scale is at accessibility sizes, where layouts
/// switch to their compact arrangement (see [TextScaleCeiling.compactFrom]).
bool isLargeTextScale(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1) >= TextScaleCeiling.compactFrom;

/// Caps the text scale of [child] at [max], leaving smaller scales as they are.
class MaxTextScale extends StatelessWidget {
  final double max;
  final Widget child;

  const MaxTextScale({super.key, required this.max, required this.child});

  @override
  Widget build(BuildContext context) =>
      MediaQuery.withClampedTextScaling(maxScaleFactor: max, child: child);
}

/// Text that wraps between words but never inside one.
///
/// Flutter breaks a word that is wider than the line mid-word ("Werbun-g"),
/// which happens with long (German) words at large text sizes. This shrinks
/// the text scale just enough for the widest word to fit the line, never
/// below the default size, so only text that would otherwise break mid-word
/// changes. [maxScale] optionally caps the scale as well, for headlines.
///
/// The fit is worked out during layout from the width given, so unlike a
/// LayoutBuilder it also works under widgets that measure their children's
/// intrinsic sizes, such as the Cupertino action sheet.
///
/// A [Text] subclass, so finders and code that look for Text (find.text)
/// still see it; only [data], [style] and [textAlign] are honoured.
class WordFitText extends Text {
  final double? maxScale;

  const WordFitText(String super.data, {super.key, super.style, super.textAlign, this.maxScale});

  String get text => data!;

  @override
  Widget build(BuildContext context) {
    var scaler = MediaQuery.textScalerOf(context);
    if (maxScale != null) scaler = scaler.clamp(maxScaleFactor: maxScale!);
    final defaults = DefaultTextStyle.of(context);
    var style = defaults.style.merge(this.style);
    if (MediaQuery.boldTextOf(context)) {
      style = style.merge(const TextStyle(fontWeight: FontWeight.bold));
    }
    return _WordFit(
      text: text,
      style: style,
      scaler: scaler,
      textAlign: textAlign ?? defaults.textAlign ?? TextAlign.start,
      textDirection: Directionality.of(context),
      locale: Localizations.maybeLocaleOf(context),
    );
  }
}

class _WordFit extends LeafRenderObjectWidget {
  final String text;
  final TextStyle style;
  final TextScaler scaler;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final Locale? locale;

  const _WordFit({
    required this.text,
    required this.style,
    required this.scaler,
    required this.textAlign,
    required this.textDirection,
    required this.locale,
  });

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderWordFit()..update(this);

  @override
  void updateRenderObject(BuildContext context, _RenderWordFit renderObject) =>
      renderObject.update(this);
}

/// Lays out and paints the text itself, so the scale can be fitted to the
/// width it is given during layout.
class _RenderWordFit extends RenderBox {
  /// Laid out by performLayout only, and painted.
  final _painter = TextPainter();

  /// For intrinsic and dry-layout queries, which may ask about other widths
  /// without a relayout following; they must not disturb [_painter].
  final _measurer = TextPainter();

  String? _text;
  TextStyle? _style;
  TextScaler? _scaler;

  void update(_WordFit widget) {
    final changed =
        widget.text != _text ||
        widget.style != _style ||
        widget.scaler != _scaler ||
        widget.textAlign != _painter.textAlign ||
        widget.textDirection != _painter.textDirection ||
        widget.locale != _painter.locale;
    if (!changed) return;
    _text = widget.text;
    _style = widget.style;
    _scaler = widget.scaler;
    for (final painter in [_painter, _measurer]) {
      painter
        ..text = TextSpan(text: widget.text, style: widget.style)
        ..textAlign = widget.textAlign
        ..textDirection = widget.textDirection
        ..locale = widget.locale;
    }
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  void _layoutText(TextPainter painter, double minWidth, double maxWidth) {
    painter.textScaler = fitWords(_text!, _style!, _scaler!, maxWidth);
    painter.layout(minWidth: minWidth, maxWidth: maxWidth);
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    _layoutText(_measurer, 0, double.infinity);
    return _measurer.minIntrinsicWidth;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    _layoutText(_measurer, 0, double.infinity);
    return _measurer.maxIntrinsicWidth;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    _layoutText(_measurer, 0, width);
    return _measurer.height;
  }

  @override
  double computeMaxIntrinsicHeight(double width) => computeMinIntrinsicHeight(width);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    _layoutText(_measurer, constraints.minWidth, constraints.maxWidth);
    return constraints.constrain(_measurer.size);
  }

  /// Read after performLayout, which laid [_painter] out for these constraints.
  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      _painter.computeDistanceToActualBaseline(baseline);

  @override
  void performLayout() {
    _layoutText(_painter, constraints.minWidth, constraints.maxWidth);
    size = constraints.constrain(_painter.size);
  }

  @override
  void paint(PaintingContext context, Offset offset) => _painter.paint(context.canvas, offset);

  /// Hit like Text does, so a GestureDetector around it (which by default
  /// only reacts where a child is hit) takes taps on the words.
  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..label = _text ?? ''
      ..textDirection = _painter.textDirection;
  }

  @override
  void dispose() {
    _painter.dispose();
    _measurer.dispose();
    super.dispose();
  }
}

/// [scaler], reduced so that the widest word of [text] fits [maxWidth]; see
/// [WordFitText]. Never reduces below the default (1.0) scale.
TextScaler fitWords(String text, TextStyle style, TextScaler scaler, double maxWidth) {
  if (!maxWidth.isFinite) return scaler;
  // Lines also break after a hyphen or slash, so those end a word too.
  final words = text.split(RegExp(r'\s+|(?<=[-/])')).where((w) => w.isNotEmpty);
  var widest = 0.0;
  for (final word in words) {
    final painter = TextPainter(
      text: TextSpan(text: word, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    if (painter.width > widest) widest = painter.width;
    painter.dispose();
  }
  if (widest <= maxWidth) return scaler;
  final fontSize = style.fontSize ?? 14;
  final current = scaler.scale(fontSize) / fontSize;
  // A little under the exact fit: glyph metrics don't scale perfectly linearly.
  final fit = current * maxWidth / widest * 0.97;
  final floor = current < 1.0 ? current : 1.0;
  return scaler.clamp(maxScaleFactor: fit > floor ? fit : floor);
}
