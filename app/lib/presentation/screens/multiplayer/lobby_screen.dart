import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/multiplayer/multiplayer_bloc.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  String _selectedTime = '10+0';

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticatedState) {
      context.read<MultiplayerBloc>().add(MpConnectEvent(authState.user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MultiplayerBloc, MultiplayerState>(
      listener: (context, state) {
        if (state.status == MultiplayerStatus.matchmaking) {
          context.push('/matchmaking');
        } else if (state.status == MultiplayerStatus.inGame && state.gameId != null) {
          context.go('/room/${state.gameId}');
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppTheme.midnight,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
              onPressed: () {
                context.read<MultiplayerBloc>().add(MpDisconnectEvent());
                context.pop();
              },
            ),
            title: const Text('Online Multiplayer', style: TextStyle(color: AppTheme.textPrimary)),
            centerTitle: true,
          ),
          body: Container(
            decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildConnectionStatus(state),
                    const SizedBox(height: 32),
                    const Text(
                      'Select Time Control',
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                    ).animate().fadeIn().slideY(),
                    const SizedBox(height: 16),
                    _buildTimeGrid().animate().fadeIn(delay: 200.ms).slideY(),
                    const Spacer(),
                    _buildPlayButton(state).animate().fadeIn(delay: 400.ms).slideY(),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: AppTheme.goldPrimary.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        // Create private room logic
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Private rooms coming soon!')),
                        );
                      },
                      icon: const Icon(Icons.lock_rounded, color: AppTheme.goldPrimary),
                      label: const Text('Create Private Game', style: TextStyle(color: AppTheme.goldPrimary, fontSize: 16)),
                    ).animate().fadeIn(delay: 500.ms).slideY(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConnectionStatus(MultiplayerState state) {
    final isConnected = state.status == MultiplayerStatus.inLobby;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isConnected ? AppTheme.accentGreen : AppTheme.accentRed,
              boxShadow: [
                BoxShadow(
                  color: (isConnected ? AppTheme.accentGreen : AppTheme.accentRed).withOpacity(0.5),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            isConnected ? 'Connected to Global Server' : 'Connecting...',
            style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeGrid() {
    final times = [
      {'label': 'Bullet', 'time': '1+0', 'icon': Icons.flash_on_rounded},
      {'label': 'Blitz', 'time': '3+0', 'icon': Icons.local_fire_department_rounded},
      {'label': 'Blitz', 'time': '5+0', 'icon': Icons.bolt_rounded},
      {'label': 'Rapid', 'time': '10+0', 'icon': Icons.timer_rounded},
      {'label': 'Rapid', 'time': '15+10', 'icon': Icons.hourglass_top_rounded},
      {'label': 'Classic', 'time': '30+0', 'icon': Icons.account_balance_rounded},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: times.length,
      itemBuilder: (context, index) {
        final item = times[index];
        final isSelected = _selectedTime == item['time'];
        return GestureDetector(
          onTap: () => setState(() => _selectedTime = item['time'] as String),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: isSelected ? AppTheme.cardGradient : null,
              color: isSelected ? null : AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppTheme.goldPrimary : Colors.transparent,
                width: 2,
              ),
              boxShadow: isSelected ? AppTheme.goldShadow : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item['icon'] as IconData, 
                  color: isSelected ? AppTheme.goldPrimary : AppTheme.textMuted,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  item['time'] as String,
                  style: TextStyle(
                    color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  item['label'] as String,
                  style: TextStyle(
                    color: isSelected ? AppTheme.goldPrimary : AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayButton(MultiplayerState state) {
    final isReady = state.status == MultiplayerStatus.inLobby;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18),
        backgroundColor: AppTheme.goldPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        shadowColor: AppTheme.goldPrimary.withOpacity(0.5),
      ),
      onPressed: isReady ? () {
        context.read<MultiplayerBloc>().add(MpJoinMatchmakingEvent(timeControl: _selectedTime));
      } : null,
      child: isReady 
        ? const Text('Find Match', style: TextStyle(
            color: AppTheme.midnight, fontSize: 18, fontWeight: FontWeight.w800,
          ))
        : const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.midnight)),
              SizedBox(width: 12),
              Text('Connecting...', style: TextStyle(color: AppTheme.midnight, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
    );
  }
}
