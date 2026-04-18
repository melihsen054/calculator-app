import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:provider/provider.dart';
import '../models/theme_notifier.dart';
import '../services/history_service.dart';
import 'converter_screen.dart';

// ─── Button layout ────────────────────────────────────────────────────────────

const _standardButtons = [
  ['C', '+/-', '%', '÷'],
  ['7', '8', '9', '×'],
  ['4', '5', '6', '-'],
  ['1', '2', '3', '+'],
  ['⌫', '0', ',', '='],
];

// Scientific panel: 4 cols × 3 rows shown left of standard grid in landscape
const _scientificButtons = [
  ['(', ')', 'xʸ', '√'],
  ['sin', 'cos', 'tan', 'x²'],
  ['log', 'ln', 'π', 'e'],
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});
  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _expression = '';
  String _display = '0';
  bool _justEvaluated = false;
  bool _useDegrees = true; // derece/radyan toggle

  // ── Button handler ──────────────────────────────────────────────────────────

  void _onButton(String label) {
    setState(() {
      switch (label) {
        // ── Clear / backspace
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

        // ── Sign / percent
        case '+/-':
          if (_display != '0') {
            _display = _display.startsWith('-')
                ? _display.substring(1)
                : '-$_display';
          }

        case '%':
          final v = double.tryParse(_display.replaceAll(',', '.'));
          if (v != null) _display = _formatNumber(v / 100);

        // ── Arithmetic operators
        case '÷':
        case '×':
        case '-':
        case '+':
          if (_justEvaluated) {
            _expression = '$_display $label ';
            _justEvaluated = false;
            _display = '0';
          } else if (_display == '0' && _expression.isNotEmpty) {
            final trimmed = _expression.trimRight();
            final last = trimmed.lastIndexOf(' ');
            _expression = '${trimmed.substring(0, last + 1)}$label ';
          } else {
            _expression = '$_expression$_display $label ';
            _display = '0';
          }

        // ── Equals
        case '=':
          final fullExpr = '$_expression$_display';
          final result = _evaluate(fullExpr);
          _expression = '$fullExpr =';
          _display = result;
          _justEvaluated = true;
          // persist to history (fire-and-forget)
          context
              .read<HistoryService>()
              .add(fullExpr, result);

        // ── Decimal
        case ',':
          if (_justEvaluated) {
            _display = '0,';
            _expression = '';
            _justEvaluated = false;
          } else if (!_display.contains(',')) {
            _display = '$_display,';
          }

        // ── Parentheses (append to expression directly)
        case '(':
        case ')':
          if (_justEvaluated) { _expression = ''; _justEvaluated = false; }
          _expression = '$_expression$label';

        // ── Power  xʸ  → append ^ operator, keep display
        case 'xʸ':
          _expression = '$_expression$_display^';
          _display = '0';
          _justEvaluated = false;

        // ── x²  → evaluate display²
        case 'x²':
          final v = double.tryParse(_display.replaceAll(',', '.'));
          if (v != null) _display = _formatNumber(v * v);

        // ── Square root
        case '√':
          final v = double.tryParse(_display.replaceAll(',', '.'));
          if (v != null) {
            _display = v < 0 ? 'Hata' : _formatNumber(math.sqrt(v));
          }

        // ── Trig
        case 'sin':
        case 'cos':
        case 'tan':
          final v = double.tryParse(_display.replaceAll(',', '.'));
          if (v != null) {
            final rad = _useDegrees ? v * math.pi / 180 : v;
            double res;
            if (label == 'sin') {
              res = math.sin(rad);
            } else if (label == 'cos') {
              res = math.cos(rad);
            } else {
              res = math.tan(rad);
            }
            // tan(90°) guard
            if (res.abs() > 1e10) {
              _display = 'Tanımsız';
            } else {
              _display = _formatNumber(res);
            }
          }

        // ── log / ln
        case 'log':
          final v = double.tryParse(_display.replaceAll(',', '.'));
          if (v != null) {
            _display = v <= 0 ? 'Hata' : _formatNumber(math.log(v) / math.ln10);
          }

        case 'ln':
          final v = double.tryParse(_display.replaceAll(',', '.'));
          if (v != null) {
            _display = v <= 0 ? 'Hata' : _formatNumber(math.log(v));
          }

        // ── Constants
        case 'π':
          _display = _formatNumber(math.pi);
          _justEvaluated = false;

        case 'e':
          _display = _formatNumber(math.e);
          _justEvaluated = false;

        // ── Digits
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

  // ── Evaluate ─────────────────────────────────────────────────────────────

  String _evaluate(String expr) {
    try {
      final normalized = expr
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll(',', '.');
      final e = GrammarParser().parse(normalized);
      final result =
          e.evaluate(EvaluationType.REAL, ContextModel()) as double;
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
      s = s
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');
    }
    return s.replaceAll('.', ',');
  }

  // ── Colors ────────────────────────────────────────────────────────────────

  static const _operatorBtns = ['÷', '×', '-', '+'];
  static const _functionBtns = ['C', '+/-', '%', '⌫'];
  static const _scientificFnBtns = [
    'sin', 'cos', 'tan', 'log', 'ln', '√', 'x²', 'xʸ', 'π', 'e', '(', ')',
  ];

  Color _bgColor(String label, ColorScheme cs) {
    if (label == '=') return cs.primary;
    if (_operatorBtns.contains(label)) return cs.primaryContainer;
    if (_functionBtns.contains(label)) return cs.surfaceContainerHighest;
    if (_scientificFnBtns.contains(label)) return cs.secondaryContainer;
    return cs.surfaceContainer;
  }

  Color _fgColor(String label, ColorScheme cs) {
    if (label == '=') return cs.onPrimary;
    if (_operatorBtns.contains(label)) return cs.primary;
    if (_scientificFnBtns.contains(label)) return cs.onSecondaryContainer;
    return cs.onSurface;
  }

  // ── History bottom sheet ─────────────────────────────────────────────────

  void _showHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _HistorySheet(
        onSelect: (expr, result) {
          setState(() {
            _display = result;
            _expression = '$expr =';
            _justEvaluated = true;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final isLandscape = orientation == Orientation.landscape;
        return isLandscape
            ? _buildLandscape(context)
            : _buildPortrait(context);
      },
    );
  }

  Widget _buildPortrait(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final themeNotifier = context.watch<ThemeNotifier>();

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            _header(context, cs, themeNotifier),
            _displayArea(context, cs, flex: 3),
            Divider(color: cs.outlineVariant.withValues(alpha: 0.4), height: 1),
            _standardGrid(context, cs, flex: 5),
          ],
        ),
      ),
    );
  }

  Widget _buildLandscape(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final themeNotifier = context.watch<ThemeNotifier>();

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            _header(context, cs, themeNotifier, compact: true),
            Expanded(
              child: Row(
                children: [
                  // Scientific panel (left)
                  Expanded(
                    flex: 5,
                    child: _scientificPanel(context, cs),
                  ),
                  VerticalDivider(
                    color: cs.outlineVariant.withValues(alpha: 0.4),
                    width: 1,
                  ),
                  // Standard grid (right) + display on top
                  Expanded(
                    flex: 6,
                    child: Column(
                      children: [
                        _displayArea(context, cs, flex: 2, compact: true),
                        Divider(
                          color: cs.outlineVariant.withValues(alpha: 0.4),
                          height: 1,
                        ),
                        _standardGrid(context, cs, flex: 5),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sub-widgets ───────────────────────────────────────────────────────────

  Widget _header(
    BuildContext context,
    ColorScheme cs,
    ThemeNotifier themeNotifier, {
    bool compact = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: 20, vertical: compact ? 2 : 6),
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.swap_horiz, size: 20),
                color: cs.primary,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ConverterScreen()),
                ),
                splashRadius: 20,
              ),
              IconButton(
                icon: const Icon(Icons.history, size: 20),
                color: cs.primary,
                onPressed: () => _showHistory(context),
                splashRadius: 20,
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
        ],
      ),
    );
  }

  Widget _displayArea(
    BuildContext context,
    ColorScheme cs, {
    required int flex,
    bool compact = false,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: 28, vertical: compact ? 4 : 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Text(
                _expression,
                key: ValueKey(_expression),
                style: TextStyle(
                  fontSize: compact ? 13 : 17,
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
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                _display,
                style: TextStyle(
                  fontSize: compact ? 48 : 76,
                  fontWeight: FontWeight.w300,
                  color: cs.onSurface,
                  letterSpacing: -2,
                  height: 1.1,
                ),
              ),
            ),
            SizedBox(height: compact ? 4 : 12),
          ],
        ),
      ),
    );
  }

  Widget _standardGrid(BuildContext context, ColorScheme cs,
      {required int flex}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        child: Column(
          children: _standardButtons.asMap().entries.map((entry) {
            final rowIndex = entry.key;
            final row = entry.value;
            final rowFlex = rowIndex >= 3 ? 13 : 11;
            return Expanded(
              flex: rowFlex,
              child: Row(
                children: row.map((label) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
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
    );
  }

  Widget _scientificPanel(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 12),
      child: Column(
        children: [
          // Deg/Rad toggle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: GestureDetector(
              onTap: () => setState(() => _useDegrees = !_useDegrees),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _useDegrees
                      ? cs.primaryContainer
                      : cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _useDegrees ? 'DEG' : 'RAD',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _useDegrees
                        ? cs.onPrimaryContainer
                        : cs.onSecondaryContainer,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
          // Scientific button rows
          ..._scientificButtons.map((row) {
            return Expanded(
              child: Row(
                children: row.map((label) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: _CalcButton(
                        label: label,
                        backgroundColor: _bgColor(label, cs),
                        foregroundColor: _fgColor(label, cs),
                        isLarge: false,
                        fontSize: 13,
                        onTap: () => _onButton(label),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── History bottom sheet ──────────────────────────────────────────────────

class _HistorySheet extends StatelessWidget {
  final void Function(String expression, String result) onSelect;

  const _HistorySheet({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final service = context.watch<HistoryService>();
    final items = service.items;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollCtrl) {
        return Column(
          children: [
            // Handle + title row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text('Geçmiş',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  if (items.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        service.clearAll();
                      },
                      child: Text('Tümünü sil',
                          style: TextStyle(color: cs.error)),
                    ),
                ],
              ),
            ),
            Divider(color: cs.outlineVariant.withValues(alpha: 0.4)),
            // List
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        'Henüz hesaplama yok',
                        style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.4)),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollCtrl,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Dismissible(
                          key: ValueKey(item.timestamp),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: cs.errorContainer,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: Icon(Icons.delete_outline,
                                color: cs.onErrorContainer),
                          ),
                          onDismissed: (_) => service.removeAt(index),
                          child: ListTile(
                            onTap: () {
                              // strip trailing " =" from expression
                              final expr = item.expression
                                  .replaceAll(RegExp(r'\s*=\s*$'), '');
                              onSelect(expr, item.result);
                            },
                            title: Text(
                              item.expression,
                              style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurface.withValues(alpha: 0.5),
                              ),
                              textAlign: TextAlign.right,
                            ),
                            subtitle: Text(
                              item.result,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w300,
                                color: cs.onSurface,
                              ),
                              textAlign: TextAlign.right,
                            ),
                            trailing: Text(
                              _formatTime(item.timestamp),
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface.withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}';
  }
}

// ─── Button widget ──────────────────────────────────────────────────────────

class _CalcButton extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool isLarge;
  final double? fontSize;
  final VoidCallback onTap;

  const _CalcButton({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.isLarge,
    required this.onTap,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Center(child: _content()),
      ),
    );
  }

  Widget _content() {
    if (label == '⌫') {
      return Icon(Icons.backspace_outlined,
          color: foregroundColor, size: isLarge ? 24 : 20);
    }
    final size = fontSize ?? (isLarge ? 28.0 : 22.0);
    return Text(
      label,
      style: TextStyle(
        fontSize: size,
        fontWeight: label == '=' ? FontWeight.w600 : FontWeight.w400,
        color: foregroundColor,
        height: 1,
      ),
    );
  }
}
