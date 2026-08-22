import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProgressStore extends ChangeNotifier {
  ProgressStore._();

  static final ProgressStore instance = ProgressStore._();

  static const _levelKey = 'progress.level';
  static const _coinsKey = 'progress.coins';
  static const _heartsKey = 'progress.hearts';
  static const _heartsDepletedAtKey = 'progress.heartsDepletedAt';

  static const maxHearts = 5;
  static const heartRechargeDuration = Duration(minutes: 15);

  int level = 50;
  int coins = 1000;
  int hearts = 5;
  DateTime? heartsDepletedAt;

  SharedPreferences? _preferences;

  Future<void> load() async {
    _preferences ??= await SharedPreferences.getInstance();
    level = _preferences!.getInt(_levelKey) ?? level;
    coins = _preferences!.getInt(_coinsKey) ?? coins;
    hearts = _preferences!.getInt(_heartsKey) ?? hearts;
    final depletedAtMilliseconds = _preferences!.getInt(_heartsDepletedAtKey);
    heartsDepletedAt = depletedAtMilliseconds == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(depletedAtMilliseconds);
    if (hearts == 0 && heartsDepletedAt == null) {
      heartsDepletedAt = DateTime.now();
      await _preferences!.setInt(
        _heartsDepletedAtKey,
        heartsDepletedAt!.millisecondsSinceEpoch,
      );
    }
    _refreshHearts();
  }

  Future<void> refresh() async {
    _refreshHearts();
    await save();
  }

  Future<void> refreshRecharge() async {
    final previousHearts = hearts;
    _refreshHearts();
    if (hearts != previousHearts) await save();
  }

  int consumeHeart() {
    if (hearts <= 0) return hearts;
    hearts--;
    if (hearts == 0) heartsDepletedAt = DateTime.now();
    return hearts;
  }

  void refillHearts() {
    hearts = maxHearts;
    heartsDepletedAt = null;
  }

  Duration? get rechargeTimeRemaining {
    final depletedAt = heartsDepletedAt;
    if (hearts != 0 || depletedAt == null) return null;
    final remaining =
        heartRechargeDuration - DateTime.now().difference(depletedAt);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  String? get rechargeTimeLabel {
    final remaining = rechargeTimeRemaining;
    if (remaining == null) return null;
    final totalSeconds = remaining.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _refreshHearts() {
    final depletedAt = heartsDepletedAt;
    if (hearts != 0 || depletedAt == null) return;
    if (DateTime.now().difference(depletedAt) >= heartRechargeDuration) {
      refillHearts();
    }
  }

  Future<void> save() async {
    _preferences ??= await SharedPreferences.getInstance();
    await Future.wait([
      _preferences!.setInt(_levelKey, level),
      _preferences!.setInt(_coinsKey, coins),
      _preferences!.setInt(_heartsKey, hearts),
      if (heartsDepletedAt == null)
        _preferences!.remove(_heartsDepletedAtKey)
      else
        _preferences!.setInt(
          _heartsDepletedAtKey,
          heartsDepletedAt!.millisecondsSinceEpoch,
        ),
    ]);
    notifyListeners();
  }
}
