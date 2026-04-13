import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/di/injection_container.dart' as di;
import '../../../core/theme/app_theme.dart';
import '../../../data/models/multiplayer_models.dart';
import '../../../data/models/time_control.dart';
import '../../../data/repositories/tournament_repository.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/multiplayer/multiplayer_bloc.dart';
import '../../blocs/tournament/tournament_bloc.dart';

/// Screen shown when a player wants to create a private tournament and invite an
/// opponent from the online lobby.
class TournamentInviteScreen extends StatefulWidget {
  /// The pre-selected opponent from the lobby (optional).
  final OnlineLobbyUser? preSelectedOpponent;

  const TournamentInviteScreen({super.key, this.preSelectedOpponent});

  @override
  State<TournamentInviteScreen> createState() => _TournamentInviteScreenState();
}

class _TournamentInviteScreenState extends State<TournamentInviteScreen> {
  OnlineLobbyUser? _selectedOpponent;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _selectedOpponent = widget.preSelectedOpponent;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TournamentBloc>(
      create: (_) =>
          TournamentBloc(di.sl<TournamentRepository>(), di.sl()),
      child: BlocConsumer<TournamentBloc, TournamentState>(
        listener: (context, ts) {
          if (ts.status == TournamentStatus.error && ts.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(ts.errorMessage!)),
            );
          }
        },
        builder: (context, ts) {
          return Scaffold(
            backgroundColor: AppTheme.midnight,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded,
                    color: AppTheme.textPrimary),
                onPressed: () => context.pop(),
              ),
              title: Text(
                '🏆 Tournament Invite',
                style: GoogleFonts.fredoka(
                  color: AppTheme.goldPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              centerTitle: true,
            ),
            body: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.backgroundGradient),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildOpponentSection(context, ts),
                      const SizedBox(height: 20),
                      _buildRoundsSection(context, ts),
                      const SizedBox(height: 20),
                      _buildTimeControlSection(context, ts),
                      const SizedBox(height: 32),
                      _buildSendButton(context, ts),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOpponentSection(BuildContext context, TournamentState ts) {
    final mpState = context.watch<MultiplayerBloc>().state;
    final players = mpState.availablePlayers;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Opponent',
            style: GoogleFonts.fredoka(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (players.isEmpty)
            Text('No players online right now.',
                style: GoogleFonts.baloo2(
                    color: AppTheme.textMuted, fontSize: 14))
          else
            ...players.map((p) => _buildPlayerTile(p)),
        ],
      ),
    );
  }

  Widget _buildPlayerTile(OnlineLobbyUser p) {
    final isSelected = _selectedOpponent?.id == p.id;
    return GestureDetector(
      onTap: () => setState(() => _selectedOpponent = p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.goldPrimary.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.goldPrimary
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.navyCard,
              child: Text(
                p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                style: GoogleFonts.fredoka(color: AppTheme.goldPrimary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      style: GoogleFonts.baloo2(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600)),
                  Text('${p.xp} XP',
                      style: GoogleFonts.baloo2(
                          color: AppTheme.textMuted, fontSize: 12)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.goldPrimary),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundsSection(BuildContext context, TournamentState ts) {
    final rounds = [3, 5, 7];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Number of Rounds',
            style: GoogleFonts.fredoka(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: rounds
                .map((r) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _buildChip(
                          label: 'Best of $r',
                          selected: ts.selectedRounds == r,
                          onTap: () => context
                              .read<TournamentBloc>()
                              .add(TournamentSelectRoundsEvent(r)),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeControlSection(BuildContext context, TournamentState ts) {
    final times = TimeControlPreset.all;
    final selectedPreset = TimeControlPreset.fromValue(ts.selectedTimeControl);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Time Control',
            style: GoogleFonts.fredoka(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: times
                .map((t) => _buildChip(
                      label: t.value,
                      selected: ts.selectedTimeControl == t.value,
                      onTap: () => context
                          .read<TournamentBloc>()
                          .add(TournamentSelectTimeControlEvent(t.value)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(selectedPreset.icon, size: 18, color: selectedPreset.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${selectedPreset.label} • ${selectedPreset.value}',
                  style: GoogleFonts.fredoka(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            selectedPreset.description,
            style: GoogleFonts.baloo2(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(
      {required String label,
      required bool selected,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.goldPrimary.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppTheme.goldPrimary
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.fredoka(
            color: selected ? AppTheme.goldPrimary : AppTheme.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton(BuildContext context, TournamentState ts) {
    final canSend = _selectedOpponent != null && !_isSending;
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.goldPrimary,
        foregroundColor: AppTheme.midnight,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      onPressed: canSend ? () => _sendInvite(context, ts) : null,
      icon: _isSending
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.send_rounded),
      label: Text(
        _isSending ? 'Sending…' : 'Send Tournament Invite',
        style: GoogleFonts.fredoka(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    );
  }

  Future<void> _sendInvite(
      BuildContext context, TournamentState ts) async {
    if (_selectedOpponent == null) return;
    setState(() => _isSending = true);

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticatedState) {
      setState(() => _isSending = false);
      return;
    }

    try {
      // Create the private tournament in DB
      final tournamentId =
          await di.sl<TournamentRepository>().createTournament(
                name: '${authState.user.username} vs ${_selectedOpponent!.name}',
                type: 'private',
                totalRounds: ts.selectedRounds,
                timeControl: ts.selectedTimeControl,
                format: 'best_of',
                invitedPlayers: [_selectedOpponent!.id],
              );

      if (!context.mounted) return;

      // Send lobby WS challenge
      context.read<MultiplayerBloc>().add(MpSendTournamentInviteEvent(
            opponent: _selectedOpponent!,
            tournamentId: tournamentId,
            totalRounds: ts.selectedRounds,
            timeControl: ts.selectedTimeControl,
          ));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '🏆 Tournament invite sent to ${_selectedOpponent!.name}!'),
          backgroundColor: AppTheme.navyCard,
        ),
      );

      context.pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create tournament: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}

