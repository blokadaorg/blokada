part of '../../widget.dart';

class MiniCard extends StatelessWidget {
  final Color? color;
  final bool? outlined;
  final Widget child;
  final VoidCallback? onTap;

  const MiniCard({
    super.key,
    required this.child,
    this.color,
    this.outlined,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    return Touch(
      onTap: onTap,
      maxValue: 0.7,
      decorationBuilder: (value) {
        return BoxDecoration(
          border: outlined == true
              ? Border.all(color: _getBgColor(theme), width: 1.0)
              : null,
          color: (outlined == true)
              ? _getBgColor(theme)?.withOpacity(value)
              : (value > 0.0
                  ? _getBgColor(theme).withOpacity(1.0 - min(value, 0.5))
                  : _getBgColor(theme)),
          borderRadius: BorderRadius.circular(12),
        );
      },
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      child: child,
    );
  }

  _getBgColor(BlokadaTheme theme) => color ?? theme.bgMiniCard;
}
