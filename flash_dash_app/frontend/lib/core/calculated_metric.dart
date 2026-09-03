class CalculatedMetric {
  final String name;
  final String formula;

  const CalculatedMetric({required this.name, required this.formula});

  Map<String, dynamic> toJson() => {'name': name, 'formula': formula};

  static CalculatedMetric? fromJson(dynamic value) {
    if (value is! Map) return null;
    final name = value['name']?.toString().trim();
    final formula = value['formula']?.toString().trim();
    if (name == null || name.isEmpty || formula == null || formula.isEmpty) {
      return null;
    }
    return CalculatedMetric(name: name, formula: formula);
  }
}

double resolveMetricValue(
  Map<dynamic, dynamic> row,
  String metric,
  Map<String, CalculatedMetric> calculatedMetrics,
) {
  final calculated = calculatedMetrics[metric];
  if (calculated != null) {
    return FormulaEvaluator(
      row,
      calculatedMetrics,
    ).evaluate(calculated.formula);
  }
  return numericValue(row[metric]);
}

double numericValue(dynamic raw) {
  if (raw is num) return raw.toDouble();
  if (raw == null) return 0;
  final text = raw
      .toString()
      .replaceAll('R\$', '')
      .replaceAll('%', '')
      .replaceAll(' ', '')
      .trim();
  if (text.isEmpty) return 0;

  var normalized = text;
  if (normalized.contains(',') && normalized.contains('.')) {
    normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
  } else if (normalized.contains(',')) {
    normalized = normalized.replaceAll(',', '.');
  }
  return double.tryParse(normalized) ?? 0;
}

class FormulaEvaluator {
  final Map<dynamic, dynamic> row;
  final Map<String, CalculatedMetric> calculatedMetrics;
  late final List<_Token> _tokens;
  int _index = 0;

  FormulaEvaluator(this.row, this.calculatedMetrics);

  double evaluate(String formula) {
    _tokens = _Tokenizer(formula).scan();
    _index = 0;
    if (_tokens.isEmpty) return 0;
    return _parseExpression();
  }

  double _parseExpression() {
    var value = _parseTerm();
    while (_match('+') || _match('-')) {
      final operator = _previous.value;
      final right = _parseTerm();
      value = operator == '+' ? value + right : value - right;
    }
    return value;
  }

  double _parseTerm() {
    var value = _parseFactor();
    while (_match('*') || _match('/')) {
      final operator = _previous.value;
      final right = _parseFactor();
      if (operator == '*') {
        value *= right;
      } else {
        value = right == 0 ? 0 : value / right;
      }
    }
    return value;
  }

  double _parseFactor() {
    if (_match('-')) return -_parseFactor();
    if (_match('(')) {
      final value = _parseExpression();
      _match(')');
      return value;
    }
    if (_isAtEnd) return 0;

    final token = _advance();
    if (token.type == _TokenType.number) {
      return double.tryParse(token.value.replaceAll(',', '.')) ?? 0;
    }
    if (token.type == _TokenType.metric) {
      return resolveMetricValue(row, token.value, calculatedMetrics);
    }
    return 0;
  }

  bool _match(String value) {
    if (_isAtEnd || _tokens[_index].value != value) return false;
    _index++;
    return true;
  }

  _Token _advance() => _tokens[_index++];

  _Token get _previous => _tokens[_index - 1];

  bool get _isAtEnd => _index >= _tokens.length;
}

enum _TokenType { number, operatorSymbol, metric }

class _Token {
  final _TokenType type;
  final String value;

  const _Token(this.type, this.value);
}

class _Tokenizer {
  final String source;

  const _Tokenizer(this.source);

  List<_Token> scan() {
    final tokens = <_Token>[];
    var i = 0;
    while (i < source.length) {
      final char = source[i];
      if (char.trim().isEmpty) {
        i++;
        continue;
      }
      if ('+-*/()'.contains(char)) {
        tokens.add(_Token(_TokenType.operatorSymbol, char));
        i++;
        continue;
      }
      if (char == '[') {
        final end = source.indexOf(']', i + 1);
        if (end == -1) break;
        tokens.add(_Token(_TokenType.metric, source.substring(i + 1, end)));
        i = end + 1;
        continue;
      }
      if (_isNumberChar(char)) {
        final start = i;
        while (i < source.length && _isNumberChar(source[i])) {
          i++;
        }
        tokens.add(_Token(_TokenType.number, source.substring(start, i)));
        continue;
      }
      i++;
    }
    return tokens;
  }

  bool _isNumberChar(String char) {
    final code = char.codeUnitAt(0);
    return (code >= 48 && code <= 57) || char == '.' || char == ',';
  }
}
