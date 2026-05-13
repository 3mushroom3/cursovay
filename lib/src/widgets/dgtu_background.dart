import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Оборачивает тело страницы, добавляя полупрозрачный герб ДГТУ на фон.
class DgtuBackground extends StatelessWidget {
  const DgtuBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Align(
            alignment: Alignment.center,
            child: Opacity(
              opacity: 0.04,
              child: SvgPicture.asset(
                'assets/logo.svg',
                width: 320,
                height: 320,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
