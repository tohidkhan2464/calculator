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
  static const _operators = {'+', '-', 'x', '/', '%'};
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
        case "⌫":
          _backspace(cursorPosition);
          break;
        case "=":
          _finalizeResult();
          break;
        default:
          _insertAtCursor(value, cursorPosition);
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
        case '/':
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isAdLoaded && _bannerAd != null)
                SizedBox(
                  width: 300,
                  height: 50,
                  child: AdWidget(ad: _bannerAd!),
                ),
              Expanded(child: _buildDisplay()),
              const SizedBox(height: 10),
              _buildButtonGrid(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisplay() => Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
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
                alignment: Alignment.bottomRight,
                child: TextField(
                  controller: _expressionController,
                  textAlign: TextAlign.right,
                  textAlignVertical: TextAlignVertical.bottom,
                  maxLines: null,
                  autofocus: true,
                  onTapOutside: (event) =>
                      FocusScope.of(context).requestFocus(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                  ),
                  showCursor: true,
                  cursorColor: ThemeConstants.accentColor,
                  cursorWidth: 2.0,
                  onChanged: (value) {
                    setState(() {
                      _calculateResult();
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 5),
            LayoutBuilder(
              builder: (context, constraints) {
                double resultFontSize = 36;
                TextSpan resultSpan = TextSpan(
                  text: _result,
                  style: TextStyle(
                    fontSize: resultFontSize,
                    fontWeight: FontWeight.bold,
                    color: _hasError ? Colors.red : ThemeConstants.accentColor,
                  ),
                );

                TextPainter resultPainter = TextPainter(
                  text: resultSpan,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                );

                resultPainter.layout(maxWidth: constraints.maxWidth);

                while (resultPainter.width > constraints.maxWidth &&
                    resultFontSize > 18) {
                  resultFontSize -= 2;
                  resultSpan = TextSpan(
                    text: _result,
                    style: TextStyle(
                      fontSize: resultFontSize,
                      fontWeight: FontWeight.bold,
                      color:
                          _hasError ? Colors.red : ThemeConstants.accentColor,
                    ),
                  );
                  resultPainter.text = resultSpan;
                  resultPainter.layout(maxWidth: constraints.maxWidth);
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    curve: Curves.easeInOut,
                    child: Text(
                      _result,
                      style: TextStyle(
                        fontSize: resultFontSize,
                        fontWeight: FontWeight.bold,
                        color:
                            _hasError ? Colors.red : ThemeConstants.accentColor,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                );
              },
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
