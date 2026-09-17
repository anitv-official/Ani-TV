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
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                gradient: AppTheme.glassGradient,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primaryColor.withOpacity(.24)),
                boxShadow: AppTheme.subtleShadow,
              ),
              child: Icon(icon, size: 34, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondaryColor),
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
