import 'package:common/src/core/core.dart';
import 'package:common/src/shared/ui/common_divider.dart';
import 'package:common/src/shared/ui/motion.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/material.dart';

/// Grey shapes standing in for content that is still loading, with a soft
/// shimmer sweeping across them. With Reduce Motion, or [animate] off, the
/// shapes stay still.
///
/// Shape the [child] like the content it replaces, from [PlaceholderBar]s,
/// so nothing jumps when the data arrives. [LoadingPlaceholder.rows] covers
/// the usual list.
class LoadingPlaceholder extends StatefulWidget {
  final Widget child;

  /// Off for a placeholder that is mounted but not on screen, so it doesn't
  /// keep drawing frames.
  final bool animate;

  const LoadingPlaceholder({super.key, required this.child, this.animate = true});

  /// [count] list rows, each a title bar and an optional [subtitle] bar,
  /// with an optional [leading] square, [rowHeight] tall and split by
  /// dividers indented by [dividerIndent] (none when null).
  LoadingPlaceholder.rows({
    super.key,
    int count = 3,
    double rowHeight = 56,
    bool subtitle = true,
    double? leading,
    double? dividerIndent,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 16),
    this.animate = true,
  }) : child = Column(
         mainAxisSize: MainAxisSize.min,
         children: [
           for (var i = 0; i < count; i++) ...[
             _PlaceholderRow(
               height: rowHeight,
               subtitle: subtitle,
               leading: leading,
               padding: padding,
               // Varied widths read as text rather than a grid.
               widthFactor: const [0.7, 0.5, 0.6][i % 3],
             ),
             if (dividerIndent != null && i < count - 1) CommonDivider(indent: dividerIndent),
           ],
         ],
       );

  @override
  State<StatefulWidget> createState() => LoadingPlaceholderState();
}

class LoadingPlaceholderState extends State<LoadingPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  bool _shimmer = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant LoadingPlaceholder oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    _shimmer = widget.animate && !Motion.reduced(context);
    if (_shimmer && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!_shimmer && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = "universal status loading".i18n;
    final shapes = ExcludeSemantics(child: widget.child);
    if (!_shimmer) return Semantics(label: label, child: shapes);

    final glow = context.theme.isDarkTheme()
        ? Colors.white.withOpacity(0.12)
        : Colors.white.withOpacity(0.6);
    return Semantics(
      label: label,
      child: AnimatedBuilder(
        animation: _controller,
        child: shapes,
        builder: (context, child) {
          return ShaderMask(
            // Paints only over the grey shapes; transparent elsewhere.
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) => LinearGradient(
              colors: [Colors.transparent, glow, Colors.transparent],
              stops: const [0.35, 0.5, 0.65],
              transform: _Slide(_controller.value),
            ).createShader(bounds),
            child: child,
          );
        },
      ),
    );
  }
}

/// Moves the gradient from fully left of the box to fully right of it.
class _Slide extends GradientTransform {
  final double progress;

  const _Slide(this.progress);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final dx = bounds.width * (progress * 2 - 1);
    return Matrix4.translationValues(dx, 0, 0);
  }
}

/// One grey rounded bar inside a [LoadingPlaceholder], e.g. a line of text.
class PlaceholderBar extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const PlaceholderBar({super.key, this.width, this.height = 14, this.radius = 4});

  static Color color(BuildContext context) => context.theme.textSecondary.withOpacity(0.18);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: color(context), borderRadius: BorderRadius.circular(radius)),
    );
  }
}

class _PlaceholderRow extends StatelessWidget {
  final double height;
  final bool subtitle;
  final double? leading;
  final EdgeInsetsGeometry padding;
  final double widthFactor;

  const _PlaceholderRow({
    required this.height,
    required this.subtitle,
    required this.leading,
    required this.padding,
    required this.widthFactor,
  });

  @override
  Widget build(BuildContext context) {
    final leading = this.leading;
    return SizedBox(
      height: height,
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            if (leading != null) ...[
              PlaceholderBar(width: leading, height: leading, radius: leading / 4),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: widthFactor,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PlaceholderBar(height: 14),
                    if (subtitle) ...[
                      const SizedBox(height: 8),
                      const FractionallySizedBox(
                        widthFactor: 0.5,
                        child: PlaceholderBar(height: 10),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
