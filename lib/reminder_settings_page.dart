import 'package:flutter/material.dart';
import 'reminders.dart';

class ReminderSettingsPage extends StatefulWidget {
  const ReminderSettingsPage({super.key, required this.manager});
  final ReminderManager manager;
  @override
  State<ReminderSettingsPage> createState() => _ReminderSettingsPageState();
}

class _ReminderSettingsPageState extends State<ReminderSettingsPage> {
  bool loading = true, busy = false, enabled = false, loadFailed = false;
  TimeOfDay time = const TimeOfDay(hour: 20, minute: 0);
  String? message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final saved = await widget.manager.load();
      if (!mounted) return;
      setState(() {
        enabled = saved.enabled;
        time = TimeOfDay(hour: saved.hour, minute: saved.minute);
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          loadFailed = true;
          message = '通知設定を読み込めませんでした。画面を開き直してください。';
        });
      }
    }
  }

  Future<void> _act(Future<void> Function() action, String success) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action();
      if (mounted) setState(() => message = success);
    } on ReminderPermissionDenied {
      if (mounted) {
        setState(() {
          message = '通知が許可されていません。「端末の通知設定」でインクリの通知を許可してから、もう一度お試しください。';
        });
      }
    } catch (error) {
      debugPrint('Reminder operation failed: $error');
      if (mounted) {
        setState(
          () => message = '通知を設定できませんでした。もう一度お試しください。改善しない場合はアプリを再起動してください。',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final supported = widget.manager.backend.supported;
    return Scaffold(
      appBar: AppBar(title: const Text('学習リマインダー')),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Icon(Icons.notifications_active_outlined, size: 44),
                  const SizedBox(height: 16),
                  const Text(
                    '英語の冒険を、毎日の習慣に。',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text('好きな時刻に、毎日1回お知らせします。通知を押すとインクリが開きます。'),
                  const SizedBox(height: 20),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('学習を通知する'),
                    value: enabled,
                    onChanged: busy || loadFailed || !supported
                        ? null
                        : (value) => setState(() {
                            enabled = value;
                            message = null;
                          }),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: busy || loadFailed || !supported
                        ? null
                        : () async {
                            final selected = await showTimePicker(
                              context: context,
                              initialTime: time,
                              builder: (context, child) => MediaQuery(
                                data: MediaQuery.of(
                                  context,
                                ).copyWith(alwaysUse24HourFormat: true),
                                child: child!,
                              ),
                            );
                            if (selected != null && mounted) {
                              setState(() {
                                time = selected;
                                message = null;
                              });
                            }
                          },
                    icon: const Icon(Icons.schedule),
                    label: Text(
                      '通知時刻  ${ReminderSettings(hour: time.hour, minute: time.minute).timeLabel}',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: busy || loadFailed || !supported
                        ? null
                        : () => _act(
                            () => widget.manager.save(
                              ReminderSettings(
                                enabled: enabled,
                                hour: time.hour,
                                minute: time.minute,
                              ),
                            ),
                            enabled
                                ? '毎日 ${ReminderSettings(hour: time.hour, minute: time.minute).timeLabel} の通知を保存しました。'
                                : '学習の通知をオフにしました。',
                          ),
                    child: Text(busy ? '処理中…' : '設定を保存'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: busy || loadFailed || !supported
                        ? null
                        : () => _act(
                            widget.manager.preview,
                            'テスト通知を送りました。端末の通知一覧をご確認ください。毎日の通知設定は変更していません。',
                          ),
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('テスト通知'),
                  ),
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Semantics(liveRegion: true, child: Text(message!)),
                    ),
                  if (supported)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => _act(
                              widget.manager.backend.openSettings,
                              '許可を変更した場合は、「設定を保存」または「テスト通知」を押してください。',
                            ),
                      child: const Text('端末の通知設定'),
                    ),
                  const SizedBox(height: 20),
                  Text(
                    supported
                        ? '設定した時刻を目安にお知らせします。省電力設定や集中モードなどにより、通知が遅れたり表示されなかったりする場合があります。時刻やオン・オフを変えたら「設定を保存」を押してください。'
                        : '通知はAndroid・iPhoneで利用できます。',
                  ),
                  const SizedBox(height: 12),
                  const Text('通知設定はこの端末に保存されます。インターネット接続は不要です。'),
                ],
              ),
      ),
    );
  }
}
