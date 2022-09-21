class AppModel {

  late AppState state;
  late bool working;
  late bool plus;

  AppModel({required this.state, required this.working, required this.plus});

  AppModel.fromJson(Map<String, dynamic> json) {
    state = _appStateFromJson(json['state']);
    working = json['working'];
    plus = json['plus'];
  }

  AppModel.empty({this.state = AppState.paused, this.working = false, this.plus = false});
}

enum AppState {
  deactivated, paused, activated;
}

AppState _appStateFromJson(String state) {
  switch (state) {
    case 'deactivated':
      return AppState.deactivated;
    case 'paused':
      return AppState.paused;
    case 'activated':
      return AppState.activated;
    default:
      throw Exception('Unknown state: $state');
  }
}