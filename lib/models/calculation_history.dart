class CalculationHistory {
  final String expression;
  final String result;
  final DateTime timestamp;

  const CalculationHistory({
    required this.expression,
    required this.result,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'expression': expression,
        'result': result,
        'timestamp': timestamp.toIso8601String(),
      };

  factory CalculationHistory.fromJson(Map<String, dynamic> j) =>
      CalculationHistory(
        expression: j['expression'] as String,
        result: j['result'] as String,
        timestamp: DateTime.parse(j['timestamp'] as String),
      );
}
