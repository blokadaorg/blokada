part of '../../widget.dart';

class MiniCardCounter extends StatefulWidget {
  final double counter;

  const MiniCardCounter({
    super.key,
    required this.counter,
  });

  @override
  State<StatefulWidget> createState() => MiniCardCounterState();
}

class MiniCardCounterState extends State<MiniCardCounter> {
  var lastCounter = 0.0; // TODO: use this actually

  @override
  Widget build(BuildContext context) {
    return Countup(
      begin: lastCounter,
      end: widget.counter,
      duration: const Duration(seconds: 1),
      style: const TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
