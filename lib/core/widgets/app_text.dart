import 'package:flutter/material.dart';

class AppText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Color? color;
  final double? fontSize;
  final FontWeight? fontWeight;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const AppText(
    this.text, {
    super.key,
    this.style,
    this.color,
    this.fontSize,
    this.fontWeight,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style:
          style?.copyWith(
            color: color,
            fontSize: fontSize,
            fontWeight: fontWeight,
          ) ??
          TextStyle(
            color: color ?? Theme.of(context).colorScheme.onSurface,
            fontSize: fontSize ?? 14,
            fontWeight: fontWeight ?? FontWeight.normal,
            fontFamily: 'Roboto',
          ),
    );
  }
}
