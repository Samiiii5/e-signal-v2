/// Point de sortie global pour les redirections de session.
/// Alimenté par [app_router.dart] après création du router.
class NavigationService {
  static void Function()? onSessionExpired;
}
