import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

typedef RateResult = ({
  Map<String, double> rates,
  DateTime? updatedAt,
  bool isStale,
});

class CurrencyService {
  static const _ratesKey = 'fx_rates_v1';
  static const _tsKey = 'fx_ts_v1';
  static const _ttl = Duration(hours: 24);

  static const currencies = [
    'USD', 'TRY', 'EUR', 'GBP', 'JPY', 'CHF', 'CAD', 'AUD', 'SAR', 'AED',
  ];

  static const symbols = {
    'USD': r'$',  'TRY': '₺', 'EUR': '€', 'GBP': '£', 'JPY': '¥',
    'CHF': 'Fr', 'CAD': r'C$', 'AUD': r'A$', 'SAR': '﷼', 'AED': 'د.إ',
  };

  Future<RateResult> getRates() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_ratesKey);
    final ts = prefs.getInt(_tsKey);
    final ageMs = ts != null
        ? DateTime.now().millisecondsSinceEpoch - ts
        : _ttl.inMilliseconds + 1;

    if (cached != null && ageMs < _ttl.inMilliseconds) {
      return (
        rates: _decode(cached),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(ts!),
        isStale: false,
      );
    }

    try {
      final resp = await http
          .get(Uri.parse('https://api.frankfurter.app/latest?from=USD'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final raw = data['rates'] as Map<String, dynamic>;
        final rates = <String, double>{'USD': 1.0};
        for (final e in raw.entries) {
          if (currencies.contains(e.key)) {
            rates[e.key] = (e.value as num).toDouble();
          }
        }
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        await prefs.setString(_ratesKey, jsonEncode(rates));
        await prefs.setInt(_tsKey, nowMs);
        return (
          rates: rates,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(nowMs),
          isStale: false,
        );
      }
    } catch (_) {}

    if (cached != null && ts != null) {
      return (
        rates: _decode(cached),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(ts),
        isStale: true,
      );
    }

    return (rates: <String, double>{}, updatedAt: null, isStale: true);
  }

  Map<String, double> _decode(String raw) =>
      Map<String, double>.from(jsonDecode(raw) as Map);
}
