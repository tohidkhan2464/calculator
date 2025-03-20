import 'dart:io';

import 'package:calculator/theme_constants.dart';
import 'package:expressions/expressions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  late String _expression = "";
  late String _result = "";
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _hasError = false;
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  final adUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/9214589741'
      : 'ca-app-pub-3940256099942544/2435281174';

  dynamic size;
  final ScrollController _expressionScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _expression = "";
    _result = "";
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _animation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    loadAd(); // Load the ad when the state is initialized
  }

  @override
  void dispose() {
    _animationController.dispose();
    _expressionScrollController.dispose();
    super.dispose();
  }

  void loadAd() async {
    // Get an AnchoredAdaptiveBannerAdSize before loading the ad.
    size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
        MediaQuery.sizeOf(context).width.truncate());

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: size,
      listener: BannerAdListener(
        // Called when an ad is successfully received.
        onAdLoaded: (ad) {
          debugPrint('$ad loaded.');
          setState(() {
            _isLoaded = true;
          });
        },
        // Called when an ad request failed.
        onAdFailedToLoad: (ad, err) {
          debugPrint('BannerAd failed to load: $err');
          // Dispose the ad here to free resources.
          ad.dispose();
        },
        // Called when an ad opens an overlay that covers the screen.
        onAdOpened: (Ad ad) {
          debugPrint('Ad opened.');
        },
        // Called when an ad removes an overlay that covers the screen.
        onAdClosed: (Ad ad) {
          debugPrint('Ad closed.');
        },
        // Called when an impression occurs on the ad.
        onAdImpression: (Ad ad) {
          debugPrint('Ad impression.');
        },
      ),
    )..load();
  }

  void _buttonPressed(String value) {
    // Play haptic feedback
    HapticFeedback.lightImpact();

    setState(() {
      if (value == "AC") {
        _expression = "";
        _result = "";
        _hasError = false;
      } else if (value == "⌫") {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
          _hasError = false;
          if (_expression.isNotEmpty) {
            _calculateResult();
          } else {
            _result = "";
          }
        }
      } else if (value == "=") {
        _calculateResult();
        // Copy result to expression if valid
        if (_result != "Error" && _result.isNotEmpty) {
          _expression = _result;
          _result = "";
        }
      } else {
        // Prevent multiple operators in a row except for minus (which can be used as negative)
        if (_isOperator(value) && value != "-") {
          if (_expression.isNotEmpty &&
              _isOperator(_expression[_expression.length - 1])) {
            _expression =
                _expression.substring(0, _expression.length - 1) + value;
            return;
          }
        }

        _expression += value;
        _hasError = false;
        _calculateResult();
      }
    });

    // Auto-scroll to the end of the expression
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

  bool _isOperator(String value) {
    return value == '+' ||
        value == '-' ||
        value == 'X' ||
        value == '/' ||
        value == '%';
  }

  void _calculateResult() {
    if (_expression.isEmpty) {
      _result = "";
      return;
    }

    try {
      // Format the expression properly
      String parsedExpression = _expression.replaceAll('X', '*');

      // Handle percentage calculations
      if (parsedExpression.contains('%')) {
        parsedExpression = _handlePercentage(parsedExpression);
      }

      const evaluator = ExpressionEvaluator();
      final expr = Expression.parse(parsedExpression);
      final evalResult = evaluator.eval(expr, {});

      // Format the result
      _result = _formatResult(evalResult);
      _hasError = false;
    } catch (e) {
      _result = "Error";
      _hasError = true;
    }
  }

  String _handlePercentage(String expression) {
    // Simple percentage handling
    if (expression.endsWith('%')) {
      return '(${expression.substring(0, expression.length - 1)})/100';
    }

    // Handle more complex percentage scenarios
    // This is a simplified implementation
    return expression.replaceAll('%', '/100');
  }

  String _formatResult(num result) {
    if (result == result.truncate()) {
      return result.toInt().toString();
    } else {
      // Limit decimal places to avoid overflow
      return result
          .toStringAsFixed(8)
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');
    }
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
              if (_isLoaded && _bannerAd != null) // Check if the ad is loaded
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      height: _bannerAd!.size.height.toDouble(),
                      child: AdWidget(
                          ad: _bannerAd!), // Create a new AdWidget instance
                    ),
                  ),
                ),
              Expanded(
                child: Container(
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
                        child: SingleChildScrollView(
                          controller: _expressionScrollController,
                          scrollDirection: Axis.horizontal,
                          reverse: true,
                          child: Text(
                            _expression,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.right,
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
                            color: _hasError
                                ? Colors.red
                                : ThemeConstants.accentColor,
                          ),
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildButtonGrid(),
            ],
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
        _buildButton("X", ButtonType.operator),
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

enum ButtonType {
  number,
  operator,
  function,
  equals,
}
