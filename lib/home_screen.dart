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
  String _result = "";
  late AnimationController _animationController;
  bool _hasError = false;
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  final TextEditingController _expressionController = TextEditingController();

  final ScrollController _expressionScrollController = ScrollController();
  static const _operators = {'+', '-', 'x', '÷', '%', '-/+'};
  static const _numberFormat = NumberFormatInfo(maxDecimalPlaces: 8);

  @override
  void initState() {
    super.initState();
    _expressionController.text = ""; // Ensure the controller is initialized
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    // Add listener to update the UI when the text changes
    _expressionController.addListener(() {
      setState(() {});
    });

    _loadAd();
    // Schedule _loadAd to run every 5 minutes
    Future.doWhile(() async {
      await Future.delayed(const Duration(minutes: 5));
      if (mounted) _loadAd();
      return mounted;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isAdLoaded) _loadAd();
  }

  @override
  void dispose() {
    _expressionController
        .removeListener(() {}); // Remove listener to avoid memory leaks
    _expressionController.dispose();
    _bannerAd?.dispose();
    _animationController.dispose();
    _expressionScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAd() async {
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      300,
    );

    if (size == null) {
      debugPrint(
          'Ad size is null — possibly due to screen width being too small');
      return;
    }
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-2552575342940499/8352470029', // test unit
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
    final cursorPosition = _expressionController.selection.baseOffset;
    setState(() {
      switch (value) {
        case "AC":
          _clearAll();
          break;
        case 'SQFT':
          if (_expressionController.text.isNotEmpty) {
            // Wrap the current expression in parentheses and append /144
            final text = _expressionController.text;
            _expressionController.text = '($text)÷144';
            _expressionController.selection = TextSelection.fromPosition(
              TextPosition(offset: _expressionController.text.length),
            );
            // Do not finalize result here; let user press '='
            _calculateResult();
            _finalizeResult();
          }
          break;
        case "CFT":
          if (_expressionController.text.isNotEmpty) {
            // Wrap the current expression in parentheses and append /144
            final text = _expressionController.text;
            _expressionController.text = '($text)÷1728';
            _expressionController.selection = TextSelection.fromPosition(
              TextPosition(offset: _expressionController.text.length),
            );
            // Do not finalize result here; let user press '='
            _calculateResult();
            _finalizeResult();
          }
        case "⌫":
          _backspace(cursorPosition);
          break;
        case "=":
          _finalizeResult();
          break;

        case "-/+":
          // Toggle the sign of the last number, also handle the case when the last character is an operator and add the last number within the parenthesis
          if (_expressionController.text.isEmpty) return;
          final text = _expressionController.text;
          final lastOperatorIndex = text.lastIndexOf(RegExp(r'[+\-x/÷]'));
          final lastNumber = text.substring(
            lastOperatorIndex + 1,
            text.length,
          );

          // Check if lastNumber is already in the form of (-number)
          // If it is, remove the parentheses and negative sign
          // If it is not, add the parentheses and negative sign
          if (lastNumber.startsWith('(') && lastNumber.endsWith(')')) {
            final innerNumber = lastNumber.substring(1, lastNumber.length - 1);
            _expressionController.text = text.substring(
                  0,
                  lastOperatorIndex + 1,
                ) +
                innerNumber;
          } else {
            _expressionController.text =
                '${text.substring(0, lastOperatorIndex + 1)}(-$lastNumber)';
          }

          _calculateResult();
          break;
        default:
          if (_expressionController.text.isNotEmpty &&
              _isOperator(_expressionController.text.characters.last) &&
              _isOperator(value) &&
              value != "%") {
            // If the last character is an operator and the new value is also an operator, replace the last character with the new value
            _expressionController.text =
                _expressionController.text.substring(0, cursorPosition - 1) +
                    value;
          } else {
            _insertAtCursor(value, cursorPosition);
          }
          break;
      }
    });
  }

  void _clearAll() {
    _expressionController.text = "";
    _result = "";
    _hasError = false;
  }

  void _backspace(int cursorPosition) {
    if (_expressionController.text.isEmpty || cursorPosition <= 0) return;
    final text = _expressionController.text;
    _expressionController.text =
        text.substring(0, cursorPosition - 1) + text.substring(cursorPosition);
    _expressionController.selection = TextSelection.fromPosition(
      TextPosition(offset: cursorPosition - 1),
    );
    _hasError = false;
    _expressionController.text.isEmpty ? _result = "" : _calculateResult();
  }

  void _insertAtCursor(String value, int cursorPosition) {
    final text = _expressionController.text;

    // Ensure cursorPosition is valid
    if (cursorPosition < 0 || cursorPosition > text.length) {
      cursorPosition = text.length; // Default to the end of the text
    }

    _expressionController.text = text.substring(0, cursorPosition) +
        value +
        text.substring(cursorPosition);
    _expressionController.selection = TextSelection.fromPosition(
      TextPosition(offset: cursorPosition + value.length),
    );
    _hasError = false;
    if (_expressionController.text.isNotEmpty) _calculateResult();
    _scrollToEnd();
  }

  void _finalizeResult() {
    if (_result.isNotEmpty && !_hasError) {
      _expressionController.text = _result;
      _result = "";
    }
  }

  bool _isOperator(String value) => _operators.contains(value);

  void _calculateResult() {
    if (_expressionController.text.isEmpty) {
      _result = "";
      return;
    }

    // Remove trailing operator for evaluation
    String expressionToEvaluate = _expressionController.text;
    if (_isOperator(expressionToEvaluate.characters.last) &&
        _expressionController.text.characters.last != '%') {
      expressionToEvaluate =
          expressionToEvaluate.substring(0, expressionToEvaluate.length - 1);
    }

    try {
      // Transform percentage operations before evaluation
      String parsedExpression =
          _handlePercentageOperations(expressionToEvaluate);
      parsedExpression = parsedExpression.replaceAll('x', '*');
      parsedExpression = parsedExpression.replaceAll('÷', '/');

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
    final percentRegex = RegExp(r'(\d+(?:\.\d+)?)([+\-x/])(\d+(?:\.\d+)?)%');

    return expression.replaceAllMapped(percentRegex, (match) {
      final leftNum = double.parse(match.group(1)!);
      final operator = match.group(2)!;
      final percentValue = double.parse(match.group(3)!) / 100;

      switch (operator) {
        case '+':
          return '${leftNum + (leftNum * percentValue)}';
        case '-':
          return '${leftNum - (leftNum * percentValue)}';
        case 'x':
          return '${leftNum * percentValue}';
        case '÷':
          return percentValue == 0 ? 'Error' : '${leftNum / percentValue}';
        default:
          return match.group(0)!; // Fallback to the original match
      }
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
      backgroundColor: ThemeConstants.primaryColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isAdLoaded && _bannerAd != null)
                Container(
                  alignment: Alignment.center,
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  margin: const EdgeInsets.only(bottom: 5),
                  child: AdWidget(ad: _bannerAd!),
                ),
              Expanded(child: _buildDisplay()),
              const SizedBox(height: 10),
              _buildButtonGrid(),
              const SizedBox(height: 5),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisplay() => Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                double fontSize = 38.0;
                final text = _expressionController.text;

                if (text.isNotEmpty) {
                  TextStyle style = TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w300,
                  );
                  TextPainter textPainter = TextPainter(
                    text: TextSpan(text: text, style: style),
                    textDirection: TextDirection.ltr,
                    maxLines: 1,
                  );
                  textPainter.layout();

                  while (textPainter.width > constraints.maxWidth &&
                      fontSize > 20) {
                    fontSize -= 2;
                    style = TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w300,
                    );
                    textPainter.text = TextSpan(text: text, style: style);
                    textPainter.layout();
                  }
                }

                return Align(
                  alignment: Alignment.bottomRight,
                  child: SingleChildScrollView(
                    reverse: true,
                    child: TextField(
                      controller: _expressionController,
                      textAlign: TextAlign.right,
                      textAlignVertical: TextAlignVertical.bottom,
                      maxLines: null,
                      autofocus: true,
                      readOnly: true,
                      scrollController: _expressionScrollController,
                      onTapOutside: (event) =>
                          FocusScope.of(context).requestFocus(),
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w300,
                        color: ThemeConstants.textColor,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      showCursor: true,
                      cursorColor: ThemeConstants.accentColor,
                      cursorWidth: 3.0,
                      cursorRadius: const Radius.circular(2),
                      onChanged: (value) {
                        setState(() {
                          _calculateResult();
                          _scrollToEnd();
                        });
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 5),
          LayoutBuilder(
            builder: (context, constraints) {
              double resultFontSize = 48;
              if (_result.isNotEmpty) {
                TextStyle style = TextStyle(
                  fontSize: resultFontSize,
                  fontWeight: FontWeight.bold,
                  color: _hasError
                      ? ThemeConstants.errorColor
                      : ThemeConstants.accentColor,
                );
                TextPainter textPainter = TextPainter(
                  text: TextSpan(text: _result, style: style),
                  textDirection: TextDirection.ltr,
                  maxLines: 1,
                );
                textPainter.layout();

                while (textPainter.width > constraints.maxWidth &&
                    resultFontSize > 20) {
                  resultFontSize -= 2;
                  style = TextStyle(
                    fontSize: resultFontSize,
                    fontWeight: FontWeight.w300,
                  );
                  textPainter.text = TextSpan(text: _result, style: style);
                  textPainter.layout();
                }
              }
              return Align(
                alignment: Alignment.bottomRight,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: Text(
                      _result,
                      style: TextStyle(
                        fontSize: resultFontSize,
                        fontWeight: FontWeight.bold,
                        color: _hasError
                            ? ThemeConstants.errorColor
                            : ThemeConstants.accentColor,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildUnitButton('SQFT'),
              _buildUnitButton('CFT'),
            ],
          ),
        ],
      );

  Widget _buildUnitButton(String label) {
    return GestureDetector(
      onTap: () => _buttonPressed(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: ThemeConstants.secondaryColor,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: ThemeConstants.accentColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: ThemeConstants.textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildButtonGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      childAspectRatio: 1.0, // Make buttons perfectly circular
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      children: [
        _buildButton("AC", ButtonType.function),
        _buildButton("⌫", ButtonType.function),
        _buildButton("-/+", ButtonType.function),
        _buildButton("÷", ButtonType.operator),
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
        _buildButton("%", ButtonType.number),
        _buildButton("0", ButtonType.number),
        _buildButton(".", ButtonType.number),
        _buildButton("=", ButtonType.equals),
      ],
    );
  }

  Widget _buildButton(String value, ButtonType type) {
    return GestureDetector(
      onTap: () => _buttonPressed(value),
      child: Container(
        decoration: BoxDecoration(
          color: _getButtonColor(type),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight:
                  type == ButtonType.number ? FontWeight.w400 : FontWeight.bold,
              color: _getTextColor(type, value),
            ),
          ),
        ),
      ),
    );
  }

  Color _getButtonColor(ButtonType type) {
    switch (type) {
      case ButtonType.function:
        return ThemeConstants.btnFunction;
      case ButtonType.operator:
        return ThemeConstants.btnOperator;
      case ButtonType.equals:
        return ThemeConstants.accentColor;
      case ButtonType.calculations:
        return ThemeConstants.secondaryColor;
      case ButtonType.number:
      default:
        return ThemeConstants.btnNumber;
    }
  }

  Color _getTextColor(ButtonType type, String value) {
    switch (type) {
      case ButtonType.function:
        return ThemeConstants.textColor;
      case ButtonType.operator:
        return ThemeConstants.accentColor;
      case ButtonType.equals:
        return Colors.black;
      case ButtonType.calculations:
        return ThemeConstants.textColor;
      case ButtonType.number:
      default:
        return ThemeConstants.textColor;
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

enum ButtonType { number, operator, function, equals, calculations }
