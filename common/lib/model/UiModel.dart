class UiStats {

  final int allowed;
  final int blocked;

  final List<int> hourlyAllowed;
  final List<int> hourlyBlocked;

  UiStats({
    required this.allowed, required this.blocked,
    required this.hourlyAllowed, required this.hourlyBlocked
  });

}