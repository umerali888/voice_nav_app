import 'package:flutter/foundation.dart';
import '../models/assistant_state.dart';

class AssistantController extends ChangeNotifier {
  AssistantState _state = AssistantState.idle;
  String _lastText = '';

  AssistantState get state => _state;
  String get lastText => _lastText;

  void setState(AssistantState newState) {
    _state = newState;
    notifyListeners();
  }

  void setText(String text) {
    _lastText = text;
    notifyListeners();
  }
}
