import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../custom_loading_widget.dart';
import 'primary_button.dart';

class LoadingView extends StatelessWidget {
  final String message;
  final double size;

  const LoadingView({super.key, this.message = 'جارٍ التحميل...', this.size = 72});

  @override
  Widget build(BuildContext context) {
    return CustomLoadingWidget(message: message, size: size);
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Icon(icon, size: 32, color: AppTheme.textSecondaryColor),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13, height: 1.45),
              ),
            ],
            if (onAction != null) ...[
              const SizedBox(height: 22),
              PrimaryButton(label: actionLabel ?? 'استكشف المحتوى', onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({
    super.key,
    this.title = 'تعذر التحميل',
    this.message = 'تحقق من الاتصال وحاول مرة أخرى.',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.wifi_off_rounded,
      title: title,
      message: message,
      actionLabel: 'إعادة المحاولة',
      onAction: onRetry,
    );
  }
}
