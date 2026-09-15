import 'package:flutter/material.dart';
import 'package:onehubapp/core/app_colors.dart';

enum AppMessageType { success, error, warning, info }

class AppMessage {
  const AppMessage._();

  static void show(
    BuildContext context,
    String message, {
    AppMessageType type = AppMessageType.info,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: Colors.transparent,
        duration: const Duration(milliseconds: 2200),
        margin: const EdgeInsets.fromLTRB(18, 12, 18, 0),
        padding: EdgeInsets.zero,
        dismissDirection: DismissDirection.up,
        content: AppMessageView(message: message, type: type),
      ),
    );
  }
}

class AppMessageView extends StatelessWidget {
  const AppMessageView({required this.message, required this.type, super.key});

  final String message;
  final AppMessageType type;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(type);
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: style.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(style.icon, color: style.foreground, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: style.foreground,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _MessageStyle _styleFor(AppMessageType type) {
    return switch (type) {
      AppMessageType.success => const _MessageStyle(
          icon: Icons.check_circle_rounded,
          foreground: Color(0xFF126B35),
          background: Color(0xFFEAF8EF),
          border: Color(0xFFB7E6C6),
        ),
      AppMessageType.error => const _MessageStyle(
          icon: Icons.error_rounded,
          foreground: Color(0xFF9D1E1E),
          background: Color(0xFFFDECEC),
          border: Color(0xFFF4B9B9),
        ),
      AppMessageType.warning => const _MessageStyle(
          icon: Icons.info_rounded,
          foreground: Color(0xFF855500),
          background: Color(0xFFFFF5DE),
          border: Color(0xFFF2D28D),
        ),
      AppMessageType.info => const _MessageStyle(
          icon: Icons.info_rounded,
          foreground: AppColors.primary,
          background: Color(0xFFEAF3FF),
          border: Color(0xFFBBD5F5),
        ),
    };
  }
}

class _MessageStyle {
  const _MessageStyle({
    required this.icon,
    required this.foreground,
    required this.background,
    required this.border,
  });

  final IconData icon;
  final Color foreground;
  final Color background;
  final Color border;
}
