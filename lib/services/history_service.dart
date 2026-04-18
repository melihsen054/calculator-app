import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/calculation_history.dart';

class HistoryService extends ChangeNotifier {
  static const _key = 'calc_history';
  static const _maxRecords = 100;

  final List<CalculationHistory> _items = [];
  List<CalculationHistory> get items => List.unmodifiable(_items);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    _items
      ..clear()
      ..addAll(
        raw.map((s) => CalculationHistory.fromJson(
            jsonDecode(s) as Map<String, dynamic>)),
      );
    notifyListeners();
  }

  Future<void> add(String expression, String result) async {
    _items.insert(
      0,
      CalculationHistory(
        expression: expression,
        result: result,
        timestamp: DateTime.now(),
      ),
    );
    if (_items.length > _maxRecords) _items.removeLast();
    await _persist();
    notifyListeners();
  }

  Future<void> removeAt(int index) async {
    _items.removeAt(index);
    await _persist();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _items.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      _items.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }
}
