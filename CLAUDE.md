# CLAUDE.md — e-Signal

## Projet
Application mobile Flutter de messagerie unifiée pour PME africaines (Côte d'Ivoire).
Plateforme : Score360 Africa. Framework : Flutter (iOS + Android).

---

## PHILOSOPHIE DESIGN — RÈGLE ABSOLUE

**L'application est BLANCHE. Le vert et le violet sont des accents chirurgicaux, pas des fonds.**

Répartition stricte :
- 70% blanc / gris très clair (#F7F8FA) — fonds d'écrans, cartes, listes
- 20% vert — boutons principaux, badges, icône active nav, statuts
- 10% violet — tout ce qui touche au paiement uniquement

**INTERDIT :**
- Fond d'écran vert ou violet (sauf slides onboarding = exception unique)
- Header vert pleine largeur sur les écrans intérieurs (inbox, chat, paiements, profil)
- Remplir les cartes ou listes de couleur
- Mettre de la couleur partout "pour que ce soit beau" — moins = mieux

**AUTORISÉ :**
- Boutons principaux en vert (pill shape, coins très arrondis)
- Petits badges, points, icônes actives en vert
- Tout ce qui concerne le paiement en violet (bouton, badge statut)
- Dégradé vert uniquement sur les 3 slides d'onboarding

---

## Charte graphique

### Couleurs

```
Vert principal   : #1E9E5E   (boutons, badges, icône active)
Vert foncé       : #1A6B3A   (texte sur fond vert pâle)
Vert pâle        : #E8F8F0   (fond bouton secondaire, badge payé)
Vert dégradé     : #1A6B3A → #1E9E5E  (onboarding uniquement)

Violet principal : #6C5CE7   (paiements, bouton paiement, badge en attente)
Violet foncé     : #4A3DB5   (texte sur fond violet pâle)
Violet pâle      : #F0EEFF   (fond bouton paiement, badge en attente)

Blanc            : #FFFFFF   (fond principal de TOUS les écrans)
Gris très clair  : #F7F8FA   (fond de page, séparateurs, input background)
Gris moyen       : #E8E9EC   (bordures, séparateurs fins)
Texte principal  : #1A1A2E   (titres, noms)
Texte secondaire : #6B7280   (aperçus, horodatages, labels)
Texte hint       : #9CA3AF   (placeholder dans les champs)

Statut Payé      : fond #E8F8F0 / texte #1A6B3A
Statut En attente: fond #F0EEFF / texte #6C5CE7
Statut Créé      : fond #F3F4F6 / texte #6B7280
Statut Expiré    : fond #F3F4F6 / texte #9CA3AF
```

### Typographie
- Police : **Outfit** (Google Fonts) — importer dans pubspec.yaml
- Fallback : Roboto (natif Android)
- Titres : Outfit 700 (Bold)
- Corps : Outfit 400 (Regular)
- Labels : Outfit 600 (SemiBold)
- Tailles : H1=24px, H2=20px, H3=16px, Body=14px, Small=12px, Tiny=11px

### Formes & Rayons
- Boutons principaux : BorderRadius.circular(28) — pill shape
- Boutons secondaires/chips : BorderRadius.circular(20)
- Cartes conversation : BorderRadius.circular(16)
- Bulles de message : BorderRadius.circular(18) avec coin aplati côté émetteur
- Champs de formulaire : BorderRadius.circular(14)
- Avatars : circulaires
- Badges/pills : BorderRadius.circular(12)

---

## Style des composants clés

### Bouton principal

```dart
// Fond vert, texte blanc, pill shape, pleine largeur
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: Color(0xFF1E9E5E),
    foregroundColor: Colors.white,
    shape: StadiumBorder(),
    padding: EdgeInsets.symmetric(vertical: 16),
    minimumSize: Size(double.infinity, 52),
    elevation: 0,
  ),
)
```

### Bouton secondaire / Passer

```dart
// Fond vert pâle, texte vert foncé, pill shape
TextButton(
  style: TextButton.styleFrom(
    backgroundColor: Color(0xFFE8F8F0),
    foregroundColor: Color(0xFF1A6B3A),
    shape: StadiumBorder(),
    padding: EdgeInsets.symmetric(vertical: 14, horizontal: 24),
  ),
)
```

### Bouton paiement (VIOLET — uniquement dans le contexte paiement)

```dart
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: Color(0xFFF0EEFF),
    foregroundColor: Color(0xFF6C5CE7),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    elevation: 0,
  ),
)
```

### Barre de navigation inférieure

```dart
// Fond BLANC avec fine bordure grise en haut — PAS de fond vert
BottomNavigationBar(
  backgroundColor: Colors.white,
  selectedItemColor: Color(0xFF1E9E5E),   // vert uniquement sur l'icône active
  unselectedItemColor: Color(0xFF9CA3AF), // gris pour les inactives
  // Séparateur : BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE8E9EC), width: 0.5)))
)
```

### Barre de recherche

```dart
// Fond gris très clair, pas de bordure, coins arrondis
Container(
  decoration: BoxDecoration(
    color: Color(0xFFF7F8FA),
    borderRadius: BorderRadius.circular(14),
  ),
)
```

### Chips / Filtres

```dart
// Actif vert : fond #1E9E5E, texte blanc
// Actif violet (Non lus) : fond #F0EEFF, texte #6C5CE7
// Inactif : fond #F3F4F6, texte #6B7280
```

### Badge non-lus

```dart
// Petit cercle vert, texte blanc, max 2 chiffres
Container(
  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  decoration: BoxDecoration(
    color: Color(0xFF1E9E5E),
    borderRadius: BorderRadius.circular(10),
  ),
  child: Text('3', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
)
```

---

## Architecture des dossiers

```
lib/
  core/
    theme/
      app_theme.dart        ← ThemeData Flutter
      app_colors.dart       ← toutes les couleurs en constantes
      app_text_styles.dart  ← styles typographiques
    constants/
      app_strings.dart
  features/
    auth/
      onboarding/           ← slides (dégradé vert = exception)
      login/                ← connexion page 1 & 2 (fond blanc)
      pin/                  ← lockscreen PIN (fond blanc ou très léger)
    inbox/
      inbox_screen.dart
      chat_screen.dart
    payments/
      payments_screen.dart
      create_link_screen.dart
    profile/
      profile_screen.dart
  shared/
    widgets/                ← composants réutilisables (AppButton, AppChip...)
    mock/                   ← données mockées JSON/Dart
    services/               ← contrats d'API (interfaces abstraites)
    models/                 ← modèles de données
```

---

## Navigation
- GoRouter recommandé
- BottomNavigationBar : 3 onglets — Inbox / Paiements / Profil
- Fond barre nav : **BLANC** (#FFFFFF)
- Bordure top : 0.5px gris #E8E9EC
- Icône active : vert #1E9E5E
- Icône inactive : gris #9CA3AF
- Label actif : vert #1E9E5E, taille 11px

---

## Règles de code

1. **TOUJOURS** utiliser AppColors.xxx — jamais de couleur hardcodée
2. **TOUJOURS** créer les données mockées dans lib/shared/mock/ avant de coder un écran
3. **TOUJOURS** définir l'interface du service (contrat API) avant l'implémentation mock
4. Backend pas prêt : toutes les features utilisent les mock data
5. Pas de packages non-standards sans validation préalable
6. Chaque écran = fond blanc (#FFFFFF) sauf onboarding
7. La couleur = récompense visuelle, pas décoration de fond

---

## Contrats d'API (résumé)

Chaque service doit avoir :
- Une `abstract class XxxService` dans `lib/shared/services/`
- Une `class MockXxxService implements XxxService` dans `lib/shared/mock/`
- Commentaires sur chaque méthode : endpoint attendu, paramètres, réponse

Exemple :

```dart
abstract class InboxService {
  /// GET /api/threads?channel=&unread=
  Future<List<Thread>> getThreads({String? channelFilter, bool? unreadOnly});

  /// GET /api/threads/:id/messages?page=&limit=20
  Future<List<Message>> getMessages(String threadId, {int page = 1});

  /// POST /api/threads/:id/messages
  Future<void> sendMessage(String threadId, String content);
}
```

---

## Stack technique
- Flutter (iOS + Android)
- GoRouter (navigation)
- Riverpod ou Provider (state management — choisir avant Sprint 1)
- SharedPreferences (PIN, onboarding vu, session locale)
- Socket.io / Firebase Realtime (messages temps réel — Sprint 4)
- Firebase Cloud Messaging (notifications push — Sprint 4)
- Google Fonts : package `google_fonts` pour Outfit
