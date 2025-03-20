import 'package:calculator/theme_constants.dart';
import 'package:flutter/material.dart';

class CustomContainer extends StatelessWidget {
  const CustomContainer({
    super.key,
    required this.child,
    this.height,
    this.width,
    this.color,
    this.onTap,
  });

  final Widget child;
  final double? height;
  final double? width;
  final int? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height ?? 70,
        width: width ?? 70,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color:
              color == 1 ? ThemeConstants.accentColor : const Color(0xffececec),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}
