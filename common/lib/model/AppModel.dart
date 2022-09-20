class AppModel {

  late AppState state;
  late bool working;

  AppModel({required this.state, required this.working});

  AppModel.fromJson(Map<String, dynamic> json) {
    state = _appStateFromJson(json['state']);
    working = json['working'];
  }

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