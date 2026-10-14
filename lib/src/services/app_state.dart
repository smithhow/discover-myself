class AppState {
  List<int>? key;
  int activeProfile = 0;

  void lock() {
    key = null;
  }
}
