import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/welcome_cinema_tracker.dart';
import '../../../core/ui/app_scaffold.dart';
import 'auth_gate.dart';

class CadastroSucessoRoutingScreen extends StatefulWidget {
  const CadastroSucessoRoutingScreen({super.key});

  @override
  State<CadastroSucessoRoutingScreen> createState() =>
      _CadastroSucessoRoutingScreenState();
}

class _CadastroSucessoRoutingScreenState
    extends State<CadastroSucessoRoutingScreen> {
  static const Color _quietLuxuryNavy = Color(0xFF0F172A);
  static const Color _emeraldAccent = Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    _processarTransicaoSessao();
  }

  String? _currentAuthUserId() {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  /// Ponte cinematográfica O(1) (450ms) sem clarão branco antes do Welcome Cinema.
  Future<void> _processarTransicaoSessao() async {
    await WelcomeCinemaTracker.armForFreshRegistration(_currentAuthUserId());
    await Future.delayed(const Duration(milliseconds: 450));

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AuthGate(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AppScaffold(
        backgroundColor: _quietLuxuryNavy,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    key: const Key('cadastro-sucesso-emerald-seal'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _emeraldAccent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: _emeraldAccent.withValues(alpha: 0.45),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          color: _emeraldAccent,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Cadastro confirmado!',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF6EE7B7),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Preparando sua apresentação...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
