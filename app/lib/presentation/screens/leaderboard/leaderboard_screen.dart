import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/di/injection_container.dart' as di;
import '../../../data/services/achievement_service.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/mission_service.dart';

class _LeaderboardEntry {
  final String id;
  final String username;
  final String? avatarUrl;
  final int xp;
  final int eloRating;
  final int wins;
  final int gamesPlayed;
  final double winRate;
  final int longestStreak;
  final int rank;
  final bool isOnline;

  const _LeaderboardEntry({
    required this.id,
    required this.username,
    this.avatarUrl,
    required this.xp,
    required this.eloRating,
    required this.wins,
    required this.gamesPlayed,
    required this.winRate,
    required this.longestStreak,
    required this.rank,
    required this.isOnline,
  });

  factory _LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    final rawOnline = json['is_online'];
    final isOnline = rawOnline == true ||
        rawOnline == 1 ||
        rawOnline == '1' ||
        rawOnline == 'true';

    return _LeaderboardEntry(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? 'Player',
      avatarUrl: json['avatar_url'] as String?,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      eloRating: (json['elo_rating'] as num?)?.toInt() ?? 1200,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      gamesPlayed: (json['games_played'] as num?)?.toInt() ?? 0,
      winRate: (json['win_rate'] as num?)?.toDouble() ?? 0,
      longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      isOnline: isOnline,
    );
  }
}

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<_LeaderboardEntry> _entries = [];
  bool _loading = true;
  String _error = '';
  String _sortType = 'elo';
  int _myRank = 0;
  String? _bountyUserId;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticatedState) {
      _fetchLeaderboard();
      // Auto-refresh leaderboard every 30 seconds to sync player name changes
      _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) {
          _fetchLeaderboard();
        }
      });
    } else {
      _loading = false;
      _error = 'Login required to view leaderboard';
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchLeaderboard() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final dio = di.sl<Dio>();
      final response = await dio.get('/api/leaderboard',
          queryParameters: {'type': _sortType, 'limit': 50},
          options: Options(validateStatus: (_) => true));

      if (response.statusCode != 200) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Leaderboard is temporarily unavailable';
        });
        return;
      }

      final data = _asStringKeyedMap(response.data);
      final list = (data['leaderboard'] is List)
          ? data['leaderboard'] as List
          : const [];
      setState(() {
        _entries = list
            .map(_asStringKeyedMap)
            .map(_LeaderboardEntry.fromJson)
            .toList();
        _loading = false;
      });
      _fetchMyRank();
      _fetchBountyTarget();
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Failed to load leaderboard';
      });
    }
  }

  void _fetchBountyTarget() {
    final missionService = di.sl<MissionService>();
    setState(() {
      _bountyUserId = missionService.bountyUserId;
    });
  }

  Future<void> _fetchMyRank() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticatedState) return;
    try {
      final dio = di.sl<Dio>();
      final response =
          await dio.get('/api/leaderboard/rank/${authState.user.id}',
            queryParameters: {'type': _sortType},
              options: Options(validateStatus: (_) => true));

      if (response.statusCode != 200) return;

      final data = _asStringKeyedMap(response.data);
      setState(() {
        _myRank = (data['rank'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('🏆 Leaderboard',
            style: GoogleFonts.fredoka(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 24)),
        centerTitle: true,
        actions: [
          // Refresh button to sync latest player names
          IconButton(
            icon: Icon(_loading ? null : Icons.refresh, color: AppTheme.accentCyan),
            onPressed: _loading ? null : () => _fetchLeaderboard(),
            tooltip: 'Refresh leaderboard',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Column(
          children: [
            _buildSortTabs(),
            if (_myRank > 0) _buildMyRankBanner(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildSortTabs() {
    final tabs = [
      {'id': 'elo', 'label': '⭐ Rating', 'color': AppTheme.lavender},
      {'id': 'xp', 'label': '🔥 XP', 'color': AppTheme.goldPrimary},
      {'id': 'wins', 'label': '🏆 Wins', 'color': AppTheme.accentCyan},
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: tabs.map((t) {
          final isSelected = _sortType == t['id'];
          final color = t['color'] as Color;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _sortType = t['id'] as String);
                _fetchLeaderboard();
              },
              child: AnimatedContainer(
                duration: 250.ms,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.2)
                      : AppTheme.surface.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: isSelected ? color : Colors.transparent, width: 2),
                ),
                child: Center(
                  child: Text(t['label'] as String,
                      style: GoogleFonts.fredoka(
                        color: isSelected ? color : AppTheme.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      )),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMyRankBanner() {
    final authState = context.read<AuthBloc>().state;
    final int myXp =
        authState is AuthAuthenticatedState ? authState.user.xp : 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: AppTheme.goldGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: AppTheme.goldPrimary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded,
                  color: AppTheme.midnight, size: 26),
              const SizedBox(width: 12),
              Text('Your Rank: #$_myRank',
                  style: GoogleFonts.fredoka(
                    color: AppTheme.midnight,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  )),
            ],
          ),
          if (myXp <= 0) // Only show if user has low/minus XP
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.midnight,
                foregroundColor: AppTheme.goldPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _requestXP(context),
              child: const Text('Request XP',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  void _requestXP(BuildContext context) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.navyCard,
        title: Text('Request XP',
            style: GoogleFonts.fredoka(color: AppTheme.goldPrimary)),
        content: const Text(
            'You are out of XP! Would you like to request 100 XP from the community network?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.goldPrimary),
            onPressed: () async {
              Navigator.pop(ctx);
              final authRepo = di.sl<AuthRepository>();
              try {
                final success = await authRepo.requestXP(amount: 100);
                if (!context.mounted) return;
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'XP Request broadcasted! If accepted, you will recive XP.')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Failed to broadcast request.')));
                }
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to broadcast request: $e')));
              }
            },
            child: const Text('Request 100 XP',
                style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.goldPrimary));
    }
    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: AppTheme.textMuted, size: 48),
            const SizedBox(height: 12),
            Text(_error,
                style: GoogleFonts.baloo2(
                    color: AppTheme.textSecondary, fontSize: 16),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchLeaderboard,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.goldPrimary,
                  foregroundColor: AppTheme.midnight),
              child: Text('Retry',
                  style: GoogleFonts.fredoka(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }
    if (_entries.isEmpty) {
      return Center(
        child: Text('No ranked players yet.\nPlay 5+ games to appear!',
            style:
                GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 16),
            textAlign: TextAlign.center),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchLeaderboard,
      color: AppTheme.goldPrimary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _entries.length,
        itemBuilder: (context, index) =>
            _buildPlayerTile(_entries[index], index),
      ),
    );
  }

  Widget _buildPlayerTile(_LeaderboardEntry entry, int index) {
    final authState = context.read<AuthBloc>().state;
    final isMe =
        authState is AuthAuthenticatedState && authState.user.id == entry.id;

    final Color rankColor;
    final String rankIcon;
    if (entry.rank == 1) {
      rankColor = const Color(0xFFFFD700);
      rankIcon = '🥇';
    } else if (entry.rank == 2) {
      rankColor = const Color(0xFFC0C0C0);
      rankIcon = '🥈';
    } else if (entry.rank == 3) {
      rankColor = const Color(0xFFCD7F32);
      rankIcon = '🥉';
    } else {
      rankColor = AppTheme.textMuted;
      rankIcon = '#${entry.rank}';
    }

    final statValue = _sortType == 'elo'
        ? '${entry.eloRating} 🔥'
        : _sortType == 'wins'
            ? '${entry.wins} W'
            : '${entry.xp} XP';

    return GestureDetector(
      onTap: isMe ? null : () => _showDonationDialog(context, entry),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: isMe
              ? LinearGradient(colors: [
                  AppTheme.goldPrimary.withValues(alpha: 0.12),
                  AppTheme.goldPrimary.withValues(alpha: 0.04)
                ])
              : AppTheme.cardGradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isMe
                  ? AppTheme.goldPrimary.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.05),
              width: isMe ? 2 : 1),
        ),
        child: Row(
          children: [
            // Rank badge
            SizedBox(
              width: 42,
              child: entry.rank <= 3
                  ? Text(rankIcon,
                      style: const TextStyle(fontSize: 26),
                      textAlign: TextAlign.center)
                  : Text(rankIcon,
                      style: GoogleFonts.fredoka(
                          color: rankColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center),
            ),
            const SizedBox(width: 12),
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.goldPrimary.withValues(alpha: 0.12),
                  child: Text(
                    entry.username.isNotEmpty
                        ? entry.username[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.fredoka(
                        color: AppTheme.goldPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                if (entry.isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppTheme.accentGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.midnight, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            // Name & stats
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.username,
                          style: GoogleFonts.fredoka(
                            color: isMe
                                ? AppTheme.goldPrimary
                                : AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: AppTheme.goldPrimary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6)),
                          child: Text('YOU',
                              style: GoogleFonts.fredoka(
                                  color: AppTheme.goldPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.gamesPlayed} games · ${entry.winRate.toStringAsFixed(0)}% win',
                    style: GoogleFonts.baloo2(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            // Primary stat
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (entry.id == _bountyUserId)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.stars_rounded,
                        color: AppTheme.goldPrimary, size: 20),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.goldPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: entry.id == _bountyUserId
                        ? Border.all(color: AppTheme.goldPrimary, width: 1.5)
                        : null,
                  ),
                  child: Text(statValue,
                      style: GoogleFonts.fredoka(
                        color: AppTheme.goldPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      )),
                ),
                if (entry.id == _bountyUserId)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('BOUNTY',
                        style: GoogleFonts.fredoka(
                            color: AppTheme.goldPrimary,
                            fontSize: 8,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.05);
  }

  void _showDonationDialog(BuildContext context, _LeaderboardEntry entry) {
    if (entry.xp >= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${entry.username} is doing fine on XP!')));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.navyCard,
        title: Text('Donate XP to ${entry.username}?',
            style: GoogleFonts.fredoka(color: AppTheme.goldPrimary)),
        content: Text(
            'They currently have ${entry.xp} XP. Donate 100 XP to help them out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.goldPrimary),
            onPressed: () async {
              Navigator.pop(ctx);
              final authRepo = di.sl<AuthRepository>();
              final success =
                  await authRepo.donateXP(recipientId: entry.id, amount: 100);
              if (!context.mounted) return;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Donation successful! 💖')));
                di.sl<AchievementService>().evaluateSpecialActions('donate_xp');
                context.read<AuthBloc>().add(AuthCheckStatusEvent());
                _fetchLeaderboard(); // Refresh to see updated XP
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'Donation failed. Not enough XP or server error.')));
              }
            },
            child: const Text('Donate 100 XP',
                style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _asStringKeyedMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return const <String, dynamic>{};
  }
}
