import 'package:flutter/material.dart';
import 'domain.dart';
import 'interests.dart';

IconData interestIcon(String id) => switch (id) {
  'beauty' => Icons.face_retouching_natural,
  'health' => Icons.health_and_safety_outlined,
  'food' => Icons.restaurant_outlined,
  'fashion' => Icons.checkroom_outlined,
  'entertainment' => Icons.theaters_outlined,
  'parenting' => Icons.child_care,
  'learning' => Icons.school_outlined,
  'relationships' => Icons.favorite_border,
  'pets' => Icons.pets_outlined,
  'games' => Icons.sports_esports_outlined,
  'business' => Icons.business_center_outlined,
  'travel' => Icons.explore_outlined,
  'cars' => Icons.directions_car_outlined,
  'gadgets' => Icons.devices_outlined,
  'sports' => Icons.sports_soccer,
  'money' => Icons.account_balance_wallet_outlined,
  _ => Icons.cottage_outlined,
};

class InterestPickerPage extends StatefulWidget {
  const InterestPickerPage({
    super.key,
    required this.catalog,
    required this.selected,
    required this.onSave,
  });
  final List<Question> catalog;
  final List<String> selected;
  final Future<void> Function(List<String>) onSave;
  @override
  State<InterestPickerPage> createState() => _InterestPickerPageState();
}

class _InterestPickerPageState extends State<InterestPickerPage> {
  late final Set<String> selected = widget.selected.toSet();
  bool saving = false;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('興味のある分野'),
        toolbarHeight:
            56 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 3.0),
        automaticallyImplyLeading: !saving,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  '好きなことから、英語を。',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                const Text(
                  '気になる分野を1つ以上選んでください。複数選べて、あとからいつでも変更できます。選んだ分野がスキルツリーに並びます。',
                  style: TextStyle(height: 1.7),
                ),
                const SizedBox(height: 18),
                for (final category in interestCategories) ...[
                  Builder(
                    builder: (context) {
                      final questions = selectInterestQuestions(
                        widget.catalog,
                        category.id,
                      );
                      final checked = selected.contains(category.id);
                      return Card(
                        elevation: 0,
                        color: checked ? const Color(0xFFE4EDE7) : Colors.white,
                        child: CheckboxListTile(
                          key: ValueKey('interest-${category.id}'),
                          secondary: Icon(
                            interestIcon(category.id),
                            color: const Color(0xFF176B61),
                          ),
                          title: Text(
                            category.label,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            questions.isEmpty
                                ? '問題の準備中'
                                : '${questions.length}問収録',
                            style: const TextStyle(fontSize: 12),
                          ),
                          value: checked,
                          onChanged: saving || (questions.isEmpty && !checked)
                              ? null
                              : (value) => setState(() {
                                  if (value == true) {
                                    selected.add(category.id);
                                  } else {
                                    selected.remove(category.id);
                                  }
                                }),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: FilledButton.icon(
            onPressed: saving || selected.isEmpty
                ? null
                : () async {
                    setState(() => saving = true);
                    try {
                      final ordered = interestCategories
                          .where((c) => selected.contains(c.id))
                          .map((c) => c.id)
                          .toList();
                      await widget.onSave(ordered);
                      if (context.mounted) Navigator.pop(context, true);
                    } catch (_) {
                      if (context.mounted) {
                        setState(() => saving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('分野を保存できませんでした。もう一度お試しください。'),
                          ),
                        );
                      }
                    }
                  },
            icon: Icon(saving ? Icons.hourglass_empty : Icons.check),
            label: Text(saving ? '保存中…' : '${selected.length}分野を選択して進む'),
          ),
        ),
      ),
    ),
  );
}
