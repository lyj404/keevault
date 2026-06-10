import 'package:flutter/material.dart';

/// Shows a toast notification that slides in from the right side.
/// [isError] controls the color: green for success, red for error.
void showToast(BuildContext context, String message, {bool isError = false, Duration duration = const Duration(seconds: 2)}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  final controller = AnimationController(vsync: overlay, duration: const Duration(milliseconds: 250));
  final animation = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
      .animate(CurvedAnimation(parent: controller, curve: Curves.easeOutCubic));

  final bgColor = isError
      ? const Color(0xFFD32F2F)
      : const Color(0xFF388E3C);

  entry = OverlayEntry(
    builder: (_) => Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 60, right: 16),
        child: SlideTransition(
          position: animation,
          child: FadeTransition(
            opacity: controller,
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 200),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(-2, 4)),
                  ],
                ),
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  controller.forward();

  Future.delayed(duration, () async {
    if (controller.isDismissed) return;
    await controller.reverse();
    entry.remove();
    controller.dispose();
  });
}
