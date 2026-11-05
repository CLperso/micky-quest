import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Une ambiance de carnet.
class Pal {
  final String id, name;
  final Color desk, paper, ink, soft, line, dot, acc, acc2, acc3, card;
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
      this.dark = false});

  static const creme = Pal('creme', 'Crème',
      desk: Color(0xFFE9E1D3),
      paper: Color(0xFFFBF7EF),
      ink: Color(0xFF3B3346),
      soft: Color(0xFF8B8197),
      line: Color(0xFFE6DCCB),
      dot: Color(0xFFD9CFC0),
      acc: Color(0xFFE8896B),
      acc2: Color(0xFF7FA99B),
      acc3: Color(0xFFE9B949),
      card: Colors.white);
  static const nuit = Pal('nuit', 'Nuit',
      desk: Color(0xFF0F0C1E),
      paper: Color(0xFF1B1733),
      ink: Color(0xFFF2EEFF),
      soft: Color(0xFF9A93BC),
      line: Color(0xFF2E2852),
      dot: Color(0xFF2E2852),
      acc: Color(0xFFB8FF3C),
      acc2: Color(0xFF4FE3FF),
      acc3: Color(0xFFFF7AB6),
      card: Color(0xFF241F45),
      dark: true);
  static const sauge = Pal('sauge', 'Sauge',
      desk: Color(0xFFDCE4D8),
      paper: Color(0xFFF4F7F1),
      ink: Color(0xFF34413A),
      soft: Color(0xFF7D8C82),
      line: Color(0xFFD7E0D3),
      dot: Color(0xFFC9D4C4),
      acc: Color(0xFF6E9C7E),
      acc2: Color(0xFFC98E6B),
      acc3: Color(0xFFD9B44A),
      card: Colors.white);
  static const rose = Pal('rose', 'Rose',
      desk: Color(0xFFF0DDE2),
      paper: Color(0xFFFDF4F6),
      ink: Color(0xFF4A3540),
      soft: Color(0xFF9A7F8B),
      line: Color(0xFFEFDCE2),
      dot: Color(0xFFE5CDD4),
      acc: Color(0xFFD9667A),
      acc2: Color(0xFF8AA9C9),
      acc3: Color(0xFFE9B949),
      card: Colors.white);

  static const all = [creme, nuit, sauge, rose];
  static Pal byId(String id) => all.firstWhere((p) => p.id == id, orElse: () => creme);
}

TextStyle hand(double size, Color c, {FontWeight w = FontWeight.w700}) => GoogleFonts.caveat(fontSize: size, color: c, fontWeight: w, height: 1.1);
TextStyle titleFont(double size, Color c) => GoogleFonts.fredoka(fontSize: size, color: c, fontWeight: FontWeight.w500, height: 1.1);
TextStyle body(double size, Color c, {FontWeight w = FontWeight.w700}) => GoogleFonts.nunito(fontSize: size, color: c, fontWeight: w);

/// Petit libellé en capitales (« CE QUI COMPTE »).
class Label extends StatelessWidget {
  final String text;
  final Color color;
  const Label(this.text, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: Text(text.toUpperCase(), style: body(11, color, w: FontWeight.w800).copyWith(letterSpacing: 1.5)),
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
  0xFF3B3346, 0xFF8B8197, 0xFFFFFFFF, 0xFF000000,
  0xFFE8896B, 0xFFD9667A, 0xFFF2A7B5, 0xFFFFC9D6,
  0xFFE9B949, 0xFFF6D776, 0xFFFFF1B8, 0xFFC98E6B,
  0xFF7FA99B, 0xFF6E9C7E, 0xFFBFD8C9, 0xFFDCE4D8,
  0xFF6FA8FF, 0xFF8AA9C9, 0xFFBFD7F2, 0xFF4FE3FF,
  0xFFB9A7FF, 0xFF8A6FD1, 0xFFE3DAF7, 0xFFFBF7EF,
];

const paperColors = [0xFFFBF7EF, 0xFFFFFFFF, 0xFFF4F7F1, 0xFFFDF4F6, 0xFFF1F4FB, 0xFFFFF8E1, 0xFFF3ECE3, 0xFF1B1733, 0xFF22303A];
