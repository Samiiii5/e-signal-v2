# Ressources logicielles utilisées

> Section rédigée pour le mémoire. Les versions indiquées sont les **versions
> effectivement résolues** dans `pubspec.lock`, et non les contraintes déclarées
> dans `pubspec.yaml` — c'est ce qui garantit la reproductibilité du projet.
> Les licences ont été relevées dans les fichiers `LICENSE` des paquets installés.
>
> ⬜ = information à compléter par l'auteur (non déterminable depuis le dépôt).

---

## 1. Environnement de développement

| Élément | Valeur |
|---|---|
| Système d'exploitation de développement | ⬜ *(Windows d'après les chemins de travail utilisés)* |
| Environnement de développement intégré (IDE) | ⬜ *(VS Code ou Android Studio)* |
| SDK Flutter | ⬜ *(relever avec `flutter --version`)* — canal **stable** |
| SDK Dart | Contrainte projet : **`^3.9.2`** |
| Révision Flutter à la création du projet | `a402d9a4376add5bc2d6b1e33e53edaae58c07f8` |
| Plateformes cibles configurées | **Android** et **iOS** |
| Terminal de test | ⬜ *(émulateur Android et/ou téléphone physique)* |

> **Comment compléter les champs ⬜ :** exécuter `flutter --version` dans le dossier
> du projet et reporter les quatre lignes affichées (Flutter, Dart, DevTools, révision).

---

## 2. Langage et framework

| Ressource | Rôle dans le projet | Licence |
|---|---|---|
| **Dart** | Langage de programmation unique de l'application (typage statique, compilation en code natif ARM) | BSD-3-Clause |
| **Flutter** | Framework de développement multiplateforme : rendu graphique propre au framework, garantissant un affichage identique sur Android et iOS | BSD-3-Clause |

---

## 3. Bibliothèques tierces

L'application s'appuie sur **22 paquets externes** publiés sur `pub.dev`.

### 3.1 Navigation

| Paquet | Version | Rôle |
|---|---|---|
| `go_router` | 14.8.1 | Navigation déclarative : déclaration centralisée des routes, navigation imbriquée avec barre persistante, redirection automatique des écrans protégés |

### 3.2 Communication réseau

| Paquet | Version | Rôle |
|---|---|---|
| `dio` | 5.10.0 | Client HTTP principal : intercepteurs pour l'ajout du jeton d'authentification et le renouvellement de session, gestion des délais d'attente |
| `http` | 1.6.0 | Client HTTP secondaire |
| `web_socket_channel` | 3.0.3 | Connexion temps réel à l'inbox (réception des messages, accusés de lecture, présence) |

### 3.3 Stockage local

| Paquet | Version | Rôle |
|---|---|---|
| `shared_preferences` | 2.5.5 | Persistance de la session : jetons d'accès, profil, organisation, état de la présentation initiale |

### 3.4 Notifications

| Paquet | Version | Rôle |
|---|---|---|
| `firebase_core` | 3.15.2 | Initialisation des services Firebase |
| `firebase_messaging` | 15.2.10 | Notifications push (nouveaux messages, appels, paiements) |
| `cloud_firestore` | 5.6.12 | Stockage de l'historique des notifications |
| `flutter_local_notifications` | 17.2.4 | Affichage des notifications locales lorsque l'application est au premier plan |

### 3.5 Fichiers et partage

| Paquet | Version | Rôle |
|---|---|---|
| `image_picker` | 1.2.2 | Sélection d'une photo dans la galerie du téléphone |
| `share_plus` | 10.1.4 | Partage d'un lien de paiement ou d'une conversation via les applications du système |
| `path_provider` | 2.1.5 | Accès aux répertoires du système pour l'enregistrement des fichiers générés |
| `open_file` | 3.5.11 | Ouverture des fichiers produits (reçus, exports) |

### 3.6 Génération de documents

| Paquet | Version | Rôle |
|---|---|---|
| `pdf` | 3.12.0 | Génération du reçu de transaction au format PDF |
| `excel` | 4.0.6 | Export des transactions au format `.xlsx` |

### 3.7 Matériel du terminal

| Paquet | Version | Rôle |
|---|---|---|
| `geolocator` | 13.0.4 | Obtention des coordonnées GPS pour le partage de position |
| `url_launcher` | 6.3.2 | Ouverture des liens externes et déclenchement des appels téléphoniques |

### 3.8 Interface utilisateur

| Paquet | Version | Rôle |
|---|---|---|
| `google_fonts` | 6.3.3 | Chargement de la police **Outfit** définie par la charte graphique |
| `shimmer` | 3.0.0 | Squelettes de chargement animés |
| `flutter_slidable` | 3.1.2 | Actions par glissement latéral sur les notifications |
| `cupertino_icons` | 1.0.9 | Jeu d'icônes de style iOS |

### 3.9 Qualité de code (dépendance de développement)

| Paquet | Version | Rôle |
|---|---|---|
| `flutter_lints` | 5.0.0 | Jeu de règles d'analyse statique appliqué via `analysis_options.yaml` |
| `flutter_test` | fourni avec le SDK | Cadre de tests automatisés |

---

## 4. Services et plateformes externes

| Service | Rôle |
|---|---|
| **API Score360** — `ws.score360.africa/api/v1.2` | Interface applicative métier : conversations, messages, catalogue, liens de paiement, commentaires, tableau de bord |
| **Connexion temps réel** — `wss://ws.score360.africa/api/v1.2/inbox/ws` | Diffusion des événements de l'inbox |
| **Firebase Cloud Messaging** | Acheminement des notifications push |
| **Cloud Firestore** | Conservation de l'historique des notifications |
| **Render** — `e-signal-v2-backend-notifications.onrender.com` | Hébergement du service d'enregistrement et d'historique des notifications |
| **Plateformes de messagerie** | WhatsApp Business, Facebook Messenger, Instagram, TikTok, SMS, Email — atteintes par l'intermédiaire de l'API Score360 |
| **Passerelles de paiement** | Wave, Orange Money, MTN Money, Moov Money, Djamo, CinetPay, FedaPay |

---

## 5. Outils de test, de débogage et de gestion de version

| Outil | Usage dans le projet |
|---|---|
| **`flutter analyze`** | Analyse statique exécutée avant chaque livraison de code ; l'objectif de zéro anomalie a été maintenu tout au long du développement |
| **Postman** | Vérification indépendante des interfaces applicatives : validation du format d'envoi du carrousel produits, contrôle de l'établissement de la connexion temps réel |
| **Journalisation applicative** | Instructions de traçage placées aux points sensibles (envoi de message, connexion temps réel, chargement du catalogue) pour le diagnostic |
| **Git** | Gestion de version, développement sur branche dédiée |
| **GitHub** | Dépôt distant `Samiiii5/e-signal-v2` — **129 révisions** enregistrées entre le 22 juin et le 3 août 2026 |
| ⬜ **Outil de modélisation UML** | *(à préciser : PlantUML, draw.io, Astah…)* |

---

## 6. Synthèse des licences et des coûts

| Catégorie | Licence | Coût |
|---|---|---|
| Flutter, Dart | BSD-3-Clause | Gratuit |
| 15 paquets tierces | BSD-3-Clause | Gratuit |
| 5 paquets tierces (`dio`, `excel`, `flutter_slidable`, `geolocator`, `cupertino_icons`) | MIT | Gratuit |
| 2 paquets tierces (`google_fonts`, `pdf`) | Apache-2.0 | Gratuit |
| Git, Postman (édition gratuite), VS Code / Android Studio | Libres ou gratuites | Gratuit |
| GitHub | Formule gratuite | Gratuit |

**L'ensemble des ressources logicielles employées pour le développement est donc libre
ou gratuit d'usage.** Les coûts éventuels du projet ne relèvent pas de l'outillage mais
des services exploités en production : facturation à la conversation de l'API WhatsApp
Business, commissions des passerelles de paiement, hébergement du backend, et frais de
publication sur les magasins d'applications.

---

## 7. Répartition des licences

| Licence | Nombre de paquets |
|---|---|
| BSD-3-Clause | 15 |
| MIT | 5 |
| Apache-2.0 | 2 |
| **Total** | **22** |

Ces trois licences sont permissives : elles autorisent l'usage commercial, la
modification et la distribution, sans obligation de publier le code source de
l'application. Aucune n'impose de contrainte de réciprocité incompatible avec un
usage propriétaire.
