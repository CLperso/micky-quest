import 'package:flutter/material.dart';

/// Une ambiance de carnet.
class Pal {
  final String id, name;
  final Color desk, paper, ink, soft, line, dot, acc, acc2, acc3, card, cover, tint;
  final bool dark;
  const Pal(this.id, this.name,
      {required this.desk,
      required this.paper,
      required this.ink,
      required this.soft,
      required this.line,
      required this.dot,
      required this.acc,
      required this.acc2,
      required this.acc3,
      required this.card,
      required this.cover,
      required this.tint,
      this.dark = false});

  static const rose = Pal('rose', 'Rose poudré',
      desk: Color(0xFFEDE4DD),
      paper: Color(0xFFFCF8F3),
      ink: Color(0xFF4A3F3C),
      soft: Color(0xFF8F817C),
      line: Color(0xFFEADFD6),
      dot: Color(0xFFDDD0C6),
      acc: Color(0xFFB0707A),
      acc2: Color(0xFF8FA383),
      acc3: Color(0xFFC6A26A),
      card: Colors.white,
      cover: Color(0xFFD9B8B4),
      tint: Color(0xFFF1DEDD));
  static const sauge = Pal('sauge', 'Sauge & lin',
      desk: Color(0xFFE6E8DF),
      paper: Color(0xFFFAFAF5),
      ink: Color(0xFF3E4639),
      soft: Color(0xFF7F877A),
      line: Color(0xFFDDE2D5),
      dot: Color(0xFFCCD3C4),
      acc: Color(0xFF5E7254),
      acc2: Color(0xFFC08A72),
      acc3: Color(0xFFC6A26A),
      card: Colors.white,
      cover: Color(0xFFC7CFBC),
      tint: Color(0xFFE6ECDF));
  static const lavande = Pal('lavande', 'Lavande brume',
      desk: Color(0xFFE9E5EE),
      paper: Color(0xFFFBF9FC),
      ink: Color(0xFF443C4E),
      soft: Color(0xFF8A8296),
      line: Color(0xFFE4DEEA),
      dot: Color(0xFFD6CFDF),
      acc: Color(0xFF7D6A92),
      acc2: Color(0xFFC08A96),
      acc3: Color(0xFFC6A26A),
      card: Colors.white,
      cover: Color(0xFFD4CDE2),
      tint: Color(0xFFECE6F2));
  static const nuit = Pal('nuit', 'Nuit douce',
      desk: Color(0xFF1E1B26),
      paper: Color(0xFF2B2735),
      ink: Color(0xFFF1E9E4),
      soft: Color(0xFFA79DB0),
      line: Color(0xFF3E3849),
      dot: Color(0xFF443D51),
      acc: Color(0xFFE3A9AE),
      acc2: Color(0xFFA9BFA4),
      acc3: Color(0xFFE9D3A0),
      card: Color(0xFF36313F),
      cover: Color(0xFF4A4258),
      tint: Color(0xFF3B3446),
      dark: true);

  static const all = [rose, sauge, lavande, nuit];
  static Pal byId(String id) => all.firstWhere((p) => p.id == id, orElse: () => rose);

  List<Color> get tabs => dark
      ? const [Color(0xFF6E5F6C), Color(0xFF6B6250), Color(0xFF55644F), Color(0xFF7A5A63), Color(0xFF5E557A), Color(0xFF4E6466), Color(0xFF6E5466)]
      : const [Color(0xFFE2D2C8), Color(0xFFECE0C4), Color(0xFFCFDCCB), Color(0xFFDDB3B6), Color(0xFFD4CDE2), Color(0xFFC9D9D6), Color(0xFFE5CAD3)];
}

const monthTabColors = [
  Color(0xFFE3C9C5), Color(0xFFE9D3C1), Color(0xFFECE0C4), Color(0xFFDCE2C9), Color(0xFFCFDCCB), Color(0xFFC9D9D6),
  Color(0xFFCBD3E1), Color(0xFFD4CDE2), Color(0xFFDCCCDF), Color(0xFFE5CAD3), Color(0xFFD7A6A8), Color(0xFFE2D2C8),
];

const coverStyles = {
  'rose': Color(0xFFD9B8B4),
  'sauge': Color(0xFFC7CFBC),
  'lavande': Color(0xFFD4CDE2),
  'cuir': Color(0xFF8C6F62),
  'nuit': Color(0xFF2B2735),
  'vichy': Color(0xFFF1DEDD),
};

/// Style des titres, choisi dans « Mon style ».
String gTitleStyle = 'elegant';

TextStyle hand(double size, Color c, {FontWeight w = FontWeight.w400}) => TextStyle(fontFamily: 'PatrickHand', fontSize: size * 0.86, color: c, height: 1.2);
TextStyle script(double size, Color c) => TextStyle(fontFamily: 'DancingScript', fontSize: size, color: c, fontWeight: FontWeight.w600, height: 1.05);
TextStyle titleFont(double size, Color c) {
  switch (gTitleStyle) {
    case 'lettering':
      return TextStyle(fontFamily: 'DancingScript', fontSize: size * 1.05, color: c, fontWeight: FontWeight.w700, height: 1.05);
    case 'manuscrit':
      return TextStyle(fontFamily: 'PatrickHand', fontSize: size * 0.95, color: c, height: 1.1);
    default:
      return TextStyle(fontFamily: 'Cormorant', fontSize: size * 1.12, color: c, fontWeight: FontWeight.w500, fontStyle: FontStyle.italic, height: 1.0);
  }
}

TextStyle body(double size, Color c, {FontWeight w = FontWeight.w700}) => TextStyle(fontFamily: 'Nunito', fontSize: size, color: c, fontWeight: w);

/// Petit libellé en capitales (« CE QUI COMPTE »).
class Label extends StatelessWidget {
  final String text;
  final Color color;
  const Label(this.text, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: Text(text.toUpperCase(), style: body(10.5, color, w: FontWeight.w800).copyWith(letterSpacing: 2.2)),
      );
}

const stickerEmojis = {
  'Nature': ['🌿', '🍂', '🌸', '🌼', '🌻', '🍄', '🌙', '☀️', '⭐', '✨', '☁️', '🌈', '❄️', '🌊'],
  'Papeterie': ['📌', '📎', '✏️', '🖋️', '📚', '📖', '🗒️', '✂️', '🔖', '💌', '🎀', '🧷'],
  'Douceurs': ['☕', '🍵', '🍪', '🧁', '🍓', '🍋', '🥐', '🍫', '🕯️', '🧸', '🎈', '💐'],
  'Humeurs': ['💛', '🧡', '💜', '💚', '🩵', '❤️', '😊', '🥹', '😴', '🤓', '😌', '🔥'],
  'Chats': ['🐈', '🐱', '😺', '😸', '😻', '🐾', '🧶', '🐟', '🐭', '🦋', '🐞', '🐝'],
};

const washiPatterns = ['stripes', 'dots', 'grid', 'solid', 'zigzag', 'check'];
const framePatterns = ['solid', 'dashed', 'double', 'rounded', 'tag', 'bubble', 'polaroid', 'corners'];
const frameNames = {
  'solid': 'Trait',
  'dashed': 'Pointillés',
  'double': 'Double',
  'rounded': 'Arrondi',
  'tag': 'Étiquette',
  'bubble': 'Bulle',
  'polaroid': 'Polaroïd',
  'corners': 'Coins photo',
};

const colorChoices = [
  0xFF4A3F3C, 0xFF8F817C, 0xFFFFFFFF, 0xFF000000,
  0xFFB0707A, 0xFFD7A6A8, 0xFFF1DEDD, 0xFFE3B7A0,
  0xFFC6A26A, 0xFFE9D3A0, 0xFFF4ECE1, 0xFFC08A72,
  0xFF5E7254, 0xFF8FA383, 0xFFA9B8A0, 0xFFE3E9DD,
  0xFF7C93AE, 0xFFA9BCD3, 0xFFDDE5EF, 0xFF6E8E8E,
  0xFF7D6A92, 0xFFB9A7C2, 0xFFECE5F0, 0xFFFCF8F3,
];

const paperColors = [0xFFFCF8F3, 0xFFFFFFFF, 0xFFFAFAF5, 0xFFFBF9FC, 0xFFF4ECE1, 0xFFF1DEDD, 0xFFE6ECDF, 0xFFD8C3A5, 0xFF2B2735, 0xFF22303A];
