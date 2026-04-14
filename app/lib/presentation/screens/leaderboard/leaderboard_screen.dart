import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/di/injection_container.dart' as di;
import '../../../data/services/achievement_service.dart';
import '../../../data/services/multiplayer_service.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/elo_service.dart';
import '../../../data/services/mission_service.dart';

class _LeaderboardEntry {
  final String id;
  final String username;
  final String? avatarUrl;
  final int xp;
  final int eloRating;
  final int wins;
  final int losses;
  final int draws;
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
    required this.losses,
    required this.draws,
    required this.gamesPlayed,
    required this.winRate,
    required this.longestStreak,
    required this.rank,
    required this.isOnline,
  });

  factory _LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic raw, [int fallback = 0]) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw) ?? fallback;
      return fallback;
    }

    double parseDouble(dynamic raw, [double fallback = 0]) {
      if (raw is double) return raw;
      if (raw is num) return raw.toDouble();
      if (raw is String) return double.tryParse(raw) ?? fallback;
      return fallback;
    }

    final rawOnline = json['is_online'];
    final isOnline = rawOnline == true ||
        rawOnline == 1 ||
        rawOnline == '1' ||
        rawOnline == 'true';

    return _LeaderboardEntry(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? 'Player',
      avatarUrl: json['avatar_url'] as String?,
      xp: parseInt(json['xp']),
      eloRating: parseInt(json['elo_rating'], 1200),
      wins: parseInt(json['wins']),
      losses: parseInt(json['losses']),
      draws: parseInt(json['draws']),
      gamesPlayed: parseInt(json['games_played']),
      winRate: parseDouble(json['win_rate']),
      longestStreak: parseInt(json['longest_streak']),
      rank: parseInt(json['rank']),
      isOnline: isOnline,
    );
  }

  int get level => (xp <= 0) ? 1 : (math.sqrt(xp / 100)).floor() + 1;
}

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<_LeaderboardEntry> _entries = [];
  bool _loading = true;
  bool _isBackgroundRefreshing = false;
  String _error = '';
  String _sortType = 'elo'; // Global ranking by ELO rating
  int _myRank = 0;
  int _activeFetchId = 0;
  String? _bountyUserId;
  Timer? _refreshTimer;
  StreamSubscription? _lobbySubscription;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticatedState) {
      _fetchLeaderboard();
      
      // Real-time push connection: Listen to lobby updates to trigger smooth refreshes
      final multiplayerService = di.sl<MultiplayerService>();
      _lobbySubscription = multiplayerService.lobbyUpdates.listen((event) {
        if (!mounted) return;
        // Trigger background refresh on lobby updates or XP transfers
        if (event['type'] == 'LOBBY_UPDATE' || event['type'] == 'XP_TRANSFERRED') {
          _fetchLeaderboard(background: true);
        }
      });

      // Regular polling as fallback and for non-online stats
      _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
        if (mounted) {
          _fetchLeaderboard(background: true);
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
    _lobbySubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchLeaderboard({bool background = false}) async {
    final requestedSortType = _sortType;
    final fetchId = ++_activeFetchId;

    if (!background) {
      setState(() {
        _loading = true;
        _error = '';
        _myRank = 0;
      });
    } else {
      setState(() {
        _isBackgroundRefreshing = true;
      });
    }

    try {
      final dio = di.sl<Dio>();
      final response = await dio.get('/api/leaderboard',
          queryParameters: {'type': requestedSortType, 'limit': 50},
          options: Options(validateStatus: (_) => true));

      if (!mounted || fetchId != _activeFetchId) return;

      if (response.statusCode != 200) {
        if (!background) {
          setState(() {
            _loading = false;
            _error = 'Leaderboard is temporarily unavailable';
          });
        } else {
          setState(() => _isBackgroundRefreshing = false);
        }
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
        _isBackgroundRefreshing = false;
      });
      _fetchMyRank(sortType: requestedSortType, fetchId: fetchId);
      _fetchBountyTarget();
    } catch (_) {
      if (!mounted || fetchId != _activeFetchId) return;
      if (!background) {
        setState(() {
          _loading = false;
          _error = 'Failed to load leaderboard';
        });
      } else {
        setState(() => _isBackgroundRefreshing = false);
      }
    }
  }

  void _fetchBountyTarget() {
    final missionService = di.sl<MissionService>();
    setState(() {
      _bountyUserId = missionService.bountyUserId;
    });
  }

  Future<void> _fetchMyRank({
    required String sortType,
    required int fetchId,
  }) async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticatedState) return;
    try {
      final dio = di.sl<Dio>();
      final response =
          await dio.get('/api/leaderboard/rank/${authState.user.id}',
            queryParameters: {'type': sortType},
              options: Options(validateStatus: (_) => true));

      if (!mounted || fetchId != _activeFetchId || sortType != _sortType) {
        return;
      }

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
        title: Column(
          children: [
            Text('🏆 Global Rankings',
                style: GoogleFonts.fredoka(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 24)),
            if (_isBackgroundRefreshing)
              Text('Syncing...',
                style: GoogleFonts.baloo2(color: AppTheme.goldPrimary, fontSize: 10))
                .animate(onPlay: (c) => c.repeat())
                .fadeIn(duration: 500.ms)
                .fadeOut(delay: 500.ms),
          ],
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Column(
          children: [
            if (_myRank > 0) _buildMyRankBanner(),
            Expanded(child: _buildContent()),
          ],
        ),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your Global Identity',
                      style: GoogleFonts.baloo2(color: AppTheme.midnight.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.bold)),
                  Text('RANKED #$_myRank',
                      style: GoogleFonts.fredoka(
                        color: AppTheme.midnight,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      )),
                ],
              ),
            ],
          ),
          if (myXp <= 0)
            const SizedBox.shrink(), // XP request feature removed
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
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

    final isPodium = entry.rank <= 3;

    return GestureDetector(
      onTap: () => _showPlayerDetailsDialog(entry),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isPodium 
            ? LinearGradient(
                colors: [
                  rankColor.withValues(alpha: 0.15),
                  AppTheme.surface.withValues(alpha: 0.4)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
          color: isMe
              ? AppTheme.accentCyan.withValues(alpha: 0.1)
              : (isPodium ? null : AppTheme.surface.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isMe 
                ? AppTheme.accentCyan 
                : (isPodium ? rankColor.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05))),
        ),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Center(
                    child: Text(
                      rankIcon,
                      style: GoogleFonts.fredoka(
                        fontSize: isPodium ? 28 : 16,
                        color: rankColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: isPodium ? 24 : 20,
                  backgroundColor: rankColor.withValues(alpha: 0.2),
                  child: Text(
                    entry.username.isNotEmpty ? entry.username.characters.first.toUpperCase() : '?',
                    style: GoogleFonts.fredoka(
                        color: rankColor,
                        fontWeight: FontWeight.bold,
                        fontSize: isPodium ? 18 : 16),
                  ),
                ),
                const SizedBox(width: 14),
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
                                fontSize: isPodium ? 19 : 17,
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
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900)),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        EloService.getRankTitle(entry.eloRating).toUpperCase(),
                        style: GoogleFonts.baloo2(
                            color: AppTheme.goldPrimary.withValues(alpha: 0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _miniStat('Rating', '${entry.eloRating}', AppTheme.lavender, Icons.stars_rounded),
                _miniStat('Wins', '${entry.wins}', AppTheme.goldPrimary, Icons.emoji_events_rounded),
                _miniStat('Win Rate', '${entry.winRate.toStringAsFixed(0)}%', AppTheme.accentCyan, Icons.insights_rounded),
                _miniStat('Matches', '${entry.gamesPlayed}', AppTheme.skyBlue, Icons.sports_esports_rounded),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(delay: (index * 40).ms).slideY(begin: 0.1),
    );
  }

  void _showPlayerDetailsDialog(_LeaderboardEntry entry) {
    final rankColor = entry.rank == 1
        ? const Color(0xFFFFD700)
        : entry.rank == 2
            ? const Color(0xFFC0C0C0)
            : entry.rank == 3
                ? const Color(0xFFCD7F32)
                : AppTheme.textMuted;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.midnight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppTheme.backgroundGradient,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.goldPrimary.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: rankColor.withValues(alpha: 0.2),
                    child: Text(
                      entry.username.isNotEmpty ? entry.username.characters.first.toUpperCase() : '?',
                      style: GoogleFonts.fredoka(
                          color: rankColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.username,
                          style: GoogleFonts.fredoka(
                            color: AppTheme.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          EloService.getRankTitle(entry.eloRating).toUpperCase(),
                          style: GoogleFonts.baloo2(
                              color: AppTheme.goldPrimary.withValues(alpha: 0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2),
                        ),
                        Text(
                          'RANK #${entry.rank}',
                          style: GoogleFonts.fredoka(
                            color: rankColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Stats Grid
              GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _dialogStatTile('ELO Rating', '${entry.eloRating}', AppTheme.lavender, Icons.stars_rounded),
                  _dialogStatTile('Wins', '${entry.wins}', AppTheme.goldPrimary, Icons.emoji_events_rounded),
                  _dialogStatTile('Losses', '${entry.losses}', AppTheme.accentRed, Icons.cancel_rounded),
                  _dialogStatTile('Draws', '${entry.draws}', AppTheme.textMuted, Icons.handshake_rounded),
                  _dialogStatTile('Win Rate', '${entry.winRate.toStringAsFixed(1)}%', AppTheme.accentCyan, Icons.insights_rounded),
                  _dialogStatTile('Matches', '${entry.gamesPlayed}', AppTheme.skyBlue, Icons.sports_esports_rounded),
                  _dialogStatTile('Longest Streak', '${entry.longestStreak}', AppTheme.accentPurple, Icons.local_fire_department_rounded),
                  _dialogStatTile('Power XP', '${entry.xp}', AppTheme.goldPrimary, Icons.bolt_rounded),
                ],
              ),
              const SizedBox(height: 24),
              // Close Button
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.goldPrimary,
                  foregroundColor: AppTheme.midnight,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Close',
                  style: GoogleFonts.fredoka(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Text(value,
                    style: GoogleFonts.fredoka(
                        color: color, fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 2),
            Text(label.toUpperCase(),
                style: GoogleFonts.baloo2(
                    color: color.withValues(alpha: 0.6), fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _dialogStatTile(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.navyCard.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.fredoka(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.baloo2(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
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

