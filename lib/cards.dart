/// Cartes Micky : une photo de Micky gagnée à chaque tâche pro finie (cochée ou en session).
/// rareté : 1 commune · 2 rare · 3 légendaire.
class MickyCard {
  final String id, name;
  final int rarity;
  const MickyCard(this.id, this.name, this.rarity);
  String get asset => 'assets/cards/$id.jpg';
}

class Cards {
  static const all = [
    MickyCard('m01', 'La crêpe', 1),
    MickyCard('m02', 'Pleine satisfaction', 2),
    MickyCard('m03', 'Le ventre offert', 2),
    MickyCard('m04', 'L\'inspectrice', 1),
    MickyCard('m05', 'Il neige sur Paris', 3),
    MickyCard('m06', 'Pacha du fauteuil', 1),
    MickyCard('m07', 'Le pain de mie', 1),
    MickyCard('m08', 'La brioche', 2),
    MickyCard('m09', 'Coussinets roses', 1),
    MickyCard('m10', 'Point d\'interrogation', 2),
    MickyCard('m11', 'La guetteuse', 3),
    MickyCard('m12', 'La directrice', 2),
    MickyCard('m13', 'Nuit douce', 1),
    MickyCard('m14', 'Accordéon', 1),
    MickyCard('m15', 'Chut, je dors', 1),
    MickyCard('m16', 'Le flou artistique', 1),
    MickyCard('m17', 'Bain de soleil', 2),
    MickyCard('m18', 'Entre les pétunias', 3),
    MickyCard('m19', 'Le regard noir', 2),
    MickyCard('m20', 'Les yeux d\'or', 3),
    MickyCard('m21', 'Bébé dans la couette', 3),
    MickyCard('m22', 'Trop fatiguée pour jouer', 2),
    MickyCard('m23', 'Le doudou', 2),
    MickyCard('m24', 'Funambule endormie', 2),
    MickyCard('m25', 'Nous deux', 3),
    MickyCard('m26', 'La voleuse de lunettes', 2),
    MickyCard('m27', 'Skateuse', 2),
    MickyCard('m28', 'Sieste de chaton', 1),
    MickyCard('m29', 'Le nounours', 1),
    MickyCard('m30', 'Le croissant', 1),
    MickyCard('m31', 'La visiteuse', 1),
    MickyCard('m32', 'Pose officielle', 1),
    MickyCard('m33', 'Documentaire animalier', 3),
    MickyCard('m34', 'La chasseuse', 1),
    MickyCard('m35', 'La patte tendue', 1),
    MickyCard('m36', 'Aux aguets', 1),
    MickyCard('m37', 'Le grand abandon', 1),
    MickyCard('m38', 'Un œil ouvert', 2),
  ];

  static MickyCard? byId(String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }

  static const rarityNames = ['', 'Commune', 'Rare', 'Légendaire'];
}

/// Une carte gagnée : quand, laquelle, combien d'XP, pour quelle tâche.
class CardDrop {
  final int ts;
  final String card;
  final int xp;
  final String title;
  const CardDrop(this.ts, this.card, this.xp, this.title);

  static CardDrop? parse(String s) {
    final p = s.split('|');
    if (p.length < 4) return null;
    return CardDrop(int.tryParse(p[0]) ?? 0, p[1], int.tryParse(p[2]) ?? 0, p.sublist(3).join('|'));
  }

  String encode() => '$ts|$card|$xp|${title.replaceAll('\n', ' ')}';
}
