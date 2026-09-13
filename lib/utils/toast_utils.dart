import 'package:flutter/material.dart';

class ToastUtils {
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void show(
    String msg, {
    Color? backgroundColor,
    Color? textColor,
    Object? gravity,
  }) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    final color = backgroundColor ?? const Color(0xFF263238);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                color == Colors.red || color.value == Colors.red.value
                    ? Icons.error_outline
                    : color == Colors.green || color.value == Colors.green.value
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                color: textColor ?? Colors.white,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  msg,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textColor ?? Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: color.withOpacity(.94),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 2400),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 86),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.white.withOpacity(.10))),
          elevation: 4,
        ),
      );
  }
}
