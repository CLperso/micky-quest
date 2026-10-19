import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';

String euros(double v) => '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2).replaceAll('.', ',')} €';

/// Carte du QG : reste du mois et ajout rapide.
/// Modifier le budget du mois.
Future<void> editBudget(BuildContext context) async {
  final store = AppScope.read(context);
  final budget = store.settings.monthlyBudget;
  final c = TextEditingController(text: budget > 0 ? budget.toStringAsFixed(0) : '');
  final v = await showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: K.card,
      title: const Text('Budget du mois'),
      content: TextField(
        controller: c,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(suffixText: '€'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        TextButton(onPressed: () => Navigator.pop(ctx, double.tryParse(c.text.replaceAll(',', '.'))), child: const Text('OK')),
      ],
    ),
  );
  c.dispose();
  if (v != null) await store.setMonthlyBudget(v);
}

/// Modifier le plafond d'une enveloppe (vide ou 0 = la retirer).
Future<void> editEnvelope(BuildContext context, String cat) async {
  final store = AppScope.read(context);
  final cur = store.envelopeFor(cat);
  final c = TextEditingController(text: cur > 0 ? cur.toStringAsFixed(0) : '');
  final v = await showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: K.card,
      title: Text(Expense.labels[cat] ?? cat),
      content: TextField(
        controller: c,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(suffixText: '€ / mois', helperText: 'Vide ou 0 : pas d\'enveloppe'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        TextButton(onPressed: () => Navigator.pop(ctx, double.tryParse(c.text.replaceAll(',', '.')) ?? 0), child: const Text('OK')),
      ],
    ),
  );
  c.dispose();
  if (v != null) await store.setEnvelope(cat, v);
}

class BudgetCard extends StatelessWidget {
  const BudgetCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final budget = store.settings.monthlyBudget;
    final spent = store.spentInMonth(DateTime.now());
    final left = budget - spent;
    final frac = budget <= 0 ? 0.0 : (spent / budget).clamp(0.0, 1.0);
    final color = budget <= 0 ? K.gold : (left < 0 ? K.coral : (frac > 0.8 ? K.gold : K.lime));
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.savings_rounded, color: K.gold, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Budget du mois', style: K.display(16))),
              IconButton(
                tooltip: 'Modifier le budget',
                onPressed: () => editBudget(context),
                icon: const Icon(Icons.edit_rounded, color: K.muted, size: 18),
              ),
              TextButton(onPressed: () => openScreen(context, const BudgetScreen()), child: const Text('Détail')),
            ],
          ),
          if (budget <= 0)
            InkWell(
              onTap: () => editBudget(context),
              child: Text('Touche pour fixer ton budget mensuel.', style: K.body(13, color: K.gold)),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(euros(left), style: K.display(24, color: color, w: FontWeight.w700)),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(left < 0 ? 'dépassé' : 'restants sur ${euros(budget)}', style: K.body(12, color: K.muted)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Bar(frac, color: color),
            const SizedBox(height: 10),
            Builder(builder: (context) {
              final allow = store.dailyAllowance(store.todayKey);
              final today = store.spentOn(store.todayKey);
              final ok = today <= allow;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: K.bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: ok ? K.lime : K.coral, width: 2)),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Aujourd\'hui : max ${euros(allow)}', style: K.body(14, w: FontWeight.w800)),
                      Text(
                        ok
                            ? 'Dépensé ${euros(today)} · reste ${euros(allow - today)} · sous la limite = +10 XP demain'
                            : 'Dépensé ${euros(today)} · ${euros(today - allow)} au-dessus · la limite des jours suivants baisse',
                        style: K.body(11, color: ok ? K.muted : K.coral),
                      ),
                    ]),
                  ),
                  Icon(ok ? Icons.check_circle_rounded : Icons.warning_amber_rounded, color: ok ? K.lime : K.coral),
                ]),
              );
            }),
          ],
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: K.ink,
                side: const BorderSide(color: K.gold, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => addExpenseSheet(context),
              icon: const Icon(Icons.add_rounded, color: K.gold),
              label: Text('Noter une dépense', style: K.body(14, w: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> addExpenseSheet(BuildContext context) {
  final store = AppScope.read(context);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => AppScope(store: store, child: const _ExpenseSheet()),
  );
}

class _ExpenseSheet extends StatefulWidget {
  const _ExpenseSheet();

  @override
  State<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends State<_ExpenseSheet> {
  final _amount = TextEditingController();
  final _why = TextEditingController();
  String _cat = 'autre';

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
              decoration: const InputDecoration(hintText: 'Pourquoi ? (ex. cadeau, courses de la semaine…)'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in Expense.categories)
                  ChoiceChip(
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
            if (store.envelopeFor(_cat) > 0) ...[
              const SizedBox(height: 10),
              Builder(builder: (context) {
                final left = store.envelopeLeft(_cat) - (value ?? 0);
                return Text(
                  left >= 0
                      ? 'Enveloppe ${Expense.labels[_cat]} : il restera ${euros(left)} ce mois-ci'
                      : 'Enveloppe ${Expense.labels[_cat]} : dépassée de ${euros(-left)} après cet achat',
                  style: K.body(13, color: left >= 0 ? K.lime : K.coral, w: FontWeight.w700),
                );
              }),
            ],
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
                      final left = store.remainingThisMonth();
                      final env = store.envelopeFor(_cat) > 0
                          ? ' ${Expense.labels[_cat]} : ${store.envelopeLeft(_cat) >= 0 ? 'reste ${euros(store.envelopeLeft(_cat))}' : 'dépassé de ${euros(-store.envelopeLeft(_cat))}'}.'
                          : '';
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(store.settings.monthlyBudget > 0
                            ? 'Noté. Il reste ${euros(left)} ce mois-ci.$env'
                            : 'Dépense notée.$env'),
                      ));
                    },
            ),
          ],
        ),
      ),
    );
  }
}

/// Détail du mois : budget, répartition et liste des dépenses.
class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  DateTime _month = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final list = store.expensesInMonth(_month);
    final spent = store.spentInMonth(_month);
    final budget = store.settings.monthlyBudget;
    final byCat = store.spentByCategory(_month).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    const months = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
    final now = DateTime.now();
    final isCurrent = store.monthKey(_month) == store.monthKey(now);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dépenses'),
        actions: [
          IconButton(
            onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Center(child: Text('${months[_month.month - 1]} ${_month.year}', style: K.body(14, w: FontWeight.w800))),
          IconButton(
            onPressed: isCurrent ? null : () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Budget mensuel', style: K.body(14))),
                    TextButton(
                      onPressed: () => editBudget(context),
                      child: Text(budget > 0 ? euros(budget) : 'Fixer'),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(euros(spent), style: K.display(26, color: K.gold, w: FontWeight.w700)),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('dépensés', style: K.body(12, color: K.muted)),
                    ),
                    const Spacer(),
                    if (budget > 0)
                      Text(
                        budget - spent < 0 ? 'dépassé de ${euros(spent - budget)}' : 'reste ${euros(budget - spent)}',
                        style: K.body(14, color: budget - spent < 0 ? K.coral : K.lime, w: FontWeight.w800),
                      ),
                  ],
                ),
                if (budget > 0) ...[
                  const SizedBox(height: 6),
                  Bar((spent / budget).clamp(0.0, 1.0), color: spent > budget ? K.coral : K.gold),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Envelopes(month: _month, byCat: byCat, spent: spent),
          const SizedBox(height: 16),
          Text('Dépenses', style: K.display(18)),
          const SizedBox(height: 8),
          if (list.isEmpty) Text('Aucune dépense ce mois-ci.', style: K.body(14, color: K.muted)),
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
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.why.isEmpty ? (Expense.labels[e.category] ?? e.category) : e.why, style: K.body(14, w: FontWeight.w800)),
                          Text(
                            '${Expense.labels[e.category] ?? e.category} · ${DateTime.fromMillisecondsSinceEpoch(e.ts).day}/${DateTime.fromMillisecondsSinceEpoch(e.ts).month} ${hm(DateTime.fromMillisecondsSinceEpoch(e.ts))}',
                            style: K.body(12, color: K.muted),
                          ),
                        ],
                      ),
                    ),
                    Text(euros(e.amount), style: K.display(16, color: K.gold, w: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          if (list.isNotEmpty) Text('Glisse une ligne vers la gauche pour la supprimer.', style: K.body(11, color: K.dim)),
        ],
      ),
    );
  }
}

/// Enveloppes du mois : dépensé / plafond par catégorie. Touche une ligne pour changer son plafond.
class _Envelopes extends StatelessWidget {
  const _Envelopes({required this.month, required this.byCat, required this.spent});

  final DateTime month;
  final List<MapEntry<String, double>> byCat;
  final double spent;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final env = store.settings.envelopes;
    final spentMap = {for (final e in byCat) e.key: e.value};
    final cats = [
      for (final c in Expense.categories)
        if ((env[c] ?? 0) > 0 || (spentMap[c] ?? 0) > 0) c,
      for (final c in spentMap.keys)
        if (!Expense.categories.contains(c)) c,
    ];
    final totalCap = env.values.fold(0.0, (a, v) => a + v);
    final d = DateTime.now();
    final isCurrent = store.monthKey(month) == store.monthKey(d);
    // Part du mois écoulée, pour repérer une enveloppe qui part trop vite.
    final pace = isCurrent ? d.day / DateTime(d.year, d.month + 1, 0).day : 1.0;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.mail_rounded, color: K.gold, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('Enveloppes', style: K.display(15))),
            if (totalCap > 0) Text('${euros(totalCap)} / mois', style: K.body(12, color: K.muted)),
          ]),
          const SizedBox(height: 6),
          if (env.isEmpty) ...[
            Text(
              'Une enveloppe par poste (courses, livraison, Amazon, tabac…) pour voir tout de suite où ça part. '
              'Le plan prévoit ~${euros(Expense.plan.values.fold(0.0, (a, v) => a + v))} par mois.',
              style: K.body(13, color: K.muted),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: K.ink,
                  side: const BorderSide(color: K.gold, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => store.applyBudgetPlan(),
                icon: const Icon(Icons.auto_awesome_rounded, color: K.gold),
                label: Text('Appliquer le plan', style: K.body(14, w: FontWeight.w800)),
              ),
            ),
          ],
          for (final c in cats)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => editEnvelope(context, c),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Builder(builder: (context) {
                  final cap = env[c] ?? 0;
                  final used = spentMap[c] ?? 0;
                  final frac = cap > 0 ? used / cap : (spent == 0 ? 0.0 : used / spent);
                  final color = cap <= 0
                      ? K.muted
                      : used > cap
                          ? K.coral
                          : (frac > pace + 0.1 ? K.gold : K.lime);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text(Expense.labels[c] ?? c, style: K.body(13))),
                        Text(
                          cap > 0 ? '${euros(used)} / ${euros(cap)}' : euros(used),
                          style: K.body(13, color: color, w: FontWeight.w800),
                        ),
                      ]),
                      const SizedBox(height: 3),
                      Bar(frac.clamp(0.0, 1.0), color: color, height: 5),
                      if (cap > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            used > cap ? 'dépassé de ${euros(used - cap)}' : 'reste ${euros(cap - used)}',
                            style: K.body(11, color: used > cap ? K.coral : K.dim),
                          ),
                        ),
                    ],
                  );
                }),
              ),
            ),
          if (env.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Touche une enveloppe pour changer son plafond. Jaune : elle part plus vite que le mois.',
                style: K.body(11, color: K.dim),
              ),
            ),
        ],
      ),
    );
  }
}
