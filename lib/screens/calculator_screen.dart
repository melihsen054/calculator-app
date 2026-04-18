import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:provider/provider.dart';
import '../models/theme_notifier.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _expression = '';
  String _display = '0';
  bool _justEvaluated = false;

  static const _buttons = [
    ['C', '+/-', '%', '÷'],
    ['7', '8', '9', '×'],
    ['4', '5', '6', '-'],
    ['1', '2', '3', '+'],
    ['⌫', '0', ',', '='],
  ];

  void _onButton(String label) {
    setState(() {
      switch (label) {
        case 'C':
          _expression = '';
          _display = '0';
          _justEvaluated = false;

        case '⌫':
          if (_justEvaluated) {
            _expression = '';
            _display = '0';
            _justEvaluated = false;
          } else if (_display.length > 1) {
            _display = _display.substring(0, _display.length - 1);
          } else {
            _display = '0';
          }

        case '+/-':
          if (_display != '0') {
            _display =
                _display.startsWith('-') ? _display.substring(1) : '-$_display';
          }

        case '%':
          final val = double.tryParse(_display.replaceAll(',', '.'));
          if (val != null) _display = _formatNumber(val / 100);

        case '÷':
        case '×':
        case '-':
        case '+':
          if (_justEvaluated) {
            _expression = '$_display $label ';
            _justEvaluated = false;
            _display = '0';
          } else if (_display == '0' && _expression.isNotEmpty) {
            // Operator değiştir
            final trimmed = _expression.trimRight();
            final lastSpace = trimmed.lastIndexOf(' ');
            _expression = '${trimmed.substring(0, lastSpace + 1)}$label ';
          } else {
            _expression = '$_expression$_display $label ';
            _display = '0';
          }

        case '=':
          final fullExpr = '$_expression$_display';
          _expression = '$fullExpr =';
          _display = _evaluate(fullExpr);
          _justEvaluated = true;

        case ',':
          if (_justEvaluated) {
            _display = '0,';
            _expression = '';
            _justEvaluated = false;
          } else if (!_display.contains(',')) {
            _display = '$_display,';
          }

        default:
          if (_justEvaluated) {
            _display = label;
            _expression = '';
            _justEvaluated = false;
          } else {
            _display = _display == '0' ? label : '$_display$label';
          }
      }
    });
  }

  String _evaluate(String expr) {
    try {
      final normalized = expr
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll(',', '.');
      final p = GrammarParser();
      final e = p.parse(normalized);
      final cm = ContextModel();
      final result = e.evaluate(EvaluationType.REAL, cm) as double;
      if (result.isInfinite) return 'Sıfıra bölünemez';
      if (result.isNaN) return 'Hata';
      return _formatNumber(result);
    } catch (_) {
      return 'Hata';
    }
  }

  String _formatNumber(double val) {
    if (val == val.truncateToDouble() && val.abs() < 1e15) {
      return val.toInt().toString();
    }
    String s = val.toStringAsPrecision(10);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return s.replaceAll('.', ',');
  }

  Color _bgColor(String label, ColorScheme cs) {
    if (label == '=') return cs.primary;
    if (const ['÷', '×', '-', '+'].contains(label)) return cs.primaryContainer;
    if (const ['C', '+/-', '%', '⌫'].contains(label)) {
      return cs.surfaceContainerHighest;
    }
    return cs.surfaceContainer;
  }

  Color _fgColor(String label, ColorScheme cs) {
    if (label == '=') return cs.onPrimary;
    if (const ['÷', '×', '-', '+'].contains(label)) return cs.primary;
    if (const ['C', '+/-', '%', '⌫'].contains(label)) return cs.onSurface;
    return cs.onSurface;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final themeNotifier = context.watch<ThemeNotifier>();

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Başlık & tema butonu
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hesap Makinesi',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.4),
                          letterSpacing: 0.5,
                        ),
                  ),
                  IconButton(
                    icon: Icon(
                      themeNotifier.isDark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                      size: 20,
                    ),
                    color: cs.primary,
                    onPressed: themeNotifier.toggle,
                    splashRadius: 20,
                  ),
                ],
              ),
            ),

            // Ekran
            Expanded(
              flex: 3,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // İşlem satırı
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: Text(
                        _expression,
                        key: ValueKey(_expression),
                        style: TextStyle(
                          fontSize: 17,
                          height: 1.4,
                          color: cs.onSurface.withValues(alpha: 0.38),
                          fontWeight: FontWeight.w300,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Sonuç satırı
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        _display,
                        style: TextStyle(
                          fontSize: 76,
                          fontWeight: FontWeight.w300,
                          color: cs.onSurface,
                          letterSpacing: -2,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            Divider(color: cs.outlineVariant.withValues(alpha: 0.4), height: 1),

            // Buton ızgarası
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                child: Column(
                  children: _buttons.asMap().entries.map((entry) {
                    final rowIndex = entry.key;
                    final row = entry.value;
                    // Alt satırlar biraz daha büyük
                    final flex = rowIndex >= 3 ? 13 : 11;
                    return Expanded(
                      flex: flex,
                      child: Row(
                        children: row.map((label) {
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(5),
                              child: _CalcButton(
                                label: label,
                                backgroundColor: _bgColor(label, cs),
                                foregroundColor: _fgColor(label, cs),
                                isLarge: rowIndex >= 3,
                                onTap: () => _onButton(label),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalcButton extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool isLarge;
  final VoidCallback onTap;

  const _CalcButton({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.isLarge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Center(child: _content()),
      ),
    );
  }

  Widget _content() {
    if (label == '⌫') {
      return Icon(Icons.backspace_outlined,
          color: foregroundColor, size: isLarge ? 24 : 21);
    }
    return Text(
      label,
      style: TextStyle(
        fontSize: isLarge ? 28 : 23,
        fontWeight:
            label == '=' ? FontWeight.w600 : FontWeight.w400,
        color: foregroundColor,
        height: 1,
      ),
    );
  }
}
