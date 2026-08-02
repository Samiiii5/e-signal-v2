# Arborescence du projet e-Signal

> Application mobile Flutter — **58 fichiers Dart, 22 157 lignes de code**.
> Architecture **Feature-First** : le code est organisé par fonctionnalité métier,
> et non par type technique.

---

## 1. Racine du projet

```
e-signal-v2/
├── android/                 Configuration et build Android
├── ios/                     Configuration et build iOS
├── web/                     Cible web (générée par Flutter, non utilisée)
├── linux/  macos/           Cibles bureau (générées par Flutter, non utilisées)
├── lib/                     ★ CODE SOURCE DE L'APPLICATION
├── test/                    Tests automatisés
├── design/                  Maquettes et visuels d'onboarding (déclarés en assets)
├── docs/                    Documentation d'analyse
├── pubspec.yaml             Dépendances et déclaration des assets
├── pubspec.lock             Versions verrouillées des dépendances
├── analysis_options.yaml    Règles d'analyse statique (flutter_lints)
├── CLAUDE.md                Charte graphique et règles de développement
└── README.md
```

---

## 2. Détail du dossier `lib/` — le code de l'application

```
lib/
├── main.dart                          Point d'entrée : initialisation Firebase,
│                                      session, notifications, lancement du router
│
├── core/                              ── SOCLE TECHNIQUE ──
│   ├── constants/
│   │   └── app_colors.dart            Palette de couleurs (charte graphique)
│   ├── navigation/
│   │   ├── app_router.dart            Déclaration des routes (GoRouter) + redirections
│   │   └── app_shell.dart             Barre de navigation inférieure (4 onglets + bouton +)
│   ├── services/
│   │   ├── api_client.dart            Client HTTP Dio : URL de base, jeton, timeouts,
│   │   │                              renouvellement automatique de session
│   │   ├── navigation_service.dart    Accès au navigateur hors contexte de widget
│   │   ├── network_service.dart       Surveillance de la connectivité
│   │   └── session_service.dart       Session locale persistée (jetons, profil, organisation)
│   ├── theme/
│   │   ├── app_text_styles.dart       Styles typographiques (police Outfit)
│   │   └── app_theme.dart             Thème global Material
│   ├── utils/
│   │   └── responsive.dart            Adaptation aux tailles d'écran
│   └── widgets/
│       ├── app_snackbar.dart          Messages de succès et d'erreur normalisés
│       ├── network_banner.dart        Bandeau « hors connexion »
│       └── shimmer_box.dart           Squelettes de chargement animés
│
├── features/                          ── ÉCRANS PAR FONCTIONNALITÉ ──
│   ├── auth/
│   │   ├── login/
│   │   │   ├── login_page1_screen.dart      Étape 1 : saisie de l'identifiant
│   │   │   ├── login_page2_screen.dart      Étape 2 : saisie du mot de passe
│   │   │   ├── set_password_screen.dart     Activation d'un compte invité
│   │   │   ├── forgot_password_screen.dart  Demande de réinitialisation
│   │   │   ├── otp_screen.dart              Saisie du code reçu par email
│   │   │   └── reset_password_screen.dart   Définition du nouveau mot de passe
│   │   └── onboarding/
│   │       ├── onboarding_screen.dart       3 slides de présentation
│   │       └── painters/                    Illustrations dessinées en code
│   │           ├── slide1_painter.dart
│   │           ├── slide2_painter.dart
│   │           └── slide3_painter.dart
│   │
│   ├── inbox/                               ── MESSAGERIE UNIFIÉE ──
│   │   ├── inbox_screen.dart                Liste des conversations, filtres, temps réel
│   │   ├── chat_screen.dart                 Conversation : messages, envois, catalogue,
│   │   │                                    localisation, actions (le plus gros fichier)
│   │   ├── notifications_screen.dart        Historique des notifications
│   │   ├── publication_detail_screen.dart   Commentaires d'une publication réseau social
│   │   └── widgets/
│   │       └── notification_item.dart       Élément de liste de notification
│   │
│   ├── payments/                            ── PAIEMENT ──
│   │   ├── payments_screen.dart             Liste des liens de paiement + export
│   │   ├── create_link_screen.dart          Création d'un lien (écran plein, 3 étapes)
│   │   ├── create_link_sheet.dart           Création d'un lien (feuille modale, 3 étapes)
│   │   └── transaction_detail_screen.dart   Détail, annulation, reçu PDF
│   │
│   ├── profile/
│   │   └── profile_screen.dart              Profil, canaux connectés, préférences
│   │
│   └── stats/
│       └── stats_screen.dart                Tableau de bord : revenus, conversations, canaux
│
└── shared/                            ── ÉLÉMENTS PARTAGÉS ──
    ├── services/                       Contrats d'API et implémentations
    │   ├── auth_service.dart               Connexion, activation, mot de passe oublié
    │   ├── inbox_service.dart              Conversations, messages, envois, cache
    │   ├── websocket_service.dart          Connexion temps réel (événements de l'inbox)
    │   ├── catalog_service.dart            Produits et comptes d'intégration
    │   ├── payment_service.dart            Liens de paiement, récapitulatif, annulation
    │   ├── comments_service.dart           Publications et commentaires réseaux sociaux
    │   ├── stats_service.dart              Tableau de bord
    │   ├── notification_service.dart       Notifications push (Firebase) et historique
    │   └── livreur_service.dart            Recherche de livreurs (données de démonstration)
    │
    ├── models/                         Structures de données
    │   ├── payment_link.dart               Lien de paiement (API)
    │   ├── lien_paiement_model.dart        Lien de paiement avec livraison
    │   ├── livreur_model.dart              Livreur
    │   ├── notification_model.dart         Notification
    │   └── dashboard_model.dart            Données du tableau de bord
    │
    └── mock/                           Données de démonstration et modèles associés
        ├── threads_mock.dart               Modèle Thread + conversations d'exemple
        ├── messages_mock.dart              Modèle Message + messages d'exemple
        ├── products_mock.dart              Produits d'exemple
        ├── payments_mock.dart              Transactions d'exemple
        ├── publications_mock.dart          Publications d'exemple
        ├── livreurs_mock.dart              Livreurs d'exemple
        ├── delivery_mock.dart              Données de livraison d'exemple
        ├── stats_mock.dart                 Statistiques d'exemple
        └── users_mock.dart                 Utilisateur de test
```

---

## 3. Principe d'organisation

| Couche | Rôle | Règle |
|---|---|---|
| **`core/`** | Socle technique réutilisable | Ne connaît aucune fonctionnalité métier |
| **`features/`** | Écrans, un dossier par domaine métier | Ne communique avec le serveur qu'à travers `shared/services/` |
| **`shared/services/`** | Contrats d'accès aux données | Une classe abstraite définit le contrat, une implémentation HTTP l'applique |
| **`shared/models/`** | Structures de données | Convertissent les réponses du serveur en objets Dart |
| **`shared/mock/`** | Données de démonstration | Utilisées en repli lorsque le serveur est indisponible |

**Convention des services** : chaque service déclare d'abord son contrat sous forme de
classe abstraite (avec l'URL attendue en commentaire), puis son implémentation réelle.
Exemple dans `inbox_service.dart` :

```dart
abstract class InboxService {
  /// GET /api/v1.2/inbox/threads
  Future<List<Thread>> getThreads({String? channelFilter, bool? unreadOnly});
}

class HttpInboxService implements InboxService { ... }   // implémentation réelle
class MockInboxService implements InboxService { ... }   // données de démonstration
```

---

## 4. Volumétrie

| Fichier | Lignes | Contenu |
|---|---|---|
| `features/inbox/chat_screen.dart` | 6 367 | Conversation et tous ses composants d'affichage |
| `features/inbox/inbox_screen.dart` | 1 858 | Liste des conversations et filtres |
| `features/payments/create_link_screen.dart` | 1 713 | Création d'un lien (écran plein) |
| `features/payments/create_link_sheet.dart` | 1 607 | Création d'un lien (feuille modale) |
| `features/auth/onboarding/onboarding_screen.dart` | 1 107 | Slides de présentation |
| `features/payments/payments_screen.dart` | 686 | Liste des transactions et export |
| `shared/services/inbox_service.dart` | 627 | Service de messagerie |
| `features/stats/stats_screen.dart` | 581 | Tableau de bord |
| **Total `lib/`** | **22 157** | **58 fichiers Dart** |

---

## 5. Bibliothèques externes utilisées

| Domaine | Bibliothèques |
|---|---|
| Navigation | `go_router` |
| Réseau | `dio`, `http`, `web_socket_channel` |
| Stockage local | `shared_preferences` |
| Notifications | `firebase_core`, `firebase_messaging`, `cloud_firestore`, `flutter_local_notifications` |
| Médias et fichiers | `image_picker`, `share_plus`, `path_provider`, `open_file` |
| Documents | `pdf` (reçus), `excel` (export des transactions) |
| Localisation | `geolocator` |
| Interface | `google_fonts` (police Outfit), `shimmer`, `flutter_slidable`, `cupertino_icons` |
| Liens externes | `url_launcher` |
| Qualité de code | `flutter_lints` |
