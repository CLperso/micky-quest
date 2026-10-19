import 'dart:math';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';

String euros(double v) => '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2).replaceAll('.', ',')} €';

const _months = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
String _date(DateTime d) => '${d.day} ${_months[d.month - 1]}';

const envelopeIcons = {
  'courses': Icons.shopping_cart_rounded,
  'repas': Icons.restaurant_rounded,
  'shopping': Icons.shopping_bag_rounded,
  'santé': Icons.pets_rounded,
  'transport': Icons.directions_bus_rounded,
  'plaisirs': Icons.celebration_rounded,
};

/// Couleur selon la part qui reste : vert, puis jaune, puis rouge.
Color leftColor(double frac) => frac >= 0.5 ? K.lime : (frac >= 0.25 ? K.gold : K.coral);

/// « Combien tu as ? » : saisir le montant disponible ou repartir au budget total.
Future<void> editAvailable(BuildContext context) async {
  final store = AppScope.read(context);
  final c = TextEditingController(text: store.periodLeft().toStringAsFixed(0));
  final v = await showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: K.card,
      title: const Text('Combien tu as ?'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Ce qu\'il te reste pour vivre jusqu\'à la paie, frais fixes déjà payés.', style: K.body(13, color: K.muted)),
        const SizedBox(height: 8),
        TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: '€'),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, -1), child: const Text('Jour de paie…')),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        TextButton(onPressed: () => Navigator.pop(ctx, double.tryParse(c.text.replaceAll(',', '.').trim())), child: const Text('OK')),
      ],
    ),
  );
  c.dispose();
  if (v == null) return;
  if (v < 0) {
    if (context.mounted) await paydayDialog(context);
  } else {
    await store.setAvailable(v);
  }
}

/// Jour de paie : salaire reçu → l'appli enlève frais fixes et charges, le reste va aux enveloppes.
Future<void> paydayDialog(BuildContext context) async {
  final store = AppScope.read(context);
  final c = TextEditingController(text: store.settings.salary.toStringAsFixed(2).replaceAll('.', ','));
  var payAppel = store.appelDueAt(store.lastPayday());
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
      final sal = double.tryParse(c.text.replaceAll(',', '.').trim()) ?? 0;
      final st = store.settings;
      final avail = store.availableFromSalary(sal, payAppel: payAppel);
      final chargesPart = payAppel ? max(0.0, st.chargesNext - st.chargesReserve) : st.chargesMonthly;
      Widget line(String l, String v, {Color? color, bool bold = false}) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              Expanded(child: Text(l, style: K.body(13, color: bold ? K.ink : K.muted, w: bold ? FontWeight.w800 : FontWeight.w400))),
              Text(v, style: K.body(13, color: color ?? K.ink, w: bold ? FontWeight.w800 : FontWeight.w400)),
            ]),
          );
      return AlertDialog(
        backgroundColor: K.card,
        title: const Text('Jour de paie'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: c,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setD(() {}),
            decoration: const InputDecoration(labelText: 'Salaire et aides reçus', suffixText: '€'),
          ),
          const SizedBox(height: 6),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: payAppel,
            onChanged: (v) => setD(() => payAppel = v ?? false),
            title: Text('Payer l\'appel de charges (${euros(st.chargesNext)})', style: K.body(13)),
            subtitle: Text(payAppel ? '${euros(st.chargesReserve)} déjà de côté' : 'Sinon, ${euros(st.chargesMonthly)} mis de côté',
                style: K.body(11, color: K.muted)),
          ),
          line('Salaire et aides', euros(sal)),
          line('Frais fixes', '− ${euros(store.fixedTotal())}'),
          line(payAppel ? 'Appel de charges (reste à payer)' : 'Charges mises de côté', '− ${euros(chargesPart)}'),
          const Divider(),
          line('Pour les enveloppes', euros(max(0.0, avail)), color: avail <= 0 ? K.coral : K.lime, bold: true),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(onPressed: sal <= 0 ? null : () => Navigator.pop(ctx, true), child: const Text('Valider')),
        ],
      );
    }),
  );
  final sal = double.tryParse(c.text.replaceAll(',', '.').trim()) ?? 0;
  c.dispose();
  if (ok == true) await store.applyPayday(sal, payAppel: payAppel);
}

/// Régler l'enveloppe charges : déjà de côté, prochain appel, mise de côté mensuelle.
Future<void> editCharges(BuildContext context) async {
  final store = AppScope.read(context);
  final st = store.settings;
  String f(double v) => v.toStringAsFixed(2).replaceAll('.', ',');
  final res = TextEditingController(text: f(st.chargesReserve));
  final next = TextEditingController(text: f(st.chargesNext));
  final month = TextEditingController(text: f(st.chargesMonthly));
  double? p(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.').trim());
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: K.card,
      title: const Text('Charges de l\'appart'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: res, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Déjà mis de côté', suffixText: '€')),
        TextField(controller: next, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Prochain appel', suffixText: '€')),
        TextField(controller: month, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'À mettre de côté chaque mois', suffixText: '€')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('OK')),
      ],
    ),
  );
  if (ok == true) await store.setCharges(reserve: p(res), next: p(next), monthly: p(month));
  res.dispose();
  next.dispose();
  month.dispose();
}

/// Prochain appel de charges (1er janvier, avril, juillet ou octobre) après aujourd'hui.
DateTime nextAppel() {
  final now = DateTime.now();
  for (var i = 0; i < 13; i++) {
    final d = DateTime(now.year, now.month + i, 1);
    if ([1, 4, 7, 10].contains(d.month) && d.isAfter(now)) return d;
  }
  return DateTime(now.year + 1, 1, 1);
}

/// L'enveloppe charges : séparée, jamais partagée avec les autres.
class ChargesTile extends StatelessWidget {
  const ChargesTile({super.key});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context).settings;
    final frac = st.chargesNext <= 0 ? 1.0 : (st.chargesReserve / st.chargesNext).clamp(0.0, 1.0);
    final a = nextAppel();
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => editCharges(context),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: K.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: K.raised, width: 2)),
        child: Row(children: [
          Stack(clipBehavior: Clip.none, children: [
            const Icon(Icons.mail_rounded, color: K.cyan, size: 30),
            Positioned(
              right: -9,
              bottom: -4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: K.bg, shape: BoxShape.circle),
                child: const Icon(Icons.apartment_rounded, color: K.gold, size: 14),
              ),
            ),
          ]),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('Charges de l\'appart', style: K.body(13, w: FontWeight.w800))),
                Text('${euros(st.chargesReserve.roundToDouble())} / ${euros(st.chargesNext.roundToDouble())}',
                    style: K.body(13, color: K.cyan, w: FontWeight.w800)),
              ]),
              const SizedBox(height: 4),
              Bar(frac, color: K.cyan, height: 5),
              const SizedBox(height: 3),
              Text('De côté pour l\'appel du ${_date(a)} ${a.year} · +${euros(st.chargesMonthly)} à chaque paie',
                  style: K.body(11, color: K.muted)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Jauge en demi-cercle : du rouge (vide) au vert (plein).
class BudgetGauge extends StatelessWidget {
  const BudgetGauge({super.key, required this.left, required this.total, this.size = 220});

  final double left;
  final double total;
  final double size;

  @override
  Widget build(BuildContext context) {
    final frac = total <= 0 ? 0.0 : (left / total).clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size * 0.62,
      child: CustomPaint(
        painter: _GaugePainter(frac),
        child: Align(
          alignment: const Alignment(0, 0.85),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            FittedBox(
              child: Text(euros(left), style: K.display(30, color: left < 0 ? K.coral : leftColor(frac), w: FontWeight.w700)),
            ),
            Text(left < 0 ? 'dépassé' : 'disponibles sur ${euros(total)}', style: K.body(11, color: K.muted)),
          ]),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.frac);
  final double frac;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final r = min(size.width / 2, size.height) - stroke / 2;
    final center = Offset(size.width / 2, r + stroke / 2);
    final rect = Rect.fromCircle(center: center, radius: r);
    final track = Paint()
      ..color = K.raised
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, pi, pi, false, track);
    if (frac <= 0) return;
    final fill = Paint()
      ..shader = const SweepGradient(
        startAngle: pi,
        endAngle: 2 * pi,
        colors: [K.coral, K.gold, K.lime],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, pi, pi * frac, false, fill);
    final a = pi + pi * frac;
    canvas.drawCircle(center + Offset(cos(a), sin(a)) * r, stroke / 2 + 3, Paint()..color = K.ink);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.frac != frac;
}

/// Une enveloppe : icône, nom, ce qui reste. Touche pour noter une dépense dedans.
class EnvelopeTile extends StatelessWidget {
  const EnvelopeTile(this.cat, {super.key});
  final String cat;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final alloc = store.envelopeAlloc(cat);
    final left = store.envelopeLeft(cat);
    final frac = alloc <= 0 ? 0.0 : left / alloc;
    final color = left < 0 ? K.coral : leftColor(frac);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => addExpenseSheet(context, cat: cat),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
        decoration: BoxDecoration(color: K.bg, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Stack(clipBehavior: Clip.none, children: [
            Icon(Icons.mail_rounded, color: color, size: 30),
            Positioned(
              right: -9,
              bottom: -4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: K.bg, shape: BoxShape.circle),
                child: Icon(envelopeIcons[cat], color: K.gold, size: 14),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text(Expense.labels[cat]!, style: K.body(11, color: K.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(store.envelopeCovered(cat) ? 'couvert' : euros(left.roundToDouble()), style: K.body(14, color: color, w: FontWeight.w800)),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Bar(frac.clamp(0.0, 1.0), color: color, height: 4),
          ),
        ]),
      ),
    );
  }
}

/// Version courte pour le QG : reste, limite du jour. Un tap ouvre la version complète.
class BudgetMiniCard extends StatelessWidget {
  const BudgetMiniCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final left = store.periodLeft();
    final total = store.periodAmount;
    final allow = store.dailyAllowance(store.todayKey);
    final today = store.spentOn(store.todayKey);
    final ok = today <= allow;
    return Material(
      color: K.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => openScreen(context, const BudgetHubScreen()),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          child: Row(children: [
            const Icon(Icons.savings_rounded, color: K.gold, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Budget', style: K.display(15)),
                  const SizedBox(width: 8),
                  Text('reste ${euros(left.roundToDouble())}', style: K.body(13, color: K.gold, w: FontWeight.w800)),
                ]),
                const SizedBox(height: 4),
                Bar(total <= 0 ? 0 : (left / total).clamp(0.0, 1.0), color: K.gold, height: 5),
                const SizedBox(height: 4),
                Text(
                  ok ? 'Aujourd\'hui : max ${euros(allow.roundToDouble())} · dépensé ${euros(today)}' : 'Aujourd\'hui : ${euros(today - allow)} au-dessus',
                  style: K.body(11, color: ok ? K.muted : K.coral),
                ),
              ]),
            ),
            IconButton(
              tooltip: 'Dépense',
              onPressed: () => addExpenseSheet(context),
              icon: const Icon(Icons.add_circle_rounded, color: K.gold),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Budget complet (depuis le QG).
class BudgetHubScreen extends StatelessWidget {
  const BudgetHubScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Budget')),
        body: SafeArea(
          top: false,
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: const [BudgetCard()]),
        ),
      );
}

/// Carte complète : jauge, limite du jour, 6 enveloppes.
class BudgetCard extends StatelessWidget {
  const BudgetCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final left = store.periodLeft();
    final end = store.nextPayday().subtract(const Duration(days: 1));
    final days = store.daysLeftInPeriod();
    final allow = store.dailyAllowance(store.todayKey);
    final today = store.spentOn(store.todayKey);
    final ok = today <= allow;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.savings_rounded, color: K.gold, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('Budget jusqu\'au ${_date(end)}', style: K.display(16))),
            IconButton(
              tooltip: 'Changer le montant',
              onPressed: () => editAvailable(context),
              icon: const Icon(Icons.edit_rounded, color: K.muted, size: 18),
            ),
          ]),
          if (store.paydayPassed || store.settings.periodStart == 0) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: K.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: K.gold, width: 2)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(store.paydayPassed ? 'Jour de paie : nouveau mois de budget' : 'Combien tu as jusqu\'à la paie ?',
                    style: K.body(13, w: FontWeight.w800)),
                const SizedBox(height: 4),
                Row(children: [
                  if (store.paydayPassed) TextButton(onPressed: () => paydayDialog(context), child: const Text('Calculer mon mois')),
                  TextButton(onPressed: () => editAvailable(context), child: const Text('Saisir le montant')),
                ]),
              ]),
            ),
          ],
          Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => editAvailable(context),
              child: BudgetGauge(left: left, total: store.periodAmount),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: K.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: ok ? K.lime : K.coral, width: 2)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Aujourd\'hui : max ${euros(allow.roundToDouble())}', style: K.body(14, w: FontWeight.w800)),
                  Text(
                    ok
                        ? 'Dépensé ${euros(today)} · $days jour${days > 1 ? 's' : ''} avant la paie'
                        : '${euros(today - allow)} au-dessus · la limite des jours suivants baisse',
                    style: K.body(11, color: ok ? K.muted : K.coral),
                  ),
                ]),
              ),
              Icon(ok ? Icons.check_circle_rounded : Icons.warning_amber_rounded, color: ok ? K.lime : K.coral),
            ]),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.95,
            children: [for (final c in Expense.categories) EnvelopeTile(c)],
          ),
          const SizedBox(height: 8),
          const ChargesTile(),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: K.ink,
                    side: const BorderSide(color: K.gold, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => addExpenseSheet(context),
                  icon: const Icon(Icons.add_rounded, color: K.gold),
                  label: Text('Dépense', style: K.body(14, w: FontWeight.w800)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: K.muted,
                    side: const BorderSide(color: K.raised, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => openScreen(context, const BudgetScreen()),
                  child: Text('Détail', style: K.body(14, w: FontWeight.w800)),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

Future<void> addExpenseSheet(BuildContext context, {String? cat}) {
  final store = AppScope.read(context);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => AppScope(store: store, child: _ExpenseSheet(cat: cat)),
  );
}

class _ExpenseSheet extends StatefulWidget {
  const _ExpenseSheet({this.cat});
  final String? cat;

  @override
  State<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends State<_ExpenseSheet> {
  final _amount = TextEditingController();
  final _why = TextEditingController();
  late String _cat = widget.cat ?? 'courses';

  @override
  void dispose() {
    _amount.dispose();
    _why.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final value = double.tryParse(_amount.text.replaceAll(',', '.').trim());
    final after = store.envelopeLeft(_cat) - (value ?? 0);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          children: [
            Text('Nouvelle dépense', style: K.display(22)),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              style: K.display(26, color: K.gold),
              decoration: const InputDecoration(hintText: '0,00', suffixText: '€'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _why,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Pourquoi ? (ex. courses de la semaine)'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in Expense.categories)
                  ChoiceChip(
                    avatar: Icon(envelopeIcons[c], size: 16, color: _cat == c ? K.bg : K.gold),
                    label: Text(Expense.labels[c]!),
                    selected: _cat == c,
                    onSelected: (_) => setState(() => _cat = c),
                    selectedColor: K.gold,
                    labelStyle: K.body(13, color: _cat == c ? K.bg : K.ink),
                    backgroundColor: K.raised,
                    side: BorderSide.none,
                    showCheckmark: false,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(Expense.hints[_cat] ?? '', style: K.body(11, color: K.dim)),
            const SizedBox(height: 8),
            Text(
              after >= 0
                  ? 'Il restera ${euros(after.roundToDouble())} dans ${Expense.labels[_cat]}'
                  : '${Expense.labels[_cat]} dépassée de ${euros((-after).roundToDouble())} après cet achat',
              style: K.body(13, color: after >= 0 ? K.lime : K.coral, w: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: value == null ? 'Montant ?' : 'Ajouter ${euros(value)}',
              color: K.gold,
              onPressed: value == null || value <= 0
                  ? null
                  : () async {
                      await store.addExpense(Expense(
                        ts: DateTime.now().millisecondsSinceEpoch,
                        amount: value,
                        why: _why.text.trim(),
                        category: _cat,
                      ));
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Noté. Il te reste ${euros(store.periodLeft())} jusqu\'à la paie.'),
                      ));
                    },
            ),
          ],
        ),
      ),
    );
  }
}

/// Changer le montant mensuel d'une enveloppe.
Future<void> editEnvelope(BuildContext context, String cat) async {
  final store = AppScope.read(context);
  final c = TextEditingController(text: store.envelopeWeight(cat).toStringAsFixed(0));
  final v = await showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: K.card,
      title: Text(Expense.labels[cat]!),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(Expense.hints[cat] ?? '', style: K.body(12, color: K.muted)),
        TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: '€ / mois'),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        TextButton(onPressed: () => Navigator.pop(ctx, double.tryParse(c.text.replaceAll(',', '.').trim())), child: const Text('OK')),
      ],
    ),
  );
  c.dispose();
  if (v != null) await store.setEnvelope(cat, v);
}

/// Changer le jour de paie.
Future<void> editPayday(BuildContext context) async {
  final store = AppScope.read(context);
  final c = TextEditingController(text: '${store.settings.payday}');
  final v = await showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: K.card,
      title: const Text('Jour de paie'),
      content: TextField(controller: c, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(prefixText: 'Le ')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        TextButton(onPressed: () => Navigator.pop(ctx, int.tryParse(c.text.trim())), child: const Text('OK')),
      ],
    ),
  );
  c.dispose();
  if (v != null) await store.setPayday(v);
}

/// Détail : période, frais fixes, plan des enveloppes, dépenses de la période.
class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final list = store.expensesInPeriod();
    final start = DateTime.fromMillisecondsSinceEpoch(store.periodStartMs);
    final end = store.nextPayday().subtract(const Duration(days: 1));
    final spentMap = store.spentByEnvelope();

    return Scaffold(
      appBar: AppBar(title: const Text('Budget')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: K.gold,
        foregroundColor: K.bg,
        onPressed: () => addExpenseSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: Text('Dépense', style: K.body(15, color: K.bg, w: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 90),
        children: [
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Du ${_date(start)} au ${_date(end)}', style: K.display(15)),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(child: Text('Disponible au départ', style: K.body(13, color: K.muted))),
                TextButton(onPressed: () => editAvailable(context), child: Text(euros(store.periodAmount))),
              ]),
              Row(children: [
                Expanded(child: Text('Dépensé', style: K.body(13, color: K.muted))),
                Text(euros(store.spentInPeriod()), style: K.body(13, color: K.gold, w: FontWeight.w800)),
              ]),
              Row(children: [
                Expanded(child: Text('Jour de paie', style: K.body(13, color: K.muted))),
                TextButton(onPressed: () => editPayday(context), child: Text('le ${store.settings.payday}')),
              ]),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => paydayDialog(context),
                  icon: const Icon(Icons.payments_rounded, size: 18),
                  label: const Text('Jour de paie : calculer mon mois'),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          const ChargesTile(),
          const SizedBox(height: 12),
          const _FixedCosts(),
          const SizedBox(height: 12),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.mail_rounded, color: K.gold, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Plan des enveloppes', style: K.display(15))),
                Text('${euros(store.planTotal)} / mois', style: K.body(12, color: K.muted)),
              ]),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Text('Le montant disponible est réparti selon ce plan. Touche une enveloppe pour changer sa part.',
                    style: K.body(11, color: K.dim)),
              ),
              for (final c in Expense.categories)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => editEnvelope(context, c),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Icon(envelopeIcons[c], color: K.gold, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(Expense.labels[c]!, style: K.body(13, w: FontWeight.w800)),
                          Text('${euros(store.envelopeWeight(c))} / mois · ${Expense.hints[c]}', style: K.body(11, color: K.muted)),
                        ]),
                      ),
                      Text(
                        '${euros((spentMap[c] ?? 0).roundToDouble())} / ${euros(store.envelopeAlloc(c).roundToDouble())}',
                        style: K.body(12, color: leftColor(store.envelopeAlloc(c) <= 0 ? 0.0 : store.envelopeLeft(c) / store.envelopeAlloc(c)), w: FontWeight.w800),
                      ),
                    ]),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          Text('Dépenses de la période', style: K.display(18)),
          const SizedBox(height: 8),
          if (list.isEmpty) Text('Aucune dépense notée depuis le ${_date(start)}.', style: K.body(14, color: K.muted)),
          for (final e in list)
            Dismissible(
              key: ValueKey(e.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(color: K.coral, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.delete_rounded, color: K.bg),
              ),
              onDismissed: (_) => store.removeExpense(e),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Icon(envelopeIcons[Expense.group(e.category)], color: K.gold, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.why.isEmpty ? (Expense.labels[e.category] ?? e.category) : e.why, style: K.body(14, w: FontWeight.w800)),
                      Text(
                        '${Expense.labels[e.category] ?? e.category} · ${_date(DateTime.fromMillisecondsSinceEpoch(e.ts))} ${hm(DateTime.fromMillisecondsSinceEpoch(e.ts))}',
                        style: K.body(12, color: K.muted),
                      ),
                    ]),
                  ),
                  Text(euros(e.amount), style: K.display(16, color: K.gold, w: FontWeight.w700)),
                ]),
              ),
            ),
          if (list.isNotEmpty) Text('Glisse une ligne vers la gauche pour la supprimer.', style: K.body(11, color: K.dim)),
        ],
      ),
    );
  }
}

/// Ajouter, modifier ou supprimer un frais fixe.
Future<void> editFixedCost(BuildContext context, String kind, {int? index, String name = '', double amount = 0}) async {
  final store = AppScope.read(context);
  final n = TextEditingController(text: name);
  final a = TextEditingController(text: amount > 0 ? amount.toStringAsFixed(2).replaceAll('.', ',') : '');
  final res = await showDialog<(String, double)>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: K.card,
      title: Text(index == null ? (kind == 'charge' ? 'Nouvelle charge' : 'Nouvel abonnement') : 'Frais fixe'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: n,
          autofocus: index == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Nom (ex. Freebox)'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: a,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: '€ / mois'),
        ),
      ]),
      actions: [
        if (index != null)
          TextButton(onPressed: () => Navigator.pop(ctx, ('', 0.0)), child: Text('Supprimer', style: K.body(14, color: K.coral))),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, (n.text.trim(), double.tryParse(a.text.replaceAll(',', '.').trim()) ?? 0)),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  n.dispose();
  a.dispose();
  if (res != null) await store.setFixedCost(index, kind, res.$1, res.$2);
}

/// Frais fixes : abonnements et charges, prélevés chaque mois, hors enveloppes.
class _FixedCosts extends StatelessWidget {
  const _FixedCosts();

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);

    Widget group(String kind, String title, IconData icon) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(children: [
              Icon(icon, color: K.muted, size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: K.body(13, w: FontWeight.w800))),
              Text(euros(store.fixedTotal(kind)), style: K.body(13, color: K.gold, w: FontWeight.w800)),
            ]),
            for (final f in store.fixedOf(kind))
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => editFixedCost(context, kind, index: f.$1, name: f.$2, amount: f.$3),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 4, 0, 4),
                  child: Row(children: [
                    Expanded(child: Text(f.$2, style: K.body(13, color: K.muted))),
                    Text(euros(f.$3), style: K.body(13, color: K.muted)),
                  ]),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => editFixedCost(context, kind),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(kind == 'charge' ? 'Ajouter une charge' : 'Ajouter un abonnement', style: K.body(12)),
              ),
            ),
          ],
        );

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.event_repeat_rounded, color: K.gold, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('Frais fixes', style: K.display(15))),
            Text('${euros(store.fixedTotal())} / mois', style: K.body(12, color: K.muted)),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Prélevés chaque mois, en dehors des enveloppes. Touche une ligne pour la modifier.', style: K.body(11, color: K.dim)),
          ),
          group('abonnement', 'Abonnements', Icons.subscriptions_rounded),
          group('charge', 'Charges', Icons.home_rounded),
        ],
      ),
    );
  }
}
