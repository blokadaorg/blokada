part of '../../widget.dart';

class MiniCardSummary extends StatefulWidget {
  final MiniCardHeader header;
  final Widget overBig;
  final Widget big;
  final String small;
  final String? footer;

  const MiniCardSummary({
    super.key,
    this.overBig = const SizedBox(),
    required this.header,
    required this.big,
    required this.small,
    this.footer,
  });

  @override
  State<StatefulWidget> createState() => MiniCardSummaryState();
}

class MiniCardSummaryState extends State<MiniCardSummary> {
  var lastCounter = 0.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        widget.header,
        const SizedBox(height: 20),
        widget.overBig,
        Row(
          textBaseline: TextBaseline.alphabetic,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          children: [
            widget.big,
            const SizedBox(width: 4),
            Text(
              widget.small,
              style: TextStyle(
                fontSize: 18,
                color: context.theme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (widget.footer != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.footer!,
              style: TextStyle(
                fontSize: 14,
                color: context.theme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
