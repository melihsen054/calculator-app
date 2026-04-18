import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/currency_service.dart';

// ─── Unit data ─────────────────────────────────────────────────────────────

class _UnitDef {
  final String label;
  final double factor; // value * factor = base unit; 0 signals temperature

  const _UnitDef(this.label, this.factor);
}

class _UnitCat {
  final String name;
  final List<_UnitDef> units;

  const _UnitCat(this.name, this.units);

  bool get isTemp => name == 'Sıcaklık';
}

const _unitCategories = [
  _UnitCat('Uzunluk', [
    _UnitDef('m', 1),
    _UnitDef('km', 1000),
    _UnitDef('cm', 0.01),
    _UnitDef('mm', 0.001),
    _UnitDef('ft', 0.3048),
    _UnitDef('inç', 0.0254),
    _UnitDef('mil', 1609.344),
  ]),
  _UnitCat('Ağırlık', [
    _UnitDef('kg', 1),
    _UnitDef('g', 0.001),
    _UnitDef('lb', 0.453592),
    _UnitDef('oz', 0.0283495),
    _UnitDef('ton', 1000),
  ]),
  _UnitCat('Sıcaklık', [
    _UnitDef('°C', 0),
    _UnitDef('°F', 0),
    _UnitDef('K', 0),
  ]),
  _UnitCat('Alan', [
    _UnitDef('m²', 1),
    _UnitDef('km²', 1e6),
    _UnitDef('ft²', 0.092903),
    _UnitDef('dönüm', 1000),
    _UnitDef('hektar', 10000),
  ]),
  _UnitCat('Hız', [
    _UnitDef('m/s', 1),
    _UnitDef('km/s', 1000),
    _UnitDef('mph', 0.44704),
    _UnitDef('knot', 0.514444),
  ]),
];

double _convertUnit(_UnitDef from, _UnitDef to, double value, bool isTemp) {
  if (isTemp) {
    return _convertTemp(value, from.label, to.label);
  }
  return value * from.factor / to.factor;
}

double _convertTemp(double v, String from, String to) {
  final celsius = switch (from) {
    '°F' => (v - 32) * 5 / 9,
    'K'  => v - 273.15,
    _    => v,
  };
  return switch (to) {
    '°F' => celsius * 9 / 5 + 32,
    'K'  => celsius + 273.15,
    _    => celsius,
  };
}

String _fmtNum(double val, {int precision = 8}) {
  if (val.isNaN || val.isInfinite) return '—';
  if (val == val.truncateToDouble() && val.abs() < 1e12) {
    return val.toInt().toString();
  }
  String s = val.toStringAsPrecision(precision);
  if (s.contains('.')) {
    s = s
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }
  return s;
}

// ─── Screen ────────────────────────────────────────────────────────────────

class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key});

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  int _catIndex = 0; // 0 = Para, 1-5 = unit categories

  static const _catLabels = [
    'Para', 'Uzunluk', 'Ağırlık', 'Sıcaklık', 'Alan', 'Hız',
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        title: Text('Dönüştürücü',
            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w400)),
        iconTheme: IconThemeData(color: cs.primary),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Category chips
          SizedBox(
            height: 54,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _catLabels.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(_catLabels[i]),
                  selected: _catIndex == i,
                  onSelected: (_) => setState(() => _catIndex = i),
                  selectedColor: cs.primaryContainer,
                  labelStyle: TextStyle(
                    color: _catIndex == i
                        ? cs.onPrimaryContainer
                        : cs.onSurface,
                    fontWeight: _catIndex == i
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                  showCheckmark: false,
                ),
              ),
            ),
          ),

          Divider(
              color: cs.outlineVariant.withValues(alpha: 0.4), height: 1),

          Expanded(
            child: IndexedStack(
              index: _catIndex,
              children: [
                const _CurrencyPanel(),
                ..._unitCategories.map((c) => _UnitPanel(category: c)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Currency panel ────────────────────────────────────────────────────────

class _CurrencyPanel extends StatefulWidget {
  const _CurrencyPanel();

  @override
  State<_CurrencyPanel> createState() => _CurrencyPanelState();
}

class _CurrencyPanelState extends State<_CurrencyPanel> {
  final _service = CurrencyService();
  final _ctrl = TextEditingController(text: '1');

  Map<String, double> _rates = {};
  DateTime? _updatedAt;
  bool _isStale = false;
  bool _loading = true;
  bool _hasError = false;

  String _from = 'USD';
  String _to = 'TRY';

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    final result = await _service.getRates();
    if (!mounted) return;
    if (result.rates.isEmpty) {
      setState(() {
        _loading = false;
        _hasError = true;
      });
    } else {
      setState(() {
        _rates = result.rates;
        _updatedAt = result.updatedAt;
        _isStale = result.isStale;
        _loading = false;
      });
    }
  }

  String get _resultStr {
    final amount = double.tryParse(_ctrl.text.replaceAll(',', '.'));
    if (amount == null || _rates.isEmpty) return '—';
    final fromRate = _rates[_from];
    final toRate = _rates[_to];
    if (fromRate == null || toRate == null) return '—';
    final result = amount * toRate / fromRate;
    return _fmtNum(result, precision: 6);
  }

  void _swap() => setState(() {
        final tmp = _from;
        _from = _to;
        _to = tmp;
      });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: cs.primary));
    }

    if (_hasError && _rates.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, color: cs.error, size: 52),
            const SizedBox(height: 12),
            Text('Kur bilgisi alınamadı',
                style: TextStyle(color: cs.error)),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _load,
              child: const Text('Yeniden dene'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        children: [
          _ConvCard(
            isInput: true,
            controller: _ctrl,
            dropdownValue: _from,
            items: CurrencyService.currencies,
            itemLabel: (c) =>
                '$c  ${CurrencyService.symbols[c] ?? ''}',
            onChanged: (v) => setState(() => _from = v!),
          ),
          _SwapButton(onTap: _swap),
          _ConvCard(
            isInput: false,
            resultText: _resultStr,
            dropdownValue: _to,
            items: CurrencyService.currencies,
            itemLabel: (c) =>
                '$c  ${CurrencyService.symbols[c] ?? ''}',
            onChanged: (v) => setState(() => _to = v!),
          ),
          const SizedBox(height: 16),
          if (_rates.isNotEmpty)
            _RateInfoBar(
              from: _from,
              to: _to,
              rates: _rates,
              updatedAt: _updatedAt,
              isStale: _isStale,
              onRefresh: _load,
            ),
        ],
      ),
    );
  }
}

// ─── Unit panel ────────────────────────────────────────────────────────────

class _UnitPanel extends StatefulWidget {
  final _UnitCat category;

  const _UnitPanel({required this.category});

  @override
  State<_UnitPanel> createState() => _UnitPanelState();
}

class _UnitPanelState extends State<_UnitPanel> {
  final _ctrl = TextEditingController(text: '1');
  int _fromIdx = 0;
  int _toIdx = 1;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _resultStr {
    final v = double.tryParse(_ctrl.text.replaceAll(',', '.'));
    if (v == null) return '—';
    final result = _convertUnit(
      widget.category.units[_fromIdx],
      widget.category.units[_toIdx],
      v,
      widget.category.isTemp,
    );
    return _fmtNum(result);
  }

  void _swap() => setState(() {
        final tmp = _fromIdx;
        _fromIdx = _toIdx;
        _toIdx = tmp;
      });

  @override
  Widget build(BuildContext context) {
    final labels = widget.category.units.map((u) => u.label).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        children: [
          _ConvCard(
            isInput: true,
            controller: _ctrl,
            dropdownValue: labels[_fromIdx],
            items: labels,
            itemLabel: (s) => s,
            onChanged: (v) =>
                setState(() => _fromIdx = labels.indexOf(v!)),
          ),
          _SwapButton(onTap: _swap),
          _ConvCard(
            isInput: false,
            resultText: _resultStr,
            dropdownValue: labels[_toIdx],
            items: labels,
            itemLabel: (s) => s,
            onChanged: (v) =>
                setState(() => _toIdx = labels.indexOf(v!)),
          ),
        ],
      ),
    );
  }
}

// ─── Shared sub-widgets ─────────────────────────────────────────────────────

class _ConvCard extends StatelessWidget {
  final bool isInput;
  final TextEditingController? controller;
  final String? resultText;
  final String dropdownValue;
  final List<String> items;
  final String Function(String) itemLabel;
  final void Function(String?)? onChanged;

  const _ConvCard({
    required this.isInput,
    required this.dropdownValue,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.controller,
    this.resultText,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Amount field / result
          if (isInput)
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9,.\-]')),
              ],
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w300,
                color: cs.onSurface,
                letterSpacing: -1,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                hintText: '0',
                hintStyle: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.25),
                    fontSize: 42,
                    fontWeight: FontWeight.w300),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                resultText ?? '—',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w300,
                  color: cs.primary,
                  letterSpacing: -1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // Unit dropdown
          DropdownButton<String>(
            value: dropdownValue,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: cs.surfaceContainerHighest,
            icon: Icon(Icons.expand_more, color: cs.primary, size: 20),
            style: TextStyle(
                fontSize: 15,
                color: cs.onSurface,
                fontWeight: FontWeight.w500),
            items: items
                .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(
                        itemLabel(s),
                        style: TextStyle(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w500),
                      ),
                    ))
                .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SwapButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SwapButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Material(
          color: cs.primaryContainer,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(Icons.swap_vert,
                  color: cs.onPrimaryContainer, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

class _RateInfoBar extends StatelessWidget {
  final String from;
  final String to;
  final Map<String, double> rates;
  final DateTime? updatedAt;
  final bool isStale;
  final VoidCallback onRefresh;

  const _RateInfoBar({
    required this.from,
    required this.to,
    required this.rates,
    required this.updatedAt,
    required this.isStale,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fromRate = rates[from];
    final toRate = rates[to];
    final rate =
        (fromRate != null && toRate != null) ? toRate / fromRate : null;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: isStale
            ? Border.all(
                color: cs.error.withValues(alpha: 0.4), width: 1)
            : null,
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rate != null)
                  Text(
                    '1 $from = ${_fmtRate(rate)} $to',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface),
                  ),
                if (updatedAt != null)
                  Text(
                    '${isStale ? 'Eski veri  ·  ' : ''}${_fmtDate(updatedAt!)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isStale
                          ? cs.error
                          : cs.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded,
                size: 18, color: cs.primary),
            onPressed: onRefresh,
            splashRadius: 18,
            tooltip: 'Güncelle',
          ),
        ],
      ),
    );
  }

  String _fmtRate(double r) {
    if (r >= 100) return r.toStringAsFixed(2);
    if (r >= 1) return r.toStringAsFixed(4);
    return r.toStringAsPrecision(4);
  }

  String _fmtDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day) {
      return 'Bugün '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
