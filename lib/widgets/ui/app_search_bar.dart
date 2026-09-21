import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AppSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool autofocus;

  const AppSearchBar({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText = 'ابحث عن أنمي أو مانجا',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.onTap,
    this.readOnly = false,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = controller?.text.isNotEmpty == true;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      readOnly: readOnly,
      autofocus: autofocus,
      onTap: onTap,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      style: const TextStyle(color: AppTheme.textPrimaryColor, fontSize: 14),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppTheme.surfaceColor,
        hintText: hintText,
        hintStyle: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13),
        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondaryColor, size: 22),
        suffixIcon: hasText
            ? IconButton(
                tooltip: 'مسح',
                icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondaryColor, size: 20),
                onPressed: onClear,
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.3),
        ),
      ),
    );
  }
}

class SearchLaunchField extends StatelessWidget {
  final VoidCallback onTap;
  final String hintText;

  const SearchLaunchField({
    super.key,
    required this.onTap,
    this.hintText = 'ابحث عن أنمي أو مانجا',
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(.62),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(.14)),
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: Colors.white70, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hintText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withOpacity(.78), fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExpandableSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;

  const ExpandableSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'بحث',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
  });

  @override
  State<ExpandableSearchBar> createState() => _ExpandableSearchBarState();
}

class _ExpandableSearchBarState extends State<ExpandableSearchBar> {
  bool _expanded = false;
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _open() {
    setState(() => _expanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: AlignmentDirectional.centerEnd,
      child: _expanded
          ? AppSearchBar(
              controller: widget.controller,
              focusNode: _focusNode,
              hintText: widget.hintText,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              onClear: widget.onClear,
            )
          : Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _open,
                  borderRadius: BorderRadius.circular(14),
                  child: Ink(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: const Icon(Icons.search_rounded),
                  ),
                ),
              ),
            ),
    );
  }
}
