import 'package:flutter/material.dart';
import 'domain.dart';
import 'growth.dart';
import 'course_levels.dart';
import 'interests.dart';

/// Every selected category, represented by five horizontal stage segments.
class CategoryLevels extends StatelessWidget {
  const CategoryLevels({
    super.key,
    required this.catalog,
    required this.data,
    required this.onOpen,
    required this.onEdit,
  });
  final List<Question> catalog;
  final LearningData data;
  final ValueChanged<String> onOpen;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) {
    final all = interestSkills(catalog, data);
    const color = Color(0xFF176B61);
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFD7E4DF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                const Text(
                  'カテゴリーの成長',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    backgroundColor: const Color(0xFFE8F3F0),
                    side: const BorderSide(color: color),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: onEdit,
                  icon: const Icon(Icons.grid_view_rounded, size: 18),
                  label: const Text('カテゴリー変更'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              data.interests.isEmpty
                  ? '興味のある分野を選ぶと、成長がここに表示されます。'
                  : '濃い色は挑戦合格。タップして学習へ。',
              style: const TextStyle(fontSize: 11, color: color),
            ),
            if (data.interests.isNotEmpty) const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns =
                    constraints.maxWidth >= 260 &&
                        MediaQuery.textScalerOf(context).scale(12) <= 15
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 16) / columns;
                return Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    for (final id in data.interests)
                      SizedBox(
                        width: width,
                        child: Builder(
                          builder: (context) {
                            final skills = all
                                .where((s) => s.categoryId == id)
                                .toList();
                            final current = skills.lastWhere(
                              (s) => s.unlocked,
                              orElse: () => skills.first,
                            );
                            final stage = courseLevel(current.level);
                            final complete = skills.every(
                              (s) => s.unlocked && s.challengePassed,
                            );
                            final label =
                                '${interestLabel(id)} ${current.displayLabel}${complete ? ' ・全レベル達成' : ''}';
                            return Tooltip(
                              message: label,
                              child: Semantics(
                                button: true,
                                label: label,
                                child: ExcludeSemantics(
                                  child: InkWell(
                                    key: ValueKey('category-graph-$id'),
                                    onTap: () => onOpen(id),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 7,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                            interestLabel(id),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Row(
                                                  children: [
                                                    for (
                                                      var i = 0;
                                                      i < skills.length;
                                                      i++
                                                    )
                                                      Expanded(
                                                        child: Container(
                                                          height: 7,
                                                          margin: EdgeInsets.only(
                                                            right:
                                                                i ==
                                                                    skills.length -
                                                                        1
                                                                ? 0
                                                                : 3,
                                                          ),
                                                          decoration: BoxDecoration(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  2,
                                                                ),
                                                            color:
                                                                skills[i]
                                                                        .challengePassed &&
                                                                    skills[i]
                                                                        .unlocked
                                                                ? color
                                                                : i ==
                                                                      stage.number -
                                                                          1
                                                                ? const Color(
                                                                    0xFF91C5BB,
                                                                  )
                                                                : const Color(
                                                                    0xFFE6ECE8,
                                                                  ),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Lv.${stage.number}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: color,
                                                ),
                                              ),
                                              if (complete)
                                                const Padding(
                                                  padding: EdgeInsets.only(
                                                    left: 3,
                                                  ),
                                                  child: Icon(
                                                    Icons.check_circle_outline,
                                                    size: 12,
                                                    color: color,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
