import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';
import 'domain.dart';
import 'store.dart';
import 'speech.dart';
import 'answer_audio_controls.dart';
import 'answer_study_notes.dart';
import 'bundled_speech.dart';
import 'activity.dart';
import 'learning_dashboard.dart';
import 'today_share.dart';
import 'growth.dart';
import 'challenge.dart';
import 'course_levels.dart';
import 'stages.dart';
import 'growth_widgets.dart';
import 'category_levels.dart';
import 'interest_picker.dart';
import 'interests.dart';
import 'usage_guide.dart';
import 'reminders.dart';
import 'reminder_notifications.dart';
import 'reminder_settings_page.dart';
import 'grammar.dart';
import 'grammar_widgets.dart';
import 'quests.dart';
import 'quest_widgets.dart';
import 'study_analytics.dart';
import 'monetization.dart';
import 'practice_allowance.dart';
import 'interactive_tutorial.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final progress = LocalProgressStore();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Noto Sans JP',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Kokoro — bundled AI speech',
    ], await rootBundle.loadString('assets/audio/LICENSE-Kokoro.txt'));
  });
  runApp(
    PhraseFlowApp(
      store: progress,
      claimFirstRun: progress.claimFirstRun,
      reminders: ReminderManager(
        store: LocalReminderStore(),
        backend: LocalReminderBackend(),
      ),
      modeStore: LocalTrainingModeStore(),
      analytics: await StudyAnalytics.connect(),
      monetization: Monetization.configured(),
      requestStoreReview: () async {
        final review = InAppReview.instance;
        if (await review.isAvailable() && await progress.claimStoreReview()) {
          await review.requestReview();
        }
      },
    ),
  );
}

const ink = Color(0xFF172F35);
const teal = Color(0xFF176B61);
const paper = Color(0xFFF6F7F2);

class PhraseFlowApp extends StatelessWidget {
  const PhraseFlowApp({
    super.key,
    required this.store,
    this.loadCatalog,
    this.reminders,
    this.loadGrammar,
    this.modeStore,
    this.analytics,
    this.monetization,
    this.claimFirstRun,
    this.requestStoreReview,
  });
  final ProgressStore store;
  final ReminderManager? reminders;
  final Future<GrammarCatalog> Function()? loadGrammar;
  final TrainingModeStore? modeStore;
  final StudyAnalytics? analytics;
  final Monetization? monetization;
  final Future<bool> Function()? claimFirstRun;
  final Future<void> Function()? requestStoreReview;
  final Future<List<Question>> Function()? loadCatalog;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'インクリ',
    debugShowCheckedModeBanner: false,
    locale: const Locale('ja'),
    supportedLocales: const [Locale('ja')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoSansJP',
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: teal,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: teal,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 54),
          backgroundColor: teal,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 54)),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        bodyLarge: TextStyle(fontSize: 17, height: 1.6, color: ink),
      ),
    ),
    home: StudyHome(
      store: store,
      reminders: reminders,
      modeStore: modeStore,
      analytics: analytics,
      monetization: monetization,
      claimFirstRun: claimFirstRun,
      requestStoreReview: requestStoreReview,
      loadGrammar:
          loadGrammar ??
          (loadCatalog == null
              ? () async => GrammarCatalog.decode(
                  await rootBundle.loadString('assets/grammar.json'),
                )
              : () async => const GrammarCatalog.empty()),
      loadCatalog:
          loadCatalog ??
          () async => Question.decode(
            await rootBundle.loadString('assets/questions.json'),
          ),
    ),
  );
}

class StudyHome extends StatefulWidget {
  const StudyHome({
    super.key,
    required this.store,
    required this.loadCatalog,
    this.reminders,
    this.loadGrammar,
    this.modeStore,
    this.analytics,
    this.monetization,
    this.claimFirstRun,
    this.requestStoreReview,
  });
  final ProgressStore store;
  final ReminderManager? reminders;
  final Future<GrammarCatalog> Function()? loadGrammar;
  final TrainingModeStore? modeStore;
  final StudyAnalytics? analytics;
  final Monetization? monetization;
  final Future<bool> Function()? claimFirstRun;
  final Future<void> Function()? requestStoreReview;
  final Future<List<Question>> Function() loadCatalog;
  @override
  State<StudyHome> createState() => _StudyHomeState();
}

class _StudyHomeState extends State<StudyHome> with WidgetsBindingObserver {
  List<Question> catalog = [];
  GrammarCatalog grammar = const GrammarCatalog.empty();
  TrainingMode mode = TrainingMode.adventure;
  bool modeSaving = false;
  final _homeScroll = ScrollController();
  List<Question> get allQuestions => [...catalog, ...grammar.questions];
  LearningData data = LearningData();
  bool loading = true, failed = false;
  int page = 0;
  Future<void> _writes = Future.value();
  bool _startingPractice = false;
  bool _tutorialRunning = false;
  bool _storeReviewScheduled = false;
  bool _showUpdateNotice = false;
  final _tutorialMode = GlobalKey();
  final _tutorialGrowth = GlobalKey();
  final _tutorialGrammar = GlobalKey();
  final _tutorialStart = GlobalKey();
  final _tutorialReview = GlobalKey();
  final _tutorialHistory = GlobalKey();
  final _tutorialChart = GlobalKey();
  final _tutorialGuide = GlobalKey();
  final _tutorialTickets = GlobalKey();
  bool get _limited => widget.monetization?.unlimited == false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.monetization?.addListener(_refreshMonetization);
    _load();
    unawaited(_restoreReminders());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.monetization?.removeListener(_refreshMonetization);
    widget.monetization?.dispose();
    _homeScroll.dispose();
    super.dispose();
  }

  void _refreshMonetization() {
    if (mounted) setState(() {});
  }

  Future<void> _update(LearningData Function(LearningData) change) {
    final action = _writes.then((_) async {
      var next = _withLevelReward(data, change(data));
      if (identical(next, data)) return;
      if (next.earnedXp > data.earnedXp) {
        final previous = GrowthProgress(data).level;
        final current = GrowthProgress(next).level;
        if (current > previous) {
          next = next.recordLevelUps(previous, current, DateTime.now());
        }
      }
      await widget.store.save(next);
      data = next;
      if (mounted) {
        setState(() {});
      }
    });
    _writes = action.catchError((Object _) {});
    return action;
  }

  void _scheduleStoreReview() {
    final request = widget.requestStoreReview;
    if (request == null || _storeReviewScheduled || _tutorialRunning) return;
    final attempts = data.entries.values.fold(0, (sum, e) => sum + e.attempts);
    if (attempts < 30 ||
        data.days.values.where((day) => day.questions > 0).length < 2) {
      return;
    }
    _storeReviewScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (ModalRoute.of(context)?.isCurrent != true ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        _storeReviewScheduled = false;
        return;
      }
      try {
        await request();
      } catch (_) {
        // The store may decline a request; practice must continue normally.
      }
    });
  }

  LearningData _withLevelReward(LearningData before, LearningData after) {
    if (!_limited || after.earnedXp <= before.earnedXp) return after;
    final levels = GrowthProgress(after).level - GrowthProgress(before).level;
    return levels > 0
        ? after.withAllowance(after.allowance.grantTickets(levels))
        : after;
  }

  Future<void> _rememberVisit() async {
    final now = DateTime.now();
    if (loading || failed || data.visits.contains(dayKey(now))) return;
    try {
      await _update((current) => current.visit(now));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('起動日の記録を保存できませんでした。次の学習時に再試行します。')),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_rememberVisit());
      unawaited(_restoreReminders());
      unawaited(widget.monetization?.recheckOwnership());
    }
  }

  Future<void> _restoreReminders() async {
    try {
      await widget.reminders?.restore();
    } catch (_) {
      debugPrint('Reminder restoration deferred until next app open.');
    }
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      final questions = await widget.loadCatalog();
      final grammarCatalog =
          await widget.loadGrammar?.call() ?? const GrammarCatalog.empty();
      if ({
            ...questions.map((q) => q.id),
            ...grammarCatalog.questions.map((q) => q.id),
          }.length !=
          questions.length + grammarCatalog.questions.length) {
        throw const FormatException('Repeated question IDs across modes');
      }
      var selectedMode = TrainingMode.adventure;
      try {
        selectedMode = await widget.modeStore?.load() ?? TrainingMode.adventure;
      } catch (_) {
        debugPrint(
          'Training mode preference unavailable; using adventure mode.',
        );
      }
      final saved = await widget.store.load();
      var firstRun = false;
      try {
        firstRun = await widget.claimFirstRun?.call() ?? false;
      } catch (_) {
        debugPrint('First-run preference unavailable.');
      }
      if (!mounted) return;
      setState(() {
        catalog = questions;
        grammar = grammarCatalog;
        mode = selectedMode;
        data = saved;
        loading = false;
      });
      unawaited(_rememberVisit());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_finishStartup(firstRun));
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          failed = true;
          loading = false;
        });
      }
    }
  }

  Future<void> _finishStartup(bool firstRun) async {
    if (firstRun) {
      await showUsageGuide(context, introductionOnly: true);
      if (mounted) await _runTutorial();
      if (mounted) await _openReminderSettings();
    }
    if (!mounted) return;
    unawaited(_checkForUpdate());
    if (widget.analytics?.needsSetup == true) await _offerAnalyticsSetup();
    if (!mounted) return;
    await widget.monetization?.connect();
  }

  Future<void> _offerAnalyticsSetup() async {
    var enabled = true;
    final choice = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          scrollable: true,
          title: const Text('学習状況の計測'),
          content: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('学習状況の計測に協力する'),
            subtitle: const Text(
              'アプリ改善のため、練習を始めた日や問題数の達成状況、アプリ・端末の情報やアプリを識別するIDをGoogleのFirebase Analyticsに送信します。ⓘからいつでもオフにできます。',
            ),
            value: enabled,
            onChanged: (value) => refresh(() => enabled = value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('協力しない'),
            ),
            if (enabled)
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('協力して続ける'),
              ),
          ],
        ),
      ),
    );
    if (choice != null && mounted) await _changeAnalytics(choice);
  }

  Future<void> _checkForUpdate() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    const channel = MethodChannel('biz.wisemap.encre/app_update');
    try {
      final available = await channel.invokeMethod<bool>('isUpdateAvailable');
      if (available == true && mounted) {
        setState(() => _showUpdateNotice = true);
      }
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }

  Future<void> _openPlayUpdate() async {
    const packageName = 'biz.wisemap.encre';
    for (final link in [
      'market://details?id=$packageName',
      'https://play.google.com/store/apps/details?id=$packageName',
    ]) {
      try {
        if (await launchUrl(
          Uri.parse(link),
          mode: LaunchMode.externalApplication,
        )) {
          return;
        }
      } on PlatformException {
        continue;
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Google Playを開けませんでした。')));
    }
  }

  Future<void> _openUsageGuide() async {
    if (await showUsageGuide(context, offerTutorial: true) == true && mounted) {
      await _runTutorial();
    }
  }

  Rect _tutorialModeFraction(bool grammarMode) {
    final width = MediaQuery.sizeOf(context).width.clamp(0, 680) - 48;
    final vertical =
        width < 300 || MediaQuery.textScalerOf(context).scale(14) > 18;
    return vertical
        ? Rect.fromLTWH(0, grammarMode ? .5 : 0, 1, .5)
        : Rect.fromLTWH(grammarMode ? .5 : 0, 0, .5, 1);
  }

  Future<void> _runTutorial() async {
    final unit = grammar.units.where((u) => u.id == 'be').firstOrNull;
    if (_tutorialRunning || unit == null) return;
    final tour = InteractiveTutorial();
    final beforeXp = GrowthProgress(data).xp;
    setState(() {
      _tutorialRunning = true;
      page = 0;
    });
    try {
      await _changeMode(TrainingMode.adventure);
      if (!mounted) return;
      if (await tour.point(
                context,
                title: '興味のあるテーマで、冒険しよう',
                description:
                    '冒険モードでは、旅行や料理など好きなカテゴリーを選べます。「スキルツリーを見る」から練習を始め、挑戦問題に合格すると次の段階へ進めます。まずは「冒険モード」をタップしてみましょう。',
                spots: [
                  TutorialSpot(
                    _tutorialMode,
                    'adventure',
                    '冒険モード',
                    fraction: _tutorialModeFraction(false),
                  ),
                ],
              ) !=
              null &&
          mounted) {
        if (await tour.point(
                  context,
                  title: '文法を思い出すなら、修行モード',
                  description:
                      '修行モードは、中学英文法を一つずつ練習するモードです。学年と文法を選んで始められます。「修行モード」をタップしてください。',
                  spots: [
                    TutorialSpot(
                      _tutorialMode,
                      'grammar',
                      '修行モード',
                      fraction: _tutorialModeFraction(true),
                    ),
                  ],
                ) !=
                null &&
            mounted) {
          await _changeMode(TrainingMode.grammar);
          if (mounted &&
              mode == TrainingMode.grammar &&
              await tour.point(
                    context,
                    title: 'まずは「be動詞」から',
                    description:
                        '「学年をえらぶ」で中学1〜3年生の文法を切り替えられます。今回は中学1年生文法の「be動詞」を開いて、1問だけ試してみましょう。',
                    spots: [TutorialSpot(_tutorialGrammar, 'be', 'be動詞')],
                  ) !=
                  null &&
              mounted) {
            final selected = await Navigator.of(context).push<GrammarStudyChoice>(
              MaterialPageRoute(
                builder: (_) => TutorialWhenReady(
                  onReady: (ctx) async {
                    final result = await tour.point(
                      ctx,
                      title: '文法メモを確認して、練習へ',
                      description:
                          '使い方や文の形を確認できます。通常は10問のセットです。今回は最初の1問を解き、2問目で途中終了する操作を試します。',
                      spots: [
                        TutorialSpot(_tutorialStart, 'start', '10問で修行する'),
                      ],
                    );
                    if (ctx.mounted) {
                      Navigator.pop(
                        ctx,
                        result == null
                            ? null
                            : (questions: unit.questions, review: false),
                      );
                    }
                  },
                  child: GrammarLessonPage(
                    unit: unit,
                    data: data,
                    startButtonKey: _tutorialStart,
                  ),
                ),
              ),
            );
            if (selected != null && mounted && !tour.canceled) {
              final trainingRoute = MaterialPageRoute<void>(
                builder: (_) => TrainingPage(
                  questions: unit.questions,
                  tutorial: tour,
                  onRate: (q, success) => _rate(q, success, normal: false),
                  onTime: (elapsed) =>
                      _update((current) => current.addTime(elapsed)),
                  growth: () => GrowthProgress(data),
                ),
              );
              await Navigator.of(context).push<void>(trainingRoute);
              await trainingRoute.completed;
            }
          }
        }
      }
      if (GrowthProgress(data).xp == beforeXp) tour.canceled = true;
      if (mounted && !tour.canceled) {
        if (_homeScroll.hasClients) _homeScroll.jumpTo(0);
        await tour.point(
          context,
          title: '1問の練習も、成長につながります',
          description:
              '今の練習で${GrowthProgress(data).xp - beforeXp} EXPがたまりました。「できた」は10 EXP、「まだ難しい」でも5 EXP。どちらのモードでも共通の経験値がたまり、レベルと役職（ランク）が成長します。',
          spots: [TutorialSpot(_tutorialGrowth, 'growth', '共通レベル・役職')],
          nextLabel: '次へ',
        );
      }
      if (mounted && !tour.canceled) {
        final weak = selectQuestions(allQuestions, data, reviewOnly: true);
        await tour.point(
          context,
          title: '復習は、ここから',
          description:
              '「まだ難しい」を選んだ問題は、この「復習」から練習できます。初期設定では「できた」が累計5回になるまで復習対象に残ります。${weak.isEmpty ? '今は復習対象がないため、ボタンはお休み中です。' : '今は${weak.length}問が復習対象になっています。'}',
          spots: [TutorialSpot(_tutorialReview, 'review', '復習')],
          nextLabel: '確認しました',
        );
      }
      if (mounted && !tour.canceled) {
        if (await tour.point(
                  context,
                  title: '続けた記録を見てみましょう',
                  description: '下の「学習記録」をタップすると、取り組んだ問題数や学習時間を振り返れます。',
                  spots: [TutorialSpot(_tutorialHistory, 'history', '学習記録')],
                ) !=
                null &&
            mounted) {
          setState(() => page = 1);
          await tour.point(
            context,
            title: '学習の積み重ねが見える画面',
            description:
                'グラフで問題数と学習時間の推移を確認できます。日別・月別の切り替えや、今日・今週・今月の実績の確認・共有もできます。下へ進むと、獲得したバッジも見られます。',
            spots: [TutorialSpot(_tutorialChart, 'chart', '学習の推移')],
            nextLabel: '次へ',
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _tutorialRunning = false;
          page = 0;
        });
        if (!tour.canceled && widget.monetization != null) {
          await InteractiveTutorial().point(
            context,
            title: 'チケットと有料プランは、ここから',
            description:
                '枠で囲んだヘッダーのアイコンで、通常チケット（1日3セットの無料枠）と追加チケットを確認できます。通常チケットは毎日午前0時に回復し、先に使われます。なくなったら追加チケット1枚で1セット練習できます。復習もチケットを使います。有料の無制限プランでは、通常練習も復習も回数制限なく、広告なしで利用できます。アイコンからプランの購入・復元もできます。',
            spots: [TutorialSpot(_tutorialTickets, 'tickets', 'チケット・有料プラン')],
            nextLabel: '次へ',
          );
        }
        if (mounted) {
          final choice = await InteractiveTutorial().point(
            context,
            title: 'いつでも「使い方」で確認できます',
            description:
                '練習の進め方は、枠で囲んだ「使い方」からいつでも確認できます。「実際の画面で操作を試す」から、操作ガイドをもう一度体験できます。',
            spots: [TutorialSpot(_tutorialGuide, 'guide', '使い方')],
            nextLabel: 'わかりました',
          );
          if (choice == 'guide' && mounted) await showUsageGuide(context);
        }
      }
    }
  }

  Future<void> _openReminderSettings() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ReminderSettingsPage(
        manager:
            widget.reminders ??
            ReminderManager(
              store: LocalReminderStore(),
              backend: LocalReminderBackend(),
            ),
      ),
    ),
  );

  Future<void> _rate(
    Question question,
    bool success, {
    required bool normal,
  }) async {
    final now = DateTime.now();
    await _update((current) => current.rate(question.id, success, now));
    if (normal) unawaited(widget.analytics?.answered(now));
  }

  String? _lastSkillCategory;

  Future<QuestReceipt> _claimQuest(String key) async {
    late QuestReceipt receipt;
    await _update((current) {
      final next = claimQuestReward(
        current,
        key,
        DateTime.now(),
        ticketsEnabled: _limited,
      );
      final before = GrowthProgress(current), after = GrowthProgress(next);
      final rewarded = _withLevelReward(current, next);
      receipt = QuestReceipt(
        after.xp - before.xp,
        before,
        after,
        tickets: rewarded.allowance.tickets - current.allowance.tickets,
      );
      return next;
    });
    return receipt;
  }

  Future<void> _openQuests() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => QuestPage(
        data: () => data,
        onClaim: _claimQuest,
        ticketsEnabled: _limited,
      ),
    ),
  );

  Future<void> _changeMode(TrainingMode selected) async {
    if (modeSaving || selected == mode) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => modeSaving = true);
    try {
      await widget.modeStore?.save(selected);
      if (mounted) {
        setState(() => mode = selected);
        if (_homeScroll.hasClients) _homeScroll.jumpTo(0);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('学習モードを保存できませんでした。もう一度お試しください。')),
        );
      }
    } finally {
      if (mounted) setState(() => modeSaving = false);
    }
  }

  Future<void> _openGrammar(GrammarUnit unit) async {
    final selected = await Navigator.of(context).push<GrammarStudyChoice>(
      MaterialPageRoute(
        builder: (_) => GrammarLessonPage(unit: unit, data: data),
      ),
    );
    if (selected != null && mounted) {
      await _start(only: selected.questions, review: selected.review);
    }
  }

  Future<void> _openSkills({String? initialCategory}) async {
    if (data.interests.isEmpty && !await _editInterests()) return;
    if (!mounted) return;
    final choice = await Navigator.of(context).push<SkillChoice>(
      MaterialPageRoute(
        builder: (_) => SkillTreePage(
          catalog: catalog,
          data: data,
          initialCategory: initialCategory ?? _lastSkillCategory,
          onCategoryChanged: (id) => _lastSkillCategory = id,
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final skill = interestSkills(catalog, data)
        .where((s) => s.categoryId == choice.scene && s.level == choice.level)
        .firstOrNull;
    if (skill == null ||
        !skill.unlocked ||
        (choice.challenge && !skill.challengeUnlocked)) {
      return;
    }
    _lastSkillCategory = choice.scene;
    await _start(
      only: selectStageQuestions(catalog, choice.scene, choice.level),
      challenge: choice.challenge ? choice : null,
    );
    if (choice.challenge && mounted) {
      await _openSkills(initialCategory: choice.scene);
    }
  }

  Future<bool> _editInterests() async =>
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => InterestPickerPage(
            catalog: catalog,
            selected: data.interests,
            onSave: (selected) =>
                _update((current) => current.withInterests(selected)),
          ),
        ),
      ) ??
      false;

  Future<void> _start({
    required List<Question> only,
    SkillChoice? challenge,
    bool review = false,
  }) async {
    if (only.isEmpty || _startingPractice) return;
    _startingPractice = true;
    try {
      if (challenge == null && _limited) {
        final now = DateTime.now();
        var allowed = false;
        try {
          await _update((current) {
            final next = current.allowance.startSet(now);
            allowed = next != null;
            return next == null ? current : current.withAllowance(next);
          });
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('練習回数を保存できませんでした。')));
          }
          return;
        }
        if (!mounted) return;
        if (!allowed) {
          if (await _showPracticePlan(exhausted: true) == true) {
            await _watchPracticeReward();
          }
          return;
        }
      }
      await _runPractice(only: only, challenge: challenge, review: review);
    } finally {
      _startingPractice = false;
    }
  }

  Future<void> _runPractice({
    required List<Question> only,
    required SkillChoice? challenge,
    required bool review,
  }) async {
    final candidates = only;
    final labels = stageLabels(catalog, progress: data);
    final normal = challenge == null && !review;
    if (normal) unawaited(widget.analytics?.startedSet(DateTime.now()));
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => TrainingPage(
          returnCompletion: true,
          studyData: () => data,
          reviewGoal: review ? data.reviewGoal : null,
          reviewProgress: review
              ? (question) => data.entries[question.id]
              : null,
          questions: createSession(
            candidates,
            limit: challenge == null ? 10 : 5,
          ),
          onRate: (question, success) =>
              _rate(question, success, normal: normal),
          levelLabelForQuestion: (question) =>
              labels[question.id] ?? question.level,
          finalChallenge:
              challenge != null && challenge.level == courseLevels.last.key,
          challengeLabel: challenge == null
              ? null
              : '${interestLabel(challenge.scene)}・${courseLevel(challenge.level, category: challenge.scene).label}',
          onChallengeRate: challenge == null
              ? null
              : (question, success, finalScore, total) => _update((current) {
                  final rated = current.rate(
                    question.id,
                    success,
                    DateTime.now(),
                  );
                  return finalScore == null
                      ? rated
                      : rated.finishChallenge(
                          challenge.scene,
                          challenge.level,
                          finalScore,
                          total,
                          DateTime.now(),
                        );
                }),
          growth: () => GrowthProgress(data),
          onTime: (elapsed) => _update((current) => current.addTime(elapsed)),
          completionBanner: widget.monetization == null
              ? null
              : ListenableBuilder(
                  listenable: widget.monetization!,
                  builder: (_, _) => _practiceBanner('completion'),
                ),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => page = 0);
    if (completed == true && challenge == null) _scheduleStoreReview();
  }

  Future<bool?> _showPracticePlan({bool exhausted = false}) => showDialog<bool>(
    context: context,
    builder: (_) => ListenableBuilder(
      listenable: widget.monetization!,
      builder: (dialogContext, _) {
        final monetization = widget.monetization!;
        final canWatch = data.allowance.canWatchAd(DateTime.now());
        return AlertDialog(
          title: Text(exhausted ? '今日の通常練習はここまで' : '練習枠と有料プラン'),
          scrollable: true,
          content: Text(
            '${monetization.unlimited ? '' : '今日の無料枠 ${data.allowance.remaining(DateTime.now())}/${PracticeAllowance.dailySets}セット・追加チケット ${data.allowance.tickets}枚\n\n'}'
            '${monetization.unlimited ? '無制限プランをご利用中です。' : '無料版は通常練習・復習を合わせて1日3セット。通常チケット（無料枠）を先に使い、なくなったら追加チケット1枚でもう1セット練習できます。無料枠は午前0時に回復します。'}'
            '\n\n有料プランでは、通常練習を回数無制限・広告なしで利用できます。'
            '${monetization.purchasePriceNote.isEmpty ? '' : '\n\n${monetization.purchasePriceNote}'}'
            '${monetization.unlimited || monetization.product != null ? '' : '\n現在、このビルドから有料プランは購入できません。'}'
            '${exhausted ? '\n\n復習や挑戦問題には引き続き取り組めます。' : ''}'
            '${monetization.purchaseMessage == null ? '' : '\n\n${monetization.purchaseMessage}'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('閉じる'),
            ),
            if (exhausted && canWatch && !monetization.unlimited)
              TextButton(
                onPressed: monetization.adsReady
                    ? () => Navigator.pop(dialogContext, true)
                    : null,
                child: const Text('広告を見て追加チケットを1枚もらう'),
              ),
            if (exhausted && !monetization.unlimited)
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _showPracticePlan();
                },
                child: const Text('有料プランを見る'),
              ),
            if (!exhausted && !monetization.unlimited)
              if (monetization.product != null)
                FilledButton(
                  onPressed: monetization.buy,
                  child: Text('無制限・広告なし（${monetization.purchasePrice}）'),
                ),
            if (!exhausted &&
                monetization.storeReady &&
                !monetization.unlimited)
              TextButton(
                onPressed: monetization.restore,
                child: const Text('購入を復元'),
              ),
          ],
        );
      },
    ),
  );

  Future<void> _watchPracticeReward() async {
    final now = DateTime.now();
    if (!_limited || !data.allowance.canWatchAd(now)) return;
    final monetization = widget.monetization!;
    final earned = await monetization.watchReward();
    if (!mounted) return;
    String message = '広告を視聴できなかったか、視聴条件に達しませんでした。';
    if (earned) {
      try {
        await _update((current) {
          final next = current.allowance.grantAdTicket(now);
          if (identical(next, current.allowance)) return current;
          message = '追加練習チケットを1枚獲得しました。';
          return current.withAllowance(next);
        });
      } catch (_) {
        message = '追加練習チケットを保存できませんでした。';
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (failed) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 40),
                const SizedBox(height: 20),
                const Text('データを読み込めませんでした', style: TextStyle(fontSize: 22)),
                const SizedBox(height: 12),
                const Text('記録は上書きしていません。アプリを再起動するか、もう一度お試しください。'),
                const SizedBox(height: 20),
                FilledButton(onPressed: _load, child: const Text('再試行')),
              ],
            ),
          ),
        ),
      );
    }
    final compactToolbar =
        widget.monetization != null &&
        (MediaQuery.sizeOf(context).width < 370 ||
            MediaQuery.textScalerOf(context).scale(14) > 20);
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          label: 'インクリ',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/brand/inkuri-icon.png',
                  width: 40,
                  height: 40,
                  excludeFromSemantics: true,
                ),
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'インクリ',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: '学習リマインダー',
            icon: const Icon(Icons.notifications_none_outlined),
            onPressed: _openReminderSettings,
          ),
          if (widget.monetization != null)
            KeyedSubtree(key: _tutorialTickets, child: _practicePlanButton()),
          if (compactToolbar)
            IconButton(
              key: _tutorialGuide,
              tooltip: '使い方',
              onPressed: _openUsageGuide,
              icon: const Icon(Icons.menu_book_outlined),
            )
          else
            TextButton(
              key: _tutorialGuide,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: _openUsageGuide,
              child: const Text('使い方'),
            ),
          IconButton(
            tooltip: 'このアプリについて',
            onPressed: _showAppInfo,
            icon: const Icon(Icons.info_outline),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                if (page == 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                    child: TrainingModeSwitch(
                      key: _tutorialMode,
                      forceSegmented: _tutorialRunning,
                      mode: mode,
                      onChanged: modeSaving ? null : _changeMode,
                    ),
                  ),
                if (page == 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                    child: HomeLearningActions(
                      reviewKey: _tutorialReview,
                      weakCount: selectQuestions(
                        allQuestions,
                        data,
                        reviewOnly: true,
                      ).length,
                      claimable:
                          learningQuests(
                                data,
                                DateTime.now(),
                                ticketsEnabled: _limited,
                              )
                              .where(
                                (q) =>
                                    q.claimable &&
                                    !q.ticketBalanceFull(
                                      data,
                                      ticketsEnabled: _limited,
                                    ),
                              )
                              .length,
                      onReview:
                          selectQuestions(
                            allQuestions,
                            data,
                            reviewOnly: true,
                          ).isEmpty
                          ? null
                          : () => _start(
                              review: true,
                              only: selectQuestions(
                                allQuestions,
                                data,
                                reviewOnly: true,
                              ),
                            ),
                      onQuests: _openQuests,
                    ),
                  ),
                Expanded(
                  child: ListView(
                    controller: page == 0 ? _homeScroll : null,
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                    children: page == 0 ? _home() : _history(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: page,
        onDestinationSelected: (value) => setState(() => page = value),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            label: 'トレーニング',
          ),
          NavigationDestination(
            key: _tutorialHistory,
            icon: const Icon(Icons.insights_outlined),
            label: '学習記録',
          ),
        ],
      ),
    );
  }

  List<Widget> _home() {
    return [
      if (!_tutorialRunning && TrainingModeSwitch.compact(context))
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            '冒険：好きなテーマで英作文。修行：文法を単元ごとに練習。'
            '\n'
            'どちらのモードで学んでも、EXPは共通レベルに加算されます。',
          ),
        ),
      if (_showUpdateNotice && !_tutorialRunning) ...[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '新しいバージョンがあります',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Text('Google Playからインクリを更新できます。'),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () =>
                            setState(() => _showUpdateNotice = false),
                        child: const Text('あとで'),
                      ),
                      FilledButton(
                        onPressed: _openPlayUpdate,
                        child: const Text('更新する'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
      GrowthCard(
        key: _tutorialGrowth,
        data: data,
        onSkills: _openSkills,
        showAdventureActions: mode == TrainingMode.adventure,
      ),
      if (mode == TrainingMode.grammar) ...[
        const SizedBox(height: 20),
        GrammarPanel(
          catalog: grammar,
          data: data,
          onOpen: _openGrammar,
          guidedUnitId: _tutorialRunning ? 'be' : null,
          guidedUnitKey: _tutorialGrammar,
        ),
      ],
      if (mode == TrainingMode.adventure) ...[
        const SizedBox(height: 16),
        CategoryLevels(
          catalog: catalog,
          data: data,
          onEdit: _editInterests,
          onOpen: (category) => _openSkills(initialCategory: category),
        ),
      ],
      _practiceBanner('home'),
    ];
  }

  Widget _practicePlanButton() {
    final remaining = data.allowance.remaining(DateTime.now());
    final tickets = data.allowance.tickets;
    const total = PracticeAllowance.dailySets;
    return Tooltip(
      message: _limited
          ? '無料枠 $remaining/$total・追加チケット $tickets枚・有料プラン'
          : '無制限プラン・広告なし',
      child: TextButton(
        onPressed: _showPracticePlan,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          minimumSize: const Size(48, 48),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 34,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: _limited ? remaining / total : 1,
                    strokeWidth: 2.5,
                    color: Colors.white,
                    backgroundColor: Colors.white38,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(5),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _limited ? '$remaining/$total' : '∞',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_limited) ...[
              const SizedBox(width: 4),
              const Icon(Icons.confirmation_number_outlined, size: 15),
              const SizedBox(width: 2),
              SizedBox(
                width: 12,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('$tickets'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _practiceBanner(String placement) {
    final monetization = widget.monetization;
    if (monetization == null ||
        monetization.unlimited ||
        !monetization.adsReady) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      key: ValueKey(placement),
      builder: (_, constraints) => constraints.maxWidth < 280
          ? const SizedBox.shrink()
          : PracticeBanner(
              key: ValueKey(constraints.maxWidth.floor()),
              adUnitId: monetization.bannerId(placement),
              width: constraints.maxWidth.floor(),
            ),
    );
  }

  Future<void> _showAppInfo() {
    final analytics = widget.analytics;
    var savingAnalytics = false;
    return showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, refresh) => AlertDialog(
          title: const Text('インクリ'),
          scrollable: true,
          content: ListBody(
            children: [
              const Text('0.16.3'),
              const SizedBox(height: 12),
              const Text(
                '日本語から英語を作る練習アプリです。\n\n登録不要。問題とAI音声はオフラインで使えます。\n\n記録はこの端末に保存されます。アプリの削除や機種変更で失われることがあります。\n\n英文は解答例です。ほかの表現でも伝えられます。',
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('復習設定'),
                subtitle: Text('「できた」${data.reviewGoal}回で復習完了'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await _editReviewGoal();
                  if (dialogContext.mounted) refresh(() {});
                },
              ),
              if (widget.monetization?.adPrivacyOptionsRequired == true)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('広告のプライバシー設定'),
                  onTap: widget.monetization!.showAdPrivacyOptions,
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('プライバシーポリシー'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _openLegalPage(
                  dialogContext,
                  'https://encre.wisemap.biz/privacy-policy-2/',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('利用規約'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _openLegalPage(
                  dialogContext,
                  'https://encre.wisemap.biz/terms/',
                ),
              ),
              if (analytics != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('学習状況の計測に協力する'),
                  subtitle: const Text(
                    'アプリの改善のため、学習した日や練習量に関するデータを送信します。いつでもオフにできます。',
                  ),
                  value: analytics.enabled,
                  onChanged: savingAnalytics
                      ? null
                      : (enabled) async {
                          refresh(() => savingAnalytics = true);
                          await _changeAnalytics(enabled);
                          if (dialogContext.mounted) {
                            refresh(() => savingAnalytics = false);
                          }
                        },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('閉じる'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeAnalytics(bool enabled) async {
    try {
      await widget.analytics!.changeEnabled(enabled);
      if (mounted) setState(() {});
    } catch (_) {
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('計測設定を変更できませんでした。')));
    }
  }

  Future<void> _openLegalPage(BuildContext dialogContext, String url) async {
    try {
      if (await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } on PlatformException {
      // Show the same fallback when the operating system cannot open the link.
    }
    if (!dialogContext.mounted) return;
    await showDialog<void>(
      context: dialogContext,
      builder: (context) => AlertDialog(
        title: const Text('ページを開けませんでした'),
        content: SelectableText(url),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Future<void> _editReviewGoal() async {
    final form = GlobalKey<FormState>();
    var value = '${data.reviewGoal}';
    final goal = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('復習設定'),
        scrollable: true,
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('復習対象になってから「できた」がこの回数に達すると、復習が完了します。初期値は5回です。'),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: value,
                decoration: const InputDecoration(
                  labelText: '復習完了に必要な回数',
                  suffixText: '回',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (text) => value = text,
                validator: (text) => (int.tryParse(text ?? '') ?? 0) > 0
                    ? null
                    : '1以上の整数を入力してください。',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(ctx, int.parse(value));
              }
            },
            child: const Text('保存する'),
          ),
        ],
      ),
    );
    if (goal == null || !mounted) return;
    try {
      await _update((current) => current.withReviewGoal(goal));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('復習設定を保存できませんでした。再度お試しください。')),
        );
      }
    }
  }

  List<Widget> _history() {
    return [
      LearningDashboard(
        data: data,
        catalog: allQuestions,
        now: DateTime.now(),
        tutorialChartKey: _tutorialChart,
      ),
      _practiceBanner('history'),
      const SizedBox(height: 24),
      OutlinedButton(
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('学習記録を削除しますか？'),
              content: const Text(
                '学習回数・苦手問題・学習時間・起動日・獲得バッジ・経験値・レベル・スキル・挑戦の合格記録・クエスト報酬をすべて削除します。この操作は元に戻せません。',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('キャンセル'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('削除する'),
                ),
              ],
            ),
          );
          if (confirmed != true || !mounted) return;
          try {
            await _update(
              (current) => LearningData()
                  .withInterests(current.interests)
                  .withReviewGoal(current.reviewGoal)
                  .withAllowance(current.allowance),
            );
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('削除できませんでした。再度お試しください。')),
              );
            }
          }
        },
        child: const Text('学習記録をリセット'),
      ),
    ];
  }
}

class TrainingPage extends StatefulWidget {
  const TrainingPage({
    super.key,
    required this.questions,
    required this.onRate,
    this.speechEngine,
    this.returnCompletion = false,
    this.onTime,
    this.now,
    this.growth,
    this.challengeLabel,
    this.onChallengeRate,
    this.levelLabelForQuestion,
    this.finalChallenge = false,
    this.completionBanner,
    this.tutorial,
    this.reviewGoal,
    this.reviewProgress,
    this.studyData,
  });
  final SpeechEngine? speechEngine;
  final bool returnCompletion;
  final List<Question> questions;
  final Future<void> Function(Question, bool) onRate;
  final Future<void> Function(Map<String, int>)? onTime;
  final DateTime Function()? now;
  final GrowthProgress Function()? growth;
  final String? challengeLabel;
  final String Function(Question)? levelLabelForQuestion;
  final bool finalChallenge;
  final Widget? completionBanner;
  final InteractiveTutorial? tutorial;
  final int? reviewGoal;
  final ProgressEntry? Function(Question)? reviewProgress;
  final LearningData Function()? studyData;
  final Future<void> Function(Question, bool, int?, int)? onChallengeRate;
  @override
  State<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage>
    with WidgetsBindingObserver {
  late final SpeechController speech;
  int index = 0, successes = 0;
  bool revealed = false, saving = false, leaving = false;
  bool _hasExited = false;
  bool get complete => index == widget.questions.length;
  final studyClock = StudyClock();
  Timer? _timer;
  Future<void>? _flushing;
  bool _foreground = true, _timeSaveFailed = false;
  int _earnedXp = 0;
  late final int _startLevel;
  String? _levelNotice;
  final _tutorialReveal = GlobalKey();
  final _tutorialAnswer = GlobalKey();
  final _tutorialDone = GlobalKey();
  final _tutorialHard = GlobalKey();
  final _tutorialExit = GlobalKey();
  DateTime get _now => (widget.now ?? DateTime.now)();

  Future<void> _flushTime() {
    if (widget.onTime == null) return Future.value();
    return _flushing ??= _saveTime().whenComplete(() => _flushing = null);
  }

  Future<void> _saveTime() async {
    while (studyClock.pending.isNotEmpty) {
      final batch = studyClock.snapshot();
      await widget.onTime!(batch);
      studyClock.acknowledge(batch);
    }
    if (mounted && _timeSaveFailed) setState(() => _timeSaveFailed = false);
  }

  Future<void> _checkpoint() async {
    studyClock.checkpoint(_now);
    try {
      await _flushTime();
    } catch (_) {
      if (mounted) setState(() => _timeSaveFailed = true);
    }
  }

  @override
  void initState() {
    super.initState();
    _startLevel = widget.growth?.call().level ?? 1;
    speech = SpeechController(widget.speechEngine ?? BundledSpeechEngine());
    speech.addListener(_speechChanged);
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.inactive &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.hidden;
    if (_foreground) studyClock.resume(_now);
    if (widget.onTime != null) {
      _timer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => unawaited(_checkpoint()),
      );
    }
    if (widget.tutorial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_practiceTutorial());
      });
    }
  }

  Future<void> _practiceTutorial() async {
    final tour = widget.tutorial!;
    final revealedByUser = await tour.point(
      context,
      title: '日本語を見て、英文を考えましょう',
      description:
          '目標は2秒以内に英文を考え始めること。声に出しても、頭の中で考えても大丈夫です。考えたら「答えを表示」をタップしてください。',
      spots: [TutorialSpot(_tutorialReveal, 'reveal', '答えを表示')],
      alignment: .8,
    );
    if (!mounted) return;
    if (revealedByUser != null) {
      setState(() => revealed = true);
      await tour.point(
        context,
        title: '解答例と比べてみましょう',
        description:
            '答えられなかった英文は、解答を見ずに言えるまで3〜5回を目安に繰り返し、口になじませましょう。音声ボタンで読み方も確認できます。',
        spots: [TutorialSpot(_tutorialAnswer, 'answer', '解答例')],
        nextLabel: '自己評価へ',
      );
      while (index == 0 && !tour.canceled) {
        if (!mounted) return;
        final choice = await tour.point(
          context,
          title: '自分で、できたかを選びます',
          description:
              'すぐに英文を作れたら「できた」。答えられなかったり、考えるのに5秒以上かかったら「まだ難しい」を選びます。今の手ごたえに合う方をタップしてください。選んだ1問は学習記録に残ります。',
          spots: [
            TutorialSpot(_tutorialDone, 'done', 'できた'),
            TutorialSpot(_tutorialHard, 'hard', 'まだ難しい'),
          ],
          alignment: .45,
        );
        if (!mounted) return;
        if (choice == 'done' || choice == 'hard') {
          await _answer(choice == 'done');
        } else {
          tour.canceled = true;
        }
      }
      while (!tour.canceled) {
        if (!mounted) return;
        if (await tour.point(
                  context,
                  title: '2問目は、途中で終えてみましょう',
                  description:
                      '左上の「×」を押すと終了の確認が開きます。「終了する」を選んでみてください。1問目の学習記録とEXPは、そのまま残ります。',
                  spots: [TutorialSpot(_tutorialExit, 'exit', '学習を終了')],
                ) ==
                null ||
            !mounted) {
          break;
        }
        await _exit();
        if (_hasExited) return;
      }
    }
    if (mounted && tour.canceled) {
      studyClock.pause(_now);
      try {
        await _flushTime();
        if (mounted) Navigator.pop(context);
      } catch (_) {
        if (mounted) setState(() => _timeSaveFailed = true);
      }
    }
  }

  void _speechChanged() {
    if (!mounted) return;
    setState(() {});
    final error = speech.error;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      unawaited(speech.stop());
      studyClock.pause(_now);
      unawaited(_checkpoint());
    } else if (!complete && !saving && !leaving) {
      studyClock.resume(_now);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    studyClock.pause(_now);
    unawaited(_flushTime().catchError((Object _) {}));
    speech.removeListener(_speechChanged);
    speech.dispose();
    super.dispose();
  }

  Future<void> _exit() async {
    if (saving || leaving || _hasExited) return;
    leaving = true;
    studyClock.pause(_now);
    await speech.stop();
    if (!mounted) return;
    final guidedExit =
        widget.tutorial != null &&
        !widget.tutorial!.canceled &&
        index == 1 &&
        !complete;
    final leave =
        complete ||
        await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('学習を終了しますか？'),
                scrollable: true,
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (guidedExit) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE4EDE7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '操作ガイド：今回は「終了する」を選びます',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: teal,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '1問目の記録とEXPを残して、次の説明へ進みましょう。普段の学習で問題に戻りたいときは「続ける」を選べます。',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      widget.challengeLabel == null
                          ? '自己評価した問題の記録は保存済みです。残りの出題は次回引き継ぎません。'
                          : '途中までの学習記録は残りますが、挑戦の合否は保存されません。再挑戦は最初から始まります。',
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('続ける'),
                  ),
                  if (guidedExit)
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('終了する'),
                    )
                  else
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('終了する'),
                    ),
                ],
              ),
            ) ==
            true;
    leaving = false;
    if (leave && mounted) {
      try {
        await _flushTime();
        if (mounted) {
          _hasExited = true;
          if (widget.returnCompletion) {
            Navigator.pop(context, complete);
          } else {
            Navigator.pop(context);
          }
        }
      } catch (_) {
        if (mounted) {
          setState(() => _timeSaveFailed = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('学習時間を保存できませんでした。もう一度終了をお試しください。')),
          );
        }
      }
    }
    if (mounted && !complete && _foreground && !_hasExited) {
      studyClock.resume(_now);
    }
  }

  Future<void> _answer(bool success) async {
    if (saving || !revealed || complete) return;
    setState(() => saving = true);
    studyClock.pause(_now);
    try {
      await speech.stop();
      if (!mounted) return;
      await _flushTime();
      final before = widget.growth?.call();
      if (widget.onChallengeRate != null) {
        await widget.onChallengeRate!(
          widget.questions[index],
          success,
          index == widget.questions.length - 1
              ? successes + (success ? 1 : 0)
              : null,
          widget.questions.length,
        );
      } else {
        await widget.onRate(widget.questions[index], success);
      }
      if (!mounted) return;
      final after = widget.growth?.call();
      setState(() {
        if (before != null && after != null) {
          _earnedXp += after.xp - before.xp;
          _levelNotice = after.level > before.level
              ? 'レベルアップ！ Lv. ${before.level} → ${after.level}'
              : null;
        }
        index++;
        if (success) successes++;
        revealed = false;
        saving = false;
      });
      if (!complete && _foreground) studyClock.resume(_now);
    } catch (_) {
      if (!mounted) return;
      setState(() => saving = false);
      if (_foreground) studyClock.resume(_now);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('記録を保存できませんでした。もう一度、自己評価を選んでください。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: complete && !saving,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _exit();
    },
    child: Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          key: _tutorialExit,
          tooltip: '学習を終了',
          onPressed: saving ? null : _exit,
          icon: const Icon(Icons.close),
        ),
        title: Text(
          complete ? '学習完了' : '${index + 1} / ${widget.questions.length}',
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: complete ? _result() : _question(),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _result() {
    final shareData = widget.studyData?.call();
    final shareNow = _now;
    final todayQuestions = shareData?.days[dayKey(shareNow)]?.questions ?? 0;
    final showDailyShare = shareData != null && todayQuestions >= 30;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.check_circle_outline, size: 64, color: teal),
        const SizedBox(height: 24),
        Text(
          widget.challengeLabel == null
              ? '今日の一歩、完了。'
              : successes >= eightyPercent(widget.questions.length)
              ? '挑戦合格！'
              : '次の挑戦へ、もう一歩。',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 16),
        Text(
          '${widget.questions.length}問に取り組みました。',
          textAlign: TextAlign.center,
        ),
        if (widget.challengeLabel != null) ...[
          const SizedBox(height: 16),
          Text(
            '今回の達成率 ${(successes * 100 / widget.questions.length).round()}%（合格基準80%以上）',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            successes >= eightyPercent(widget.questions.length)
                ? (widget.finalChallenge
                      ? 'この分野の最終チャレンジを達成しました！'
                      : '次の難易度が解放されました！')
                : '合格は今回の回答だけで判定します。何度でも再挑戦できます。',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            '達成率は「できた」の自己評価に基づきます。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
        ],
        if (widget.growth != null) ...[
          const SizedBox(height: 24),
          _surface([
            Text(
              widget.questions.any((q) => q.isGrammar)
                  ? '今回の修行の成果'
                  : '今回の冒険の成果',
              style: const TextStyle(color: teal, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              '獲得経験値  $_earnedXp EXP',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('Lv. $_startLevel → Lv. ${widget.growth!.call().level}'),
            if (widget.growth!.call().level > _startLevel)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'レベルアップ！新しい一歩が力になりました。',
                  style: TextStyle(color: teal, fontWeight: FontWeight.w700),
                ),
              ),
          ]),
        ],
        const SizedBox(height: 32),
        _surface([
          Text('まだ難しい  ${widget.questions.length - successes}問'),
          const SizedBox(height: 12),
          const Text(
            '「まだ難しい」の問題は学習記録に残ります。あとから復習できます。',
            style: TextStyle(height: 1.6),
          ),
        ]),
        const SizedBox(height: 28),
        if (showDailyShare) ...[
          TodayShareCard(
            questions: todayQuestions,
            onShare: () =>
                showTodayShare(context, data: shareData, now: shareNow),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: teal,
              side: const BorderSide(color: teal),
            ),
            onPressed: _exit,
            child: Text(widget.challengeLabel == null ? 'ホームに戻る' : 'スキルツリーに戻る'),
          ),
        ] else
          FilledButton(
            onPressed: _exit,
            child: Text(widget.challengeLabel == null ? 'ホームに戻る' : 'スキルツリーに戻る'),
          ),
        if (widget.questions.length == 10 && widget.challengeLabel == null) ...[
          ?widget.completionBanner,
        ],
      ],
    );
  }

  Widget _question() {
    final q = widget.questions[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.challengeLabel != null) ...[
          Text(
            '${widget.challengeLabel}の挑戦問題',
            style: const TextStyle(color: teal, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '今回${widget.questions.length}問のうち${eightyPercent(widget.questions.length)}問以上「できた」で合格。解答を見て自己評価してください。',
            style: const TextStyle(fontSize: 12, height: 1.7),
          ),
          const SizedBox(height: 12),
        ],
        LinearProgressIndicator(
          value: index / widget.questions.length,
          semanticsLabel: '今回の学習進捗',
        ),
        if (widget.growth != null) ...[
          const SizedBox(height: 12),
          Text(
            'Lv. ${widget.growth!.call().level}  ·  累計 ${widget.growth!.call().xp} EXP',
            style: const TextStyle(color: teal, fontWeight: FontWeight.w700),
          ),
          if (_levelNotice != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _levelNotice!,
                  style: const TextStyle(
                    color: teal,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
        ],
        const SizedBox(height: 24),
        if (_timeSaveFailed)
          const Text(
            '学習時間を保存できませんでした。終了時に再試行します。',
            style: TextStyle(color: Colors.deepOrange),
          ),
        Text(
          q.isGrammar
              ? '修行モード  /  ${q.topic}'
              : '${widget.levelLabelForQuestion?.call(q) ?? q.level}  /  ${q.scene}${q.topic.isEmpty ? '' : '  /  ${q.topic}'}',
          style: const TextStyle(color: teal, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        const Text('次の日本語を、英語にしてみましょう。', style: TextStyle(fontSize: 13)),
        if (widget.reviewGoal case final goal?) ...[
          const SizedBox(height: 16),
          Text(
            '${widget.reviewProgress?.call(q)?.reviewSuccesses ?? 0} / $goal 回 できた',
            style: const TextStyle(color: teal, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'この問題で「できた」を累計$goal回選ぶと、復習対象から外れます。\n復習の設定回数（初期値5回）は、TOPのiアイコンから変更できます。',
            style: const TextStyle(fontSize: 13, height: 1.6),
          ),
        ],
        const SizedBox(height: 20),
        _surface([
          const Text(
            'JAPANESE',
            style: TextStyle(fontSize: 11, letterSpacing: 2, color: teal),
          ),
          const SizedBox(height: 24),
          Text(
            q.japanese,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(height: 1.6),
          ),
          const SizedBox(height: 24),
          const Text('声に出しても、頭の中でも。', style: TextStyle(fontSize: 12)),
        ]),
        const SizedBox(height: 24),
        if (!revealed) ...[
          FilledButton(
            key: _tutorialReveal,
            onPressed: () => setState(() => revealed = true),
            child: const Text('答えを表示'),
          ),
          const SizedBox(height: 12),
          const Text(
            '自分のペースで考えてから、答えを確認しましょう。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
        ] else ...[
          Semantics(
            liveRegion: true,
            child: _surface([
              for (var i = 0; i < q.answers.length; i++) ...[
                if (i > 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Divider(height: 1),
                  ),
                Text(
                  i == 0 ? '解答例' : '別の言い方 $i',
                  style: const TextStyle(
                    color: teal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  q.answers[i].text,
                  key: i == 0 ? _tutorialAnswer : null,
                  style: TextStyle(
                    fontSize: i == 0 ? 25 : 21,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 12),
                AnswerAudioControls(
                  speech: speech,
                  text: q.answers[i].text,
                  enabled: !saving,
                  showSpeed: i == 0 || speech.activeText == q.answers[i].text,
                ),
                if (q.answers[i].explanation.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'ニュアンス・使い方',
                    style: TextStyle(
                      fontSize: 12,
                      color: teal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    q.answers[i].explanation,
                    style: const TextStyle(height: 1.7),
                  ),
                ],
              ],
              if (answerStudyNotes[q.id] case final supplement?)
                AnswerStudyDetails(note: supplement),
              if (q.note.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(height: 1),
                ),
                const Text(
                  '学習のポイント',
                  style: TextStyle(color: teal, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(q.note, style: const TextStyle(height: 1.6)),
              ],
            ]),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: _tutorialDone,
            onPressed: saving ? null : () => _answer(true),
            icon: const Icon(Icons.check),
            label: const Text('できた'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: _tutorialHard,
            onPressed: saving ? null : () => _answer(false),
            icon: const Icon(Icons.bookmark_add_outlined),
            label: const Text('まだ難しい'),
          ),
          const SizedBox(height: 8),
          const Text(
            '学習記録に残し、あとから復習できます。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
          if (saving)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ],
    );
  }
}

Widget _surface(List<Widget> children) => Container(
  width: double.infinity,
  padding: const EdgeInsets.all(24),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: const Color(0xFFE3E8E2)),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: children,
  ),
);
