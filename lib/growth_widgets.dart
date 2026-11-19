import 'package:flutter/material.dart';
import 'domain.dart';
import 'growth.dart';
import 'interests.dart';
import 'interest_picker.dart';
import 'course_levels.dart';

const _teal = Color(0xFF176B61);

class GrowthCard extends StatelessWidget {
  const GrowthCard({
    super.key,
    required this.data,
    required this.onSkills,
    this.showAdventureActions = true,
  });
  final LearningData data;
  final VoidCallback onSkills;
  final bool showAdventureActions;
  @override
  Widget build(BuildContext context) {
    final growth = GrowthProgress(data);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFE4EDE7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _teal.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: _teal, size: 24),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '共通レベル・役職',
                  style: TextStyle(fontWeight: FontWeight.w700, color: _teal),
                ),
              ),
              IconButton(
                tooltip: '成長履歴',
                onPressed: () => _showGrowthHistory(context, data),
                icon: const Icon(Icons.history_rounded, size: 22),
              ),
              IconButton(
                tooltip: '経験値とスキルのルール',
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('学びが、経験値になる。'),
                    content: const SingleChildScrollView(
                      child: Text(
                        'どのカテゴリーでも、学習のEXPは共通レベルへ合算されます。共通レベルが上がると役職も昇格します。興味分野を変えても、過去に学んだ分のEXPは残ります。\n\n「できた」で10 EXP、「まだ難しい」でも5 EXP。復習や繰り返しにも経験値が入り、レベルアップします。修行モードでの文法練習も、同じ共通EXPに加算されます。クエストを達成し、報酬を受け取ると追加のEXPが入ります。\n\nスキルは、同じ問題の繰り返しではなく、異なる問題を一度以上「できた」にすると育ちます。各分野には5段階のオリジナル称号があり、挑戦の合格で次の称号へ成長します。各レベルを8割クリア（端数切り上げ）すると、そのレベルの挑戦問題が開きます。挑戦は毎回ランダムに5問、その回で4問以上「できた」にすると合格し、次の難易度が開きます。レベル5の合格はその分野の最終達成です。判定は自己評価です。\n\n起動や学習時間だけではEXPは増えません。レベルとスキルはアプリ内の学習実績を表す目安です。',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('わかりました'),
                      ),
                    ],
                  ),
                ),
                icon: const Icon(Icons.help_outline, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Lv. ${growth.level}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: _teal,
                ),
              ),
              TextButton(
                onPressed: () => showAdventurerRoles(context, growth),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 36),
                ),
                child: Text(
                  '役職：${growth.title}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: growth.fraction,
            minHeight: 10,
            color: _teal,
            backgroundColor: Colors.white,
            borderRadius: BorderRadius.circular(6),
            semanticsLabel:
                '次のレベルまでの経験値 ${growth.current} / ${growth.required} EXP',
          ),
          const SizedBox(height: 10),
          Text(
            'あと ${growth.remaining} EXPで Lv. ${growth.level + 1}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '累計 ${growth.xp} EXP',
            style: const TextStyle(fontSize: 12, color: _teal),
          ),
          const SizedBox(height: 8),
          if (growth.nextRole != null)
            Text(
              '次の役職「${growth.titleFor(growth.nextRole!)}」は Lv. ${growth.nextRole!.minLevel}',
              style: const TextStyle(fontSize: 12, color: _teal),
            )
          else
            const Text(
              '最高役職に到達！ 冒険はまだ続きます。',
              style: TextStyle(fontSize: 12, color: _teal),
            ),
          if (showAdventureActions) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onSkills,
              icon: const Icon(Icons.account_tree_outlined),
              label: const Text('スキルツリーを見る'),
            ),
          ],
        ],
      ),
    );
  }
}

void _showGrowthHistory(BuildContext context, LearningData data) {
  final growth = GrowthProgress(data);
  final nextRole = growth.nextRole;
  final levels =
      data.levelUpDays.keys.where((level) => level <= growth.level).toList()
        ..sort((a, b) => b.compareTo(a));
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('成長履歴'),
      scrollable: true,
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('現在 Lv. ${growth.level} ・ ${growth.title}'),
            Text('Lv. ${growth.level + 1}まであと ${growth.remaining} EXP'),
            Text(
              nextRole == null
                  ? '最高の称号に到達しました'
                  : '次の称号：${growth.titleFor(nextRole)}（Lv. ${nextRole.minLevel}）',
            ),
            const Divider(height: 28),
            Text('称号の変遷', style: Theme.of(ctx).textTheme.titleSmall),
            for (final role in adventurerRoles.reversed)
              if (role.minLevel <= growth.level)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(role.title),
                  subtitle: Text(
                    'Lv. ${role.minLevel} ・ '
                    '${role.minLevel == 1 ? '最初の称号' : data.levelUpDays[role.minLevel] ?? '日付の記録なし'}',
                  ),
                ),
            const Divider(height: 28),
            Text('レベルアップ履歴', style: Theme.of(ctx).textTheme.titleSmall),
            if (levels.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('今後のレベルアップがここに記録されます。'),
              ),
            for (final level in levels)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Lv. $level に到達'),
                subtitle: Text(data.levelUpDays[level]!),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('閉じる'),
        ),
      ],
    ),
  );
}

void showAdventurerRoles(BuildContext context, GrowthProgress growth) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('冒険者の役職'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('どのカテゴリーを学んでも、EXPは同じ冒険者レベルへ。復習でも成長します。'),
            const SizedBox(height: 12),
            for (final role in adventurerRoles)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  growth.level >= role.minLevel
                      ? Icons.verified_outlined
                      : Icons.lock_outline,
                ),
                title: Text(growth.titleFor(role)),
                subtitle: Text(
                  'Lv. ${role.minLevel}から${role == growth.role ? ' ・現在の役職' : ''}',
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('閉じる'),
        ),
      ],
    ),
  );
}

class SkillChoice {
  const SkillChoice(this.scene, this.level, {this.challenge = false});
  final bool challenge;
  final String scene, level;
}

class SkillTreePage extends StatefulWidget {
  const SkillTreePage({
    super.key,
    required this.catalog,
    required this.data,
    this.initialCategory,
    this.onCategoryChanged,
  });
  final List<Question> catalog;
  final LearningData data;
  final String? initialCategory;
  final ValueChanged<String>? onCategoryChanged;
  @override
  State<SkillTreePage> createState() => _SkillTreePageState();
}

class _SkillTreePageState extends State<SkillTreePage> {
  late String category;
  int selectedStage = 0;
  @override
  void initState() {
    super.initState();
    category = widget.data.interests.contains(widget.initialCategory)
        ? widget.initialCategory!
        : widget.data.interests.firstOrNull ?? '';
    selectedStage = currentStage(category);
  }

  int currentStage(String id) {
    final skills = interestSkills(
      widget.catalog,
      widget.data,
    ).where((s) => s.categoryId == id).toList();
    final next = skills.indexWhere((s) => s.unlocked && !s.challengePassed);
    return next < 0 ? (skills.isEmpty ? 0 : skills.length - 1) : next;
  }

  Future<void> switchCategory() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (_) => _CategorySearch(
        categories: widget.data.interests,
        selected: category,
      ),
    );
    if (choice == null || !mounted || choice == category) return;
    setState(() {
      category = choice;
      selectedStage = currentStage(choice);
    });
    widget.onCategoryChanged?.call(choice);
  }

  @override
  Widget build(BuildContext context) {
    final skills = interestSkills(
      widget.catalog,
      widget.data,
    ).where((s) => s.categoryId == category).toList();
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: const Text('スキルツリー')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: skills.isEmpty
                ? const Center(child: Text('興味のある分野を選んでください。'))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: OutlinedButton.icon(
                          onPressed: switchCategory,
                          icon: Icon(interestIcon(category)),
                          label: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  interestLabel(category),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Icon(Icons.expand_more),
                            ],
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 18),
                        child: Text(
                          'カテゴリーを切り替えて、学習レベルを選択',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          key: ValueKey('$category-$selectedStage'),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: _CategoryCharacterCard(
                                      category: category,
                                      skill: skills[selectedStage],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 6,
                                    child: Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        for (var i = 0; i < skills.length; i++)
                                          ChoiceChip(
                                            label: Text(
                                              MediaQuery.textScalerOf(
                                                        context,
                                                      ).scale(14) >
                                                      18
                                                  ? 'Lv. ${i + 1}'
                                                  : '${i + 1} ${skills[i].unlocked ? courseLevel(skills[i].level, category: category).name : hiddenTitle}',
                                            ),
                                            avatar: Icon(
                                              skills[i].challengePassed
                                                  ? Icons.check_circle_outline
                                                  : skills[i].unlocked
                                                  ? Icons.circle_outlined
                                                  : Icons.lock_outline,
                                              size: 16,
                                            ),
                                            selected: selectedStage == i,
                                            onSelected: (_) => setState(
                                              () => selectedStage = i,
                                            ),
                                            tooltip: skills[i].displayLabel,
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _SkillNode(
                                skill: skills[selectedStage],
                                previousLabel: selectedStage > 0
                                    ? skills[selectedStage - 1].displayLabel
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                '各レベルの通常問題を8割クリア → 挑戦で8割「できた」 → 次のレベルへ。レベル5の挑戦がゴールです。',
                                style: TextStyle(fontSize: 12, height: 1.7),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _CategoryCharacterCard extends StatelessWidget {
  const _CategoryCharacterCard({required this.category, required this.skill});

  final String category;
  final LearningSkill skill;

  @override
  Widget build(BuildContext context) {
    final stage = courseLevel(skill.level, category: category);
    final unlocked = skill.unlocked;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: const Color(0xFFF3EFE4),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 1,
        child: unlocked
            ? Image.asset(
                'assets/characters/$category/${stage.key}.jpg',
                fit: BoxFit.contain,
                semanticLabel: '${stage.name}のキャラクター',
              )
            : const Icon(Icons.lock_outline_rounded, size: 32, color: _teal),
      ),
    );
  }
}

class _CategorySearch extends StatefulWidget {
  const _CategorySearch({required this.categories, required this.selected});
  final List<String> categories;
  final String selected;
  @override
  State<_CategorySearch> createState() => _CategorySearchState();
}

class _CategorySearchState extends State<_CategorySearch> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final shown = widget.categories
        .where(
          (id) => interestLabel(
            id,
          ).toLowerCase().contains(query.trim().toLowerCase()),
        )
        .toList();
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'カテゴリーを選ぶ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '閉じる',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'カテゴリーを検索',
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                      onChanged: (value) => setState(() => query = value),
                    ),
                    const SizedBox(height: 12),
                    if (shown.isEmpty) const Text('該当するカテゴリーがありません。'),
                    for (final id in shown)
                      ListTile(
                        leading: Icon(interestIcon(id)),
                        title: Text(interestLabel(id)),
                        selected: id == widget.selected,
                        trailing: id == widget.selected
                            ? const Icon(Icons.check)
                            : null,
                        onTap: () => Navigator.pop(context, id),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkillNode extends StatelessWidget {
  const _SkillNode({required this.skill, this.previousLabel});
  final String? previousLabel;
  final LearningSkill skill;
  @override
  Widget build(BuildContext context) {
    final color = skill.unlocked ? _teal : Colors.grey.shade600;
    final previous = previousLabel ?? '前のレベル';
    final label = skill.displayLabel;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: skill.rank > 0
            ? const Color(0xFFE4EDE7)
            : skill.unlocked
            ? Colors.white
            : const Color(0xFFECEEE8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                skill.unlocked
                    ? skill.rank > 0
                          ? Icons.auto_awesome
                          : Icons.spa_outlined
                    : Icons.lock_outline,
                color: color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  skill.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 19,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              Text(label),
              Text('${skill.cleared} / ${skill.total}問クリア'),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: skill.total == 0
                ? 0
                : (skill.cleared / skill.total).clamp(0, 1),
            minHeight: 7,
            color: color,
            backgroundColor: Colors.white,
            borderRadius: BorderRadius.circular(5),
            semanticsLabel:
                '${skill.name}のクリア数 ${skill.cleared} / ${skill.total}問',
          ),
          if (skill.total == 0 || !skill.unlocked || skill.rank == 3) ...[
            const SizedBox(height: 10),
            Text(
              skill.total == 0
                  ? 'この難易度の問題はありません。'
                  : !skill.unlocked
                  ? '$sceneLabel：$previousの挑戦問題に合格すると解放'
                  : '全問クリア！',
              style: TextStyle(fontSize: 12, color: color, height: 1.6),
            ),
          ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: skill.unlocked
                ? () => Navigator.pop(
                    context,
                    SkillChoice(skill.categoryId ?? skill.scene, skill.level),
                  )
                : null,
            icon: Icon(skill.rank == 3 ? Icons.replay : Icons.arrow_forward),
            label: Text('$labelの学習へ'),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5E8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '$labelの挑戦問題',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  skill.challengePassed
                      ? (skill.level == courseLevels.last.key
                            ? '合格済み！この分野の最終チャレンジ達成です。'
                            : '合格済み！次の難易度が解放されています。')
                      : !skill.unlocked
                      ? 'この難易度の解放後に挑戦できます。'
                      : skill.total == 0
                      ? 'この難易度の問題はありません。'
                      : skill.challengeUnlocked
                      ? 'ランダムに${skill.challengeCount}問。その回で${(skill.challengeCount * 4 + 4) ~/ 5}問以上「できた」で合格。'
                      : '通常問題を${skill.challengeGoal} / ${skill.total}問クリアすると解放（あと${skill.challengeGoal - skill.cleared}問）。',
                  style: const TextStyle(fontSize: 12, height: 1.7),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: skill.challengeUnlocked
                      ? () => Navigator.pop(
                          context,
                          SkillChoice(
                            skill.categoryId ?? skill.scene,
                            skill.level,
                            challenge: true,
                          ),
                        )
                      : null,
                  icon: Icon(
                    skill.challengePassed ? Icons.replay : Icons.flag_outlined,
                  ),
                  label: Text(
                    skill.challengePassed ? '$labelの挑戦問題に再挑戦' : '$labelの挑戦問題へ',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get sceneLabel => skill.scene;
}
