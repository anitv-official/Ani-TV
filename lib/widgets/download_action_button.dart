import 'package:flutter/material.dart';

class DownloadActionButton extends StatefulWidget {
  final Future<bool> Function() onDownload;
  final String tooltip;
  final double size;
  const DownloadActionButton({super.key, required this.onDownload, this.tooltip = 'تنزيل', this.size = 22});

  @override
  State<DownloadActionButton> createState() => _DownloadActionButtonState();
}

class _DownloadActionButtonState extends State<DownloadActionButton> {
  bool _busy = false;
  bool _done = false;

  Future<void> _run() async {
    if (_busy || _done) return;
    setState(() => _busy = true);
    final success = await widget.onDownload();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = success;
    });
  }

  @override
  Widget build(BuildContext context) {
    final icon = _done
        ? Icons.check_circle
        : _busy
            ? Icons.downloading_rounded
            : Icons.download_for_offline_outlined;
    return Tooltip(
      message: _done ? 'تم التنزيل' : widget.tooltip,
      child: IconButton(
        onPressed: _busy || _done ? null : _run,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _busy
              ? SizedBox(
                  key: const ValueKey('progress'),
                  width: widget.size,
                  height: widget.size,
                  child: const CircularProgressIndicator(strokeWidth: 2.5, color: Colors.amber),
                )
              : Icon(key: ValueKey(icon), icon, size: widget.size, color: _done ? Colors.greenAccent : Colors.white70),
        ),
      ),
    );
  }
}
