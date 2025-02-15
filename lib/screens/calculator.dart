import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:math_expressions/math_expressions.dart';

class Calculator extends StatefulWidget {
  const Calculator({super.key});

  @override
  State<Calculator> createState() => _CalculatorState();
}

class _CalculatorState extends State<Calculator> {
  String _display = '0';
  String _expression = '';
  final List<String> _history = [];
  final _inputController = TextEditingController();
  final List<String> _buttons = [
    'C',
    '%',
    '←',
    '/',
    '7',
    '8',
    '9',
    'x',
    '4',
    '5',
    '6',
    '-',
    '1',
    '2',
    '3',
    '+',
    '0',
    '.',
    '=',
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('calculator_history') ?? [];
    setState(() {
      _history.addAll(historyJson);
    });
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('calculator_history', _history);
  }

  void _appendInput(String value) {
    setState(() {
      if (value == 'x') {
        value = '*';
      }
      _expression += value;
      _display = _expression;
      _inputController.text = _display;
      _inputController.selection = TextSelection.fromPosition(
        TextPosition(offset: _inputController.text.length),
      );
    });
  }

  void _clearInput() {
    setState(() {
      _display = '0';
      _expression = '';
      _inputController.clear();
    });
  }

  void _calculate() {
    if (_expression.isEmpty) return;

    try {
      final expr = _expression.replaceAll('x', '*');
      final parser = Parser();
      final expression = parser.parse(expr);
      final context = ContextModel();
      final result = expression.evaluate(EvaluationType.REAL, context);
      final formattedResult =
          result.toStringAsFixed(2); // Format to 2 decimal places

      setState(() {
        _display = formattedResult;
        _history.insert(0, '$_expression = $formattedResult');
        _expression = formattedResult;
        _inputController.text = _display;
        _inputController.selection = TextSelection.fromPosition(
          TextPosition(offset: _inputController.text.length),
        );
      });
      _saveHistory();
    } catch (e) {
      setState(() {
        _display = 'Error';
        _expression = '';
        _inputController.text = _display;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Calculation error: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _clearHistory() async {
    setState(() {
      _history.clear();
    });
    await _saveHistory();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculator'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _clearHistory,
            icon: const Icon(Icons.clear_all_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final entry = _history[index];
                return ListTile(
                  title: Text(entry),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _inputController,
                  decoration: InputDecoration(
                    hintText: 'Enter calculation',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface.withAlpha(204),
                  ),
                  textAlign: TextAlign.end,
                  keyboardType: TextInputType.number,
                  onChanged: (value) => setState(() => _display = value),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  children: _buttons.map((button) {
                    return _buildButton(button, () {
                      if (button == '=') {
                        _calculate();
                      } else if (button == 'C') {
                        _clearInput();
                      } else if (button == '←') {
                        setState(() {
                          _display =
                              _display.substring(0, _display.length - 1) == ''
                                  ? '0'
                                  : _display.substring(0, _display.length - 1);
                        });
                      } else {
                        _appendInput(button);
                      }
                    });
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed) {
    final theme = Theme.of(context);
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        padding: const EdgeInsets.all(12),
        textStyle: const TextStyle(fontSize: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        minimumSize: const Size(60, 60),
      ),
      child: Text(text),
    );
  }
}
