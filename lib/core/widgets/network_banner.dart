import 'package:flutter/material.dart';
import '../services/network_service.dart';

/// Bannière rouge discrète affichée quand le réseau est absent.
/// Se place en haut du Scaffold, hauteur animée 0 ↔ 36px.
class NetworkBanner extends StatelessWidget {
  const NetworkBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: NetworkService.onStatusChange,
      initialData: NetworkService.isOnline,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          height: isOnline ? 0 : 36,
          color: const Color(0xFFD32F2F),
          child: isOnline
              ? const SizedBox.shrink()
              : const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off, color: Colors.white, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Pas de connexion réseau',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
