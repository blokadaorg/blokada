part of '../../widget.dart';

class FilterOptionWidget extends StatefulWidget {
  final Option option;
  final List<String> selections;

  const FilterOptionWidget(
      {super.key, required this.option, required this.selections});

  @override
  State<StatefulWidget> createState() => FilterOptionWidgetState();
}

class FilterOptionWidgetState extends State<FilterOptionWidget> {
  bool selected = false;

  @override
  void initState() {
    super.initState();
    selected = widget.selections.contains(widget.option.optionName);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        child: Container(
            child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              TwoLetterIconWidget(name: widget.option.optionName, big: true),
              const SizedBox(width: 12.0),
              Text(widget.option.optionName.firstLetterUppercase()),
              Expanded(child: Container()),
              CupertinoSwitch(
                activeColor: context.theme.accent,
                value: selected,
                onChanged: (bool? value) {
                  setState(() {
                    selected = value!;
                  });
                },
              ),
            ],
          ),
        )),
      );
}
