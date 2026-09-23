import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/ai_chat_screen.dart';
import '../theme/app_theme.dart';

class AiFloatingButton extends StatefulWidget {
  static final ValueNotifier<bool> visibleNotifier = ValueNotifier<bool>(true);
  const AiFloatingButton({super.key});
  @override
  State<AiFloatingButton> createState() => _AiFloatingButtonState();
}

class _AiFloatingButtonState extends State<AiFloatingButton> {
  static const _visibleKey = 'ai_assistant_visible';
  static const _leftKey = 'ai_assistant_left';
  static const _topKey = 'ai_assistant_top';
  Offset? _position;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      AiFloatingButton.visibleNotifier.value =
          prefs.getBool(_visibleKey) ?? true;
      final left = prefs.getDouble(_leftKey);
      final top = prefs.getDouble(_topKey);
      if (left != null && top != null) _position = Offset(left, top);
    });
  }

  Future<void> _savePosition() async {
    final prefs = await SharedPreferences.getInstance();
    final position = _position;
    if (position == null) return;
    await prefs.setDouble(_leftKey, position.dx);
    await prefs.setDouble(_topKey, position.dy);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AiFloatingButton.visibleNotifier,
      builder: (context, visible, _) {
        if (!visible) return const SizedBox.shrink();
        return _buildButton(context);
      },
    );
  }

  Widget _buildButton(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final position = _position ?? Offset(size.width - 82, size.height - 180);
    final left = position.dx.clamp(8.0, size.width - 70.0);
    final top = position.dy.clamp(70.0, size.height - 150.0);
    return Positioned(
        left: left,
        top: top,
        child: GestureDetector(
          onTap: _dragging
              ? null
              : () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AiChatScreen())),
          onLongPressStart: (_) => setState(() => _dragging = true),
          onLongPressMoveUpdate: (details) {
            setState(() => _position = Offset(
                left + details.offsetFromOrigin.dx,
                top + details.offsetFromOrigin.dy));
          },
          onLongPressEnd: (_) async {
            setState(() => _dragging = false);
            await _savePosition();
          },
          child: AnimatedScale(
              scale: _dragging ? 1.12 : 1,
              duration: const Duration(milliseconds: 120),
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.backgroundColor,
                    border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(.75),
                        width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(.35),
                          blurRadius: 18,
                          spreadRadius: 2)
                    ]),
                padding: const EdgeInsets.all(5),
                child: const AiBrandMark(size: 50),
              )),
        ));
  }
}
