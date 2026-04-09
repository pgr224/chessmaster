import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/engine/chess_engine.dart';
import '../../../data/models/puzzle_model.dart';
import '../../../data/models/game_config.dart';
import '../../../data/services/elo_service.dart';
import 'post_game_analysis_chart.dart';

class GameOverOverlay extends StatefulWidget {
  final GameResult result;
  final DrawReason? drawReason;
  final PieceColor? playerColor;
  final VoidCallback onPlayAgain;
  final VoidCallback onGoHome;
  final VoidCallback onShare;
  final Puzzle? puzzle;
  final String? opponentName;
  final int? moveCount;
  final GameMode? gameMode;
  final double accuracy;
  final double opponentAccuracy;
  final int mistakes;
  final int opponentMistakes;
  final int blunders;
  final int opponentBlunders;
  final int xpGained;
  final int xpReward;
  final int xpPenalty;
  final String? analysisMessage;
  final List<double> evalHistory;
  final int eloChange;
  final int currentElo;
  final int bestMoves;

  const GameOverOverlay({
    super.key,
    required this.result,
    this.drawReason,
    this.playerColor,
    required this.onPlayAgain,
    required this.onGoHome,
    required this.onShare,
    this.puzzle,
    this.opponentName,
    this.moveCount,
    this.gameMode,
    this.accuracy = 0.0,
    this.opponentAccuracy = 0.0,
    this.mistakes = 0,
    this.opponentMistakes = 0,
    this.blunders = 0,
    this.opponentBlunders = 0,
    this.xpGained = 0,
    this.xpReward = 0,
    this.xpPenalty = 0,
    this.analysisMessage,
    this.evalHistory = const [],
    this.eloChange = 0,
    this.currentElo = 1200,
    this.bestMoves = 0,
  });

  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay> {
  late ConfettiController _confettiController;
  bool _showAnalysis = false;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 4));

    final isWin = (widget.result == GameResult.whiteWins &&
            widget.playerColor == PieceColor.white) ||
        (widget.result == GameResult.blackWins &&
            widget.playerColor == PieceColor.black);

    if (isWin) {
      _confettiController.play();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWin = (widget.result == GameResult.whiteWins &&
            widget.playerColor == PieceColor.white) ||
        (widget.result == GameResult.blackWins &&
            widget.playerColor == PieceColor.black);
    final isDraw = widget.result == GameResult.draw;
    final isCheckmate = !isDraw && !isWin;

    final statusColor = isWin
        ? AppTheme.goldPrimary
        : isDraw
            ? AppTheme.accentCyan
            : AppTheme.accentRed;

    return Stack(
      children: [
        Container(color: Colors.black.withValues(alpha: 0.55)),

        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.82,
            ),
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(
              gradient: AppTheme.cardGradient,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: statusColor.withValues(alpha: 0.6), width: 3),
              boxShadow: [
                BoxShadow(
                    color: statusColor.withValues(alpha: 0.3),
                    blurRadius: 40,
                    spreadRadius: 4),
              ],
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── RESULT HEADER ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          isWin
                              ? '🏆'
                              : isDraw
                                  ? '🤝'
                                  : '💔',
                          style: const TextStyle(fontSize: 42),
                        ),
                      )
                          .animate()
                          .scale(
                              begin: const Offset(0.4, 0.4),
                              duration: 600.ms,
                              curve: Curves.elasticOut)
                          .fadeIn(),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isCheckmate
                                ? 'CHECKMATE!'
                                : isWin
                                    ? 'VICTORY!'
                                    : isDraw
                                        ? 'DRAW!'
                                        : 'DEFEAT',
                            style: GoogleFonts.fredoka(
                              color: statusColor,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
                          const SizedBox(height: 2),
                          Text(
                            _resultText(),
                            style: GoogleFonts.baloo2(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ).animate().fadeIn(delay: 350.ms),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ── ELO CHANGE ──
                  if (widget.eloChange != 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: widget.eloChange > 0
                              ? [
                                  AppTheme.accentCyan.withValues(alpha: 0.2),
                                  AppTheme.accentCyan.withValues(alpha: 0.05)
                                ]
                              : [
                                  AppTheme.accentRed.withValues(alpha: 0.2),
                                  AppTheme.accentRed.withValues(alpha: 0.05)
                                ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: (widget.eloChange > 0
                                  ? AppTheme.accentCyan
                                  : AppTheme.accentRed)
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${EloService.getRankEmoji(widget.currentElo)} ELO: ${widget.currentElo}',
                            style: GoogleFonts.fredoka(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (widget.eloChange > 0
                                      ? AppTheme.accentCyan
                                      : AppTheme.accentRed)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.eloChange > 0
                                  ? '+${widget.eloChange}'
                                  : '${widget.eloChange}',
                              style: GoogleFonts.fredoka(
                                color: widget.eloChange > 0
                                    ? AppTheme.accentCyan
                                    : AppTheme.accentRed,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.1),

                  // ── PERFORMANCE STATS ──
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(18),
                      border:
                          Border.all(color: AppTheme.skyBlue.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      children: [
                        if (widget.gameMode == GameMode.multiplayer ||
                            widget.gameMode == GameMode.twoPlayer) ...[
                          _buildAccuracyBars(),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _dualStatItem(
                                  'Mistakes',
                                  '${widget.mistakes}',
                                  '${widget.opponentMistakes}',
                                  AppTheme.lavender),
                              _dualStatItem(
                                  'Blunders',
                                  '${widget.blunders}',
                                  '${widget.opponentBlunders}',
                                  AppTheme.accentRed),
                            ],
                          ),
                        ] else if (widget.gameMode == GameMode.singlePlayer ||
                            widget.gameMode == GameMode.practice) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _singleStatItem(
                                  'Accuracy',
                                  '${widget.accuracy.round()}%',
                                  AppTheme.accentCyan),
                              _singleStatItem('Mistakes', '${widget.mistakes}',
                                  AppTheme.lavender),
                              _singleStatItem('Blunders', '${widget.blunders}',
                                  AppTheme.accentRed),
                            ],
                          ),
                        ] else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _dualStatItem(
                                  'Accuracy',
                                  '${widget.accuracy.round()}%',
                                  '${widget.opponentAccuracy.round()}%',
                                  AppTheme.accentCyan),
                              _dualStatItem(
                                  'Mistakes',
                                  '${widget.mistakes}',
                                  '${widget.opponentMistakes}',
                                  AppTheme.lavender),
                              _dualStatItem(
                                  'Blunders',
                                  '${widget.blunders}',
                                  '${widget.opponentBlunders}',
                                  AppTheme.accentRed),
                            ],
                          ),
                        if (widget.analysisMessage != null) ...[
                          const Divider(height: 20, color: AppTheme.textMuted),
                          Text(
                            widget.analysisMessage!,
                            style: GoogleFonts.baloo2(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ).animate().fadeIn(delay: 450.ms).slideX(begin: 0.1),

                  const SizedBox(height: 12),

                  // ── ANALYSIS CHART TOGGLE ──
                  if (widget.evalHistory.isNotEmpty)
                    Column(
                      children: [
                        GestureDetector(
                          onTap: () =>
                              setState(() => _showAnalysis = !_showAnalysis),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.skyBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppTheme.skyBlue.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _showAnalysis
                                      ? Icons.expand_less_rounded
                                      : Icons.analytics_rounded,
                                  color: AppTheme.skyBlue,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _showAnalysis
                                      ? 'Hide Analysis'
                                      : '📊 View Game Analysis',
                                  style: GoogleFonts.fredoka(
                                    color: AppTheme.skyBlue,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ).animate().fadeIn(delay: 500.ms),
                        if (_showAnalysis) ...[
                          const SizedBox(height: 12),
                          PostGameAnalysisChart(
                            evalHistory: widget.evalHistory,
                            totalMoves:
                                widget.moveCount ?? widget.evalHistory.length,
                            accuracy: widget.accuracy,
                            mistakes: widget.mistakes,
                            blunders: widget.blunders,
                            bestMoves: widget.bestMoves,
                          )
                              .animate()
                              .fadeIn(duration: 400.ms)
                              .slideY(begin: 0.1),
                        ],
                        const SizedBox(height: 12),
                      ],
                    ),

                  // ── XP GAINED / LOST ──
                  if (widget.xpGained != 0 ||
                      widget.xpReward != 0 ||
                      widget.xpPenalty != 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: (widget.xpReward > 0 || widget.xpGained > 0)
                                ? [
                                    AppTheme.goldPrimary.withValues(alpha: 0.4),
                                    AppTheme.goldPrimary.withValues(alpha: 0.1)
                                  ]
                                : [
                                    AppTheme.accentRed.withValues(alpha: 0.4),
                                    AppTheme.accentRed.withValues(alpha: 0.1)
                                  ]),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: ((widget.xpReward > 0 || widget.xpGained > 0)
                                    ? AppTheme.goldPrimary
                                    : AppTheme.accentRed)
                                .withValues(alpha: 0.5),
                            width: 2),
                        boxShadow: [
                          BoxShadow(
                          color: ((widget.xpReward > 0 || widget.xpGained > 0)
                                    ? AppTheme.goldPrimary
                                    : AppTheme.accentRed)
                                .withValues(alpha: 0.2),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                (widget.xpReward > 0 || widget.xpGained > 0)
                                    ? Icons.stars_rounded
                                    : Icons.trending_down_rounded,
                                color: (widget.xpReward > 0 || widget.xpGained > 0)
                                    ? AppTheme.goldPrimary
                                    : AppTheme.accentRed,
                                size: 30,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                widget.xpReward > 0
                                    ? '+${widget.xpReward} XP'
                                    : (widget.xpGained > 0
                                        ? '+${widget.xpGained} XP'
                                        : '${widget.xpGained} XP'),
                                style: GoogleFonts.fredoka(
                                  color: (widget.xpReward > 0 || widget.xpGained > 0)
                                      ? AppTheme.goldPrimary
                                      : AppTheme.accentRed,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.xpReward > 0
                                ? 'WIN REWARD'
                                : (widget.xpGained > 0 ? 'XP GAINED' : 'XP PENALTY'),
                            style: GoogleFonts.fredoka(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                          if (widget.xpPenalty > 0) ...[
                            const SizedBox(height: 6),
                            Text(
                              '-${widget.xpPenalty} XP deductions',
                              style: GoogleFonts.baloo2(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              widget.xpGained >= 0
                                  ? 'Net +${widget.xpGained} XP applied to score'
                                  : 'Net ${widget.xpGained} XP applied to score',
                              style: GoogleFonts.fredoka(
                                color: AppTheme.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .shimmer(
                            delay: 1.seconds,
                            duration: 1500.ms,
                            color: Colors.white.withValues(alpha: 0.2))
                        .scale(
                            begin: const Offset(1, 1),
                            end: const Offset(1.03, 1.03),
                            duration: 1000.ms,
                            curve: Curves.easeInOut)
                        .animate()
                        .scale(
                            delay: 700.ms,
                            duration: 500.ms,
                            curve: Curves.easeOutBack)
                        .fadeIn(delay: 700.ms),

                  // ── ACTION BUTTONS ──
                  Row(
                    children: [
                      Expanded(
                        flex: widget.gameMode == GameMode.puzzle ? 2 : 3,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textPrimary,
                            side: BorderSide(
                                color: AppTheme.textMuted.withValues(alpha: 0.3),
                                width: 2),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          onPressed: widget.onShare,
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: Text('Share',
                              style: GoogleFonts.fredoka(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: widget.gameMode == GameMode.puzzle ? 4 : 5,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: statusColor,
                            foregroundColor: AppTheme.midnight,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            elevation: 8,
                          ),
                          onPressed: widget.onPlayAgain,
                          icon: Icon(
                              widget.gameMode == GameMode.puzzle
                                  ? Icons.skip_next_rounded
                                  : Icons.refresh_rounded,
                              size: 20),
                          label: Text(
                              widget.gameMode == GameMode.puzzle
                                  ? 'NEXT PUZZLE'
                                  : 'REMATCH',
                              style: GoogleFonts.fredoka(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  letterSpacing: 1)),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.3),

                  const SizedBox(height: 8),

                  TextButton.icon(
                    onPressed: widget.onGoHome,
                    icon: const Icon(Icons.home_rounded,
                        color: AppTheme.textMuted, size: 18),
                    label: Text('Back to Home',
                        style: GoogleFonts.fredoka(
                            color: AppTheme.textMuted,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ).animate().fadeIn(delay: 650.ms),
                ],
              ),
            ),
          ),
        ),

        // Confetti
        if (isWin)
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                AppTheme.goldPrimary,
                AppTheme.accentCyan,
                AppTheme.accentPurple,
                AppTheme.skyBlue,
                Colors.white,
              ],
              numberOfParticles: 50,
              maximumSize: const Size(15, 7),
              gravity: 0.2,
            ),
          ),
      ],
    );
  }

  Widget _singleStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.fredoka(
              color: color, fontSize: 20, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: GoogleFonts.baloo2(
              color: AppTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _dualStatItem(String label, String me, String them, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              me,
              style: GoogleFonts.fredoka(
                  color: color, fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(
              ' vs ',
              style: GoogleFonts.fredoka(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
            Text(
              them,
              style: GoogleFonts.fredoka(
                  color: color.withValues(alpha: 0.7),
                  fontSize: 18,
                  fontWeight: FontWeight.w800),
            ),
          ],
        ),
        Text(
          label,
          style: GoogleFonts.baloo2(
              color: AppTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildAccuracyBars() {
    final myLabel = 'You';
    final oppLabel = widget.opponentName?.trim().isNotEmpty == true
        ? widget.opponentName!.trim()
        : 'Opponent';

    final myAcc = widget.accuracy.clamp(0.0, 100.0);
    final oppAcc = widget.opponentAccuracy.clamp(0.0, 100.0);

    final isTie = (myAcc - oppAcc).abs() < 0.05;
    final myIsHigher = myAcc > oppAcc;

    final myColor = isTie
        ? AppTheme.accentCyan
        : (myIsHigher ? AppTheme.accentGreen : AppTheme.accentRed);
    final oppColor = isTie
        ? AppTheme.accentCyan
        : (!myIsHigher ? AppTheme.accentGreen : AppTheme.accentRed);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Accuracy Comparison',
          style: GoogleFonts.fredoka(
            color: AppTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        _accuracyBarRow(
          name: myLabel,
          value: myAcc,
          color: myColor,
        ),
        const SizedBox(height: 8),
        _accuracyBarRow(
          name: oppLabel,
          value: oppAcc,
          color: oppColor,
        ),
      ],
    );
  }

  Widget _accuracyBarRow({
    required String name,
    required double value,
    required Color color,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 86,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.fredoka(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (value / 100.0).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: AppTheme.textMuted.withValues(alpha: 0.24),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          child: Text(
            '${value.toStringAsFixed(1)}%',
            textAlign: TextAlign.right,
            style: GoogleFonts.fredoka(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  String _resultText() {
    if (widget.result == GameResult.draw) {
      return switch (widget.drawReason) {
        DrawReason.stalemate => 'Stalemate — no legal moves left! 😅',
        DrawReason.insufficientMaterial => 'Not enough pieces to win! ♟️',
        DrawReason.fiftyMoveRule => '50 moves without a catch! ⏳',
        DrawReason.threefoldRepetition => 'Same position repeated 3 times! 🔄',
        DrawReason.agreement => 'Draw by mutual agreement! 🤝',
        null => 'The game ends in a draw! 😊',
      };
    }
    if (widget.puzzle != null) return 'Puzzle solved with brilliance! 🧠';

    final didPlayerWin = (widget.result == GameResult.whiteWins &&
            widget.playerColor == PieceColor.white) ||
        (widget.result == GameResult.blackWins &&
            widget.playerColor == PieceColor.black);
    final didPlayerLose = (widget.result == GameResult.whiteWins &&
            widget.playerColor == PieceColor.black) ||
        (widget.result == GameResult.blackWins &&
            widget.playerColor == PieceColor.white);

    if (widget.gameMode == GameMode.singlePlayer ||
        widget.gameMode == GameMode.practice) {
      final opponentLabel = widget.opponentName ?? 'Computer';
      if (didPlayerWin) return 'You defeated $opponentLabel! 🥳';
      if (didPlayerLose) return '$opponentLabel wins this round.';
    }

    if (widget.gameMode == GameMode.multiplayer && widget.opponentName != null) {
      if (didPlayerWin) return 'You defeated ${widget.opponentName}! 🥳';
      if (didPlayerLose) return '${widget.opponentName} wins this round.';
    }

    final winner = widget.result == GameResult.whiteWins ? 'White' : 'Black';
    return '$winner wins the battle! 🥳';
  }
}
