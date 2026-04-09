import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/di/injection_container.dart' as di;
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/achievement_service.dart';
import '../../blocs/auth/auth_bloc.dart';

class DonationSettingsScreen extends StatefulWidget {
  const DonationSettingsScreen({super.key});

  @override
  State<DonationSettingsScreen> createState() => _DonationSettingsScreenState();
}

class _DonationSettingsScreenState extends State<DonationSettingsScreen> {
  final AuthRepository _authRepository = di.sl<AuthRepository>();

  final TextEditingController _searchCtrl = TextEditingController();

  List<_DonationTarget> _targets = const [];
  bool _loading = true;
  bool _donating = false;
  String _error = '';

  _SourceFilter _sourceFilter = _SourceFilter.all;
  _PresenceFilter _presenceFilter = _PresenceFilter.all;
  int _selectedAmount = 100;

  @override
  void initState() {
    super.initState();
    _loadTargets();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTargets({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = '';
      });
    }

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticatedState) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Login required to manage donations.';
      });
      return;
    }

    try {
      final userId = authState.user.id;
      final results = await Future.wait<dynamic>([
        _authRepository.getLeaderboard(limit: 100),
        _authRepository.getFriends(),
      ]);

      final leaderboardUsers = (results[0] as List<UserModel>)
          .where((u) => u.id.isNotEmpty && u.id != userId)
          .toList();
      final friendRows = (results[1] as List<dynamic>)
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList();

      final byId = <String, _DonationTarget>{};

      for (final user in leaderboardUsers) {
        byId[user.id] = _DonationTarget(
          userId: user.id,
          username: user.username,
          xp: user.xp,
          isOnline: user.isOnline,
          inLeaderboard: true,
          inFriends: false,
        );
      }

      for (final row in friendRows) {
        final friendId = row['user_id']?.toString() ?? '';
        if (friendId.isEmpty || friendId == userId) {
          continue;
        }

        final status = row['status']?.toString() ?? 'pending';
        if (status != 'accepted') {
          continue;
        }

        final existing = byId[friendId];
        final isOnline = _parseOnline(row['is_online']);
        final rowXp = (row['xp'] as num?)?.toInt() ?? 0;
        final rowName = row['username']?.toString() ?? 'Player';

        if (existing == null) {
          byId[friendId] = _DonationTarget(
            userId: friendId,
            username: rowName,
            xp: rowXp,
            isOnline: isOnline,
            inLeaderboard: false,
            inFriends: true,
          );
        } else {
          byId[friendId] = existing.copyWith(
            inFriends: true,
            isOnline: isOnline,
            xp: rowXp,
            username: rowName,
          );
        }
      }

      final merged = byId.values.toList()
        ..sort((a, b) {
          if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
          return b.xp.compareTo(a.xp);
        });

      if (!mounted) return;
      setState(() {
        _targets = merged;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load donation targets: $e';
      });
    }
  }

  bool _parseOnline(dynamic raw) {
    return raw == true || raw == 1 || raw == '1' || raw == 'true';
  }

  List<_DonationTarget> _filteredTargets() {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _targets.where((t) {
      final bySource = switch (_sourceFilter) {
        _SourceFilter.all => true,
        _SourceFilter.leaderboard => t.inLeaderboard,
        _SourceFilter.friends => t.inFriends,
      };
      final byPresence = switch (_presenceFilter) {
        _PresenceFilter.all => true,
        _PresenceFilter.online => t.isOnline,
        _PresenceFilter.offline => !t.isOnline,
      };
      final byText = q.isEmpty ||
          t.username.toLowerCase().contains(q) ||
          t.userId.toLowerCase().contains(q);
      return bySource && byPresence && byText;
    }).toList();
  }

  Future<void> _promptDonation(_DonationTarget target) async {
    final amountCtrl = TextEditingController(text: _selectedAmount.toString());
    final parsed = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.navyCard,
        title: Text(
          'Donate XP to ${target.username}',
          style: GoogleFonts.fredoka(color: AppTheme.textPrimary),
        ),
        content: TextField(
          controller: amountCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount',
            hintText: 'Enter XP amount',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final amount = int.tryParse(amountCtrl.text.trim());
              if (amount == null || amount <= 0) {
                return;
              }
              Navigator.pop(ctx, amount);
            },
            child: const Text('Donate'),
          ),
        ],
      ),
    );

    amountCtrl.dispose();

    if (parsed == null || parsed <= 0 || !mounted) {
      return;
    }

    setState(() => _selectedAmount = parsed);
    await _donate(target, parsed);
  }

  Future<void> _donate(_DonationTarget target, int amount) async {
    setState(() => _donating = true);
    try {
      final ok = await _authRepository.donateXP(
        recipientId: target.userId,
        amount: amount,
      );

      if (!mounted) return;

      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Donation failed. Please try again.')),
        );
        return;
      }

      di.sl<AchievementService>().evaluateSpecialActions('donate_xp');
      context.read<AuthBloc>().add(AuthCheckStatusEvent());

      setState(() {
        _targets = _targets
            .map((t) => t.userId == target.userId
                ? t.copyWith(xp: t.xp + amount)
                : t)
            .toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Donated $amount XP to ${target.username}.')),
      );

      unawaited(_loadTargets(silent: true));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Donation failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _donating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final myXp =
        authState is AuthAuthenticatedState ? authState.user.xp : 0;

    final filtered = _filteredTargets();

    return Scaffold(
      backgroundColor: AppTheme.midnight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Donation Settings',
          style: GoogleFonts.fredoka(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Column(
          children: [
            _summaryCard(myXp),
            _filterBar(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.goldPrimary,
                      ),
                    )
                  : _error.isNotEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _error,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.baloo2(
                                    color: AppTheme.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: _loadTargets,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadTargets,
                          child: filtered.isEmpty
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    const SizedBox(height: 120),
                                    Center(
                                      child: Text(
                                        'No players match your filters.',
                                        style: GoogleFonts.baloo2(
                                          color: AppTheme.textSecondary,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 8, 16, 20),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final target = filtered[index];
                                    return _targetCard(target);
                                  },
                                ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(int myXp) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.volunteer_activism_rounded,
              color: AppTheme.goldPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your XP: $myXp',
                  style: GoogleFonts.fredoka(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Select recipients from leaderboard or accepted friends.',
                  style: GoogleFonts.baloo2(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: _donating ? null : _loadTargets,
            child: const Text('Sync'),
          ),
        ],
      ),
    );
  }

  Widget _filterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.baloo2(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search by player name',
              hintStyle: GoogleFonts.baloo2(color: AppTheme.textMuted),
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: AppTheme.surface.withValues(alpha: 0.45),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('All Sources', _sourceFilter == _SourceFilter.all,
                  () => setState(() => _sourceFilter = _SourceFilter.all)),
              _chip('Leaderboard', _sourceFilter == _SourceFilter.leaderboard,
                  () => setState(() => _sourceFilter = _SourceFilter.leaderboard)),
              _chip('Friends', _sourceFilter == _SourceFilter.friends,
                  () => setState(() => _sourceFilter = _SourceFilter.friends)),
              _chip('Any Presence', _presenceFilter == _PresenceFilter.all,
                  () => setState(() => _presenceFilter = _PresenceFilter.all)),
              _chip('Online', _presenceFilter == _PresenceFilter.online,
                  () => setState(() => _presenceFilter = _PresenceFilter.online)),
              _chip('Offline', _presenceFilter == _PresenceFilter.offline,
                  () => setState(() => _presenceFilter = _PresenceFilter.offline)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _amountChip(50),
              _amountChip(100),
              _amountChip(250),
              _amountChip(500),
            ],
          ),
        ],
      ),
    );
  }

  Widget _amountChip(int amount) {
    final selected = _selectedAmount == amount;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => setState(() => _selectedAmount = amount),
      label: Text('$amount XP', style: GoogleFonts.fredoka(fontSize: 12)),
      selectedColor: AppTheme.goldPrimary,
      backgroundColor: AppTheme.surface.withValues(alpha: 0.6),
      labelStyle: TextStyle(
        color: selected ? AppTheme.midnight : AppTheme.textPrimary,
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      label: Text(label, style: GoogleFonts.fredoka(fontSize: 11)),
      selectedColor: AppTheme.accentCyan,
      backgroundColor: AppTheme.surface.withValues(alpha: 0.6),
      labelStyle: TextStyle(
        color: selected ? AppTheme.midnight : AppTheme.textPrimary,
      ),
    );
  }

  Widget _targetCard(_DonationTarget target) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.navyCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: target.isOnline
                ? AppTheme.accentGreen.withValues(alpha: 0.25)
                : AppTheme.textMuted.withValues(alpha: 0.25),
            child: Text(
              target.username.isEmpty
                  ? '?'
                  : target.username.characters.first.toUpperCase(),
              style: GoogleFonts.fredoka(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  target.username,
                  style: GoogleFonts.fredoka(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${target.xp} XP • ${target.isOnline ? 'Online' : 'Offline'}',
                  style: GoogleFonts.baloo2(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: [
                    if (target.inLeaderboard) _badge('Leaderboard'),
                    if (target.inFriends) _badge('Friend'),
                  ],
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: _donating ? null : () => _promptDonation(target),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.goldPrimary,
              foregroundColor: AppTheme.midnight,
            ),
            child: Text(
              'Donate $_selectedAmount',
              style: GoogleFonts.fredoka(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.goldPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: GoogleFonts.fredoka(
          color: AppTheme.goldPrimary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DonationTarget {
  final String userId;
  final String username;
  final int xp;
  final bool isOnline;
  final bool inLeaderboard;
  final bool inFriends;

  const _DonationTarget({
    required this.userId,
    required this.username,
    required this.xp,
    required this.isOnline,
    required this.inLeaderboard,
    required this.inFriends,
  });

  _DonationTarget copyWith({
    String? userId,
    String? username,
    int? xp,
    bool? isOnline,
    bool? inLeaderboard,
    bool? inFriends,
  }) {
    return _DonationTarget(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      xp: xp ?? this.xp,
      isOnline: isOnline ?? this.isOnline,
      inLeaderboard: inLeaderboard ?? this.inLeaderboard,
      inFriends: inFriends ?? this.inFriends,
    );
  }
}

enum _SourceFilter { all, leaderboard, friends }

enum _PresenceFilter { all, online, offline }
