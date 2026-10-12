import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette de Micky Quest.
class K {
  static const bg = Color(0xFF15112B);
  static const card = Color(0xFF221C42);
  static const raised = Color(0xFF2E2756);
  static const line = Color(0xFF3A3366);
  static const ink = Color(0xFFF4F2FF);
  static const muted = Color(0xFFB4AED6);
  static const dim = Color(0xFF8C86B8);
  static const lime = Color(0xFFB8FF3C);
  static const cyan = Color(0xFF4FE3FF);
  static const gold = Color(0xFFFFD24A);
  static const pink = Color(0xFFFF6FD8);
  static const coral = Color(0xFFFF8A5B);

  static const quadColors = {
    'do': lime,
    'plan': cyan,
    'light': gold,
    'drop': dim,
    'inbox': muted,
  };
  static const quadBg = {
    'do': Color(0xFF1E2A1A),
    'plan': Color(0xFF16263A),
    'light': Color(0xFF2A2418),
    'drop': Color(0xFF1C1736),
    'inbox': card,
  };
  static const moodColors = [coral, Color(0xFFC98AB5), dim, lime, Color(0xFF8FD12A)];

  static const micky = {
    'face': 'assets/images/micky_face.webp',
    'happy': 'assets/images/micky_happy.webp',
    'bed': 'assets/images/micky_bed.webp',
    'window': 'assets/images/micky_window.webp',
    'belly': 'assets/images/micky_belly.webp',
  };

  static TextStyle display(double size, {Color color = ink, FontWeight w = FontWeight.w600}) =>
      GoogleFonts.fredoka(fontSize: size, fontWeight: w, color: color, height: 1.15);

  static TextStyle body(double size, {Color color = ink, FontWeight w = FontWeight.w700}) =>
      GoogleFonts.nunito(fontSize: size, fontWeight: w, color: color);

  static ThemeData theme() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: base.colorScheme.copyWith(
        primary: lime,
        onPrimary: bg,
        secondary: cyan,
        surface: card,
        onSurface: ink,
      ),
      textTheme: GoogleFonts.nunitoTextTheme(base.textTheme).apply(bodyColor: ink, displayColor: ink),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: ink,
        elevation: 0,
        titleTextStyle: display(20),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: raised,
        contentTextStyle: TextStyle(color: ink),
        behavior: SnackBarBehavior.floating,
      ),
      sliderTheme: const SliderThemeData(activeTrackColor: cyan, thumbColor: ink, inactiveTrackColor: raised),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? bg : muted),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? lime : raised),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        labelStyle: const TextStyle(color: muted),
        hintStyle: const TextStyle(color: dim),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: line, width: 2)),
        enabledBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: line, width: 2)),
        focusedBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cyan, width: 2)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: card),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  const PrimaryButton({super.key, required this.label, this.onPressed, this.color = K.lime});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: K.bg,
          disabledBackgroundColor: K.line,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        onPressed: onPressed,
        child: Text(label, style: K.display(18, color: onPressed == null ? K.muted : K.bg, w: FontWeight.w700)),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const SecondaryButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: K.ink,
          backgroundColor: K.card,
          side: const BorderSide(color: K.line, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        onPressed: onPressed,
        child: Text(label, style: K.display(16)),
      ),
    );
  }
}

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color? border;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.color = K.card, this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: border == null ? null : Border.all(color: border!, width: 2),
      ),
      child: child,
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final Color? fill;
  const Pill(this.text, {super.key, this.color = K.muted, this.fill});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: fill ?? K.raised, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: K.body(12, color: color, w: FontWeight.w800)),
    );
  }
}

class Bar extends StatelessWidget {
  final double value;
  final Color color;
  final double height;
  const Bar(this.value, {super.key, this.color = K.cyan, this.height = 8});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: height,
        color: K.raised,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(color: color),
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 8),
        child: Text(text.toUpperCase(), style: K.display(13, color: K.muted).copyWith(letterSpacing: 1)),
      );
}

/// Bulle de Micky avec sa photo.
class MickySays extends StatelessWidget {
  final String text;
  final String pose;
  final Color ring;
  const MickySays(this.text, {super.key, this.pose = 'happy', this.ring = K.gold});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ring, width: 3),
            image: DecorationImage(image: AssetImage(K.micky[pose]!), fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: K.card,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: Text(text, style: K.body(15)),
          ),
        ),
      ],
    );
  }
}

Widget photo(String path, {double? size, double radius = 12}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: Image.file(
      File(path),
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(width: size, height: size, color: K.raised),
    ),
  );
}

String hm(DateTime d) => '${d.hour}h${d.minute.toString().padLeft(2, '0')}';

/// Popup de coffre ouvert.
Future<void> showChest(BuildContext context, String item) {
  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: K.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: K.gold, width: 2)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_2_rounded, color: K.gold, size: 56),
          const SizedBox(height: 12),
          Text('Coffre ouvert !', style: K.display(24, color: K.gold)),
          const SizedBox(height: 8),
          Text(item, textAlign: TextAlign.center, style: K.body(18)),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Trop bien', color: K.gold, onPressed: () => Navigator.pop(context)),
        ],
      ),
    ),
  );
}
