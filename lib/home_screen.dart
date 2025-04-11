import 'dart:io';

import 'package:calculator/theme_constants.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  String _expression = "";
  String _result = "";
  late AnimationController _animationController;
  bool _hasError = false;
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  final String _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-2552575342940499/8352470029'
      : 'ca-app-pub-2552575342940499/8352470029';

  final ScrollController _expressionScrollController = ScrollController();
  static const _operators = {'+', '-', 'x', '/', '%'};
  static const _numberFormat = NumberFormatInfo(maxDecimalPlaces: 8);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
   
    _loadAd();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isAdLoaded) _loadAd();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _animationController.dispose();
    _expressionScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAd() async {
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      MediaQuery.of(context).size.width.truncate(),
    );

    if (size == null) return;

    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      size: size,
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isAdLoaded = true),
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          debugPrint('BannerAd failed to load: $err');
        },
      ),
    )..load();
  }

  void _buttonPressed(String value) {
    setState(() {
      switch (value) {
        case "AC":
          _clearAll();
          break;
        case "⌫":
          _backspace();
          break;
        case "=":
          _finalizeResult();
          break;
        default:
          if (_isOperator(value)) {
            if (_expression.isEmpty) {
              if (value == '-') _expression = value;
            } else if (_isOperator(_expression.characters.last) &&
                value == '-' &&
                (_expression.characters.last == 'x' ||
                    _expression.characters.last == '/')) {
              _expression += value;
            } else if (_isOperator(_expression.characters.last) &&
                _expression.characters.last != '%') {
              _expression =
                  _expression.substring(0, _expression.length - 1) + value;
            } else {
              _expression += value;
            }
          } else {
            if (value == '.' &&
                (_expression.isEmpty ||
                    _isOperator(_expression.characters.last))) {
              _expression += '0.';
            } else if (value == '.') {
              final parts = _expression.split(RegExp(r'[+\-x/]'));
              if (!parts.last.contains('.')) {
                _expression += value;
              }
            } else if ((value == '0' || value == '00') && _expression == '0') {
            } else {
              _expression += value;
            }
          }

          _hasError = false;
          if (_expression.isNotEmpty) _calculateResult();
          _scrollToEnd();
      }
    });
  }

  void _clearAll() {
    _expression = "";
    _result = "";
    _hasError = false;
  }

  void _backspace() {
    if (_expression.isEmpty) return;
    _expression = _expression.substring(0, _expression.length - 1);
    _hasError = false;
    _expression.isEmpty ? _result = "" : _calculateResult();
  }

  void _finalizeResult() {
    if (_result.isNotEmpty && !_hasError) {
      _expression = _result;
      _result = "";
    }
  }

  bool _isOperator(String value) => _operators.contains(value);

  void _calculateResult() {
    if (_expression.isEmpty) {
      _result = "";
      return;
    }

    // Remove trailing operator for evaluation
    String expressionToEvaluate = _expression;
    if (_isOperator(expressionToEvaluate.characters.last) &&
        _expression.characters.last != '%') {
      expressionToEvaluate =
          expressionToEvaluate.substring(0, expressionToEvaluate.length - 1);
    }

    try {
      // Transform percentage operations before evaluation
      String parsedExpression =
          _handlePercentageOperations(expressionToEvaluate);
      parsedExpression = parsedExpression.replaceAll('x', '*');

      Parser p = Parser();
      Expression expr = p.parse(parsedExpression);
      ContextModel cm = ContextModel();
      final result = expr.evaluate(EvaluationType.REAL, cm);
      if (result == double.infinity || result == double.negativeInfinity) {
        _result = "Error";
        _hasError = true;
        return;
      }
      _result = _numberFormat.format(result);
      _hasError = false;
    } catch (e) {
      _result = "Error";
      _hasError = true;
    }
  }

  String _handlePercentageOperations(String expression) {
    final percentRegex = RegExp(r'(\d+(?:\.\d+)?)([+\-])(\d+(?:\.\d+)?)%');

    return expression.replaceAllMapped(percentRegex, (match) {
      final leftNum = double.parse(match.group(1)!);
      final operator = match.group(2)!;
      final percentValue = double.parse(match.group(3)!) / 100 * leftNum;
     
      return operator == '+'
          ? '${leftNum + percentValue}'
          : '${leftNum - percentValue}';
    });
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_expressionScrollController.hasClients) {
        _expressionScrollController.animateTo(
          _expressionScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isAdLoaded && _bannerAd != null)
                SizedBox(
                  width: double.infinity,
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
              Expanded(child: _buildDisplay()),
              const SizedBox(height: 20),
              _buildButtonGrid(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisplay() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.topRight,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double fontSize = 28;
                    TextSpan textSpan = TextSpan(
                      text: _expression,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w500,
                      ),
                    );

                    TextPainter textPainter = TextPainter(
                      text: textSpan,
                      textDirection: TextDirection.ltr,
                      maxLines: 5,
                    );

                    textPainter.layout(maxWidth: constraints.maxWidth);

                    while (textPainter.didExceedMaxLines && fontSize > 14) {
                      fontSize -= 2;
                      textSpan = TextSpan(
                        text: _expression,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                      textPainter.text = textSpan;
                      textPainter.layout(maxWidth: constraints.maxWidth);
                    }

                    return Text(
                      _expression,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Text(
                _result,
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: _hasError ? Colors.red : ThemeConstants.accentColor,
                ),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );

  Widget _buildButtonGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      childAspectRatio: 1.1,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _buildButton("AC", ButtonType.function),
        _buildButton("%", ButtonType.operator),
        _buildButton("/", ButtonType.operator),
        _buildButton("⌫", ButtonType.function),
        _buildButton("7", ButtonType.number),
        _buildButton("8", ButtonType.number),
        _buildButton("9", ButtonType.number),
        _buildButton("x", ButtonType.operator),
        _buildButton("4", ButtonType.number),
        _buildButton("5", ButtonType.number),
        _buildButton("6", ButtonType.number),
        _buildButton("-", ButtonType.operator),
        _buildButton("1", ButtonType.number),
        _buildButton("2", ButtonType.number),
        _buildButton("3", ButtonType.number),
        _buildButton("+", ButtonType.operator),
        _buildButton("00", ButtonType.number),
        _buildButton("0", ButtonType.number),
        _buildButton(".", ButtonType.number),
        _buildButton("=", ButtonType.equals),
      ],
    );
  }

  Widget _buildButton(String value, ButtonType type) {
    return GestureDetector(
      onTap: () => _buttonPressed(value),
      child: TweenAnimationBuilder(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 200),
        builder: (context, double value, child) {
          return Transform.scale(
            scale: value,
            child: child,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: _getButtonColor(type),
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: _getTextColor(type, value),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getButtonColor(ButtonType type) {
    switch (type) {
      case ButtonType.function:
        return Colors.grey.shade200;
      case ButtonType.operator:
        return Colors.grey.shade300;
      case ButtonType.equals:
        return ThemeConstants.accentColor;
      case ButtonType.number:
      default:
        return Colors.white;
    }
  }

  Color _getTextColor(ButtonType type, String value) {
    switch (type) {
      case ButtonType.function:
        return value == "AC" ? Colors.red : Colors.black87;
      case ButtonType.operator:
        return ThemeConstants.accentColor;
      case ButtonType.equals:
        return Colors.white;
      case ButtonType.number:
      default:
        return Colors.black87;
    }
  }
}

class NumberFormatInfo {
  final int maxDecimalPlaces;

  const NumberFormatInfo({required this.maxDecimalPlaces});

  String format(num value) {
    if (value == value.truncate()) return value.toInt().toString();
    return value
        .toStringAsFixed(maxDecimalPlaces)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }
}

enum ButtonType {
  number,
  operator,
  function,
  equals,
}
