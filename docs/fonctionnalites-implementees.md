# e-Signal — Fonctionnalités implémentées et carte du projet

> **Application** : messagerie unifiée pour PME ivoiriennes — Score360 Africa
> **Technologie** : Flutter (Android + iOS) · **58 fichiers Dart** · **23 014 lignes**
> **Branche de référence** : `feature/retouch`
>
> Document de repérage : chaque fonctionnalité est suivie du **chemin exact** du
> fichier qui la contient, dans l'ordre du parcours utilisateur.
>
> **Légende**
> ✅ branché sur l'API Score360 · ⚪ interface seule, aucune requête réseau
> ⚠️ partiellement implémenté · ❌ annoncé mais indisponible

---

## SOMMAIRE

| § | Étape du parcours | Dossier principal |
|---|---|---|
| 0 | Comprendre l'organisation des dossiers | `lib/` |
| 1 | Démarrage de l'application | `lib/main.dart`, `lib/core/` |
| 2 | Présentation initiale (onboarding) | `lib/features/auth/onboarding/` |
| 3 | Connexion et mot de passe | `lib/features/auth/login/` |
| 4 | Navigation générale (4 onglets + bouton ✚) | `lib/core/navigation/` |
| 5 | Inbox — liste des conversations | `lib/features/inbox/inbox_screen.dart` |
| 6 | Temps réel (WebSocket) | `lib/shared/services/websocket_service.dart` |
| 7 | Chat — la conversation | `lib/features/inbox/chat_screen.dart` |
| 8 | Catalogue produits | `lib/shared/services/catalog_service.dart` |
| 9 | Paiements | `lib/features/payments/` |
| 10 | Commentaires réseaux sociaux | `lib/features/inbox/publication_detail_screen.dart` |
| 11 | Statistiques | `lib/features/stats/` |
| 12 | Notifications push | `lib/features/inbox/notifications_screen.dart` |
| 13 | Profil | `lib/features/profile/` |
| 14 | Récapitulatif des 28 endpoints | — |
| 15 | Où ajouter une nouvelle fonctionnalité | — |

---

## 0 — Comprendre l'organisation des dossiers

L'architecture est **Feature-First en couches** : le code est rangé **par
fonctionnalité métier**, pas par type technique. Trois dossiers seulement.

```
lib/
├── main.dart          Point d'entrée : démarre les services puis l'application
│
├── core/              ── SOCLE TECHNIQUE — ne connaît AUCUN métier ──
│   ├── constants/     Palette de couleurs de la charte graphique
│   ├── navigation/    Déclaration des routes + barre de navigation du bas
│   ├── services/      Client HTTP, session locale, connectivité réseau
│   ├── theme/         Thème Material global et styles de texte
│   ├── utils/         Adaptation aux tailles d'écran
│   └── widgets/       Petits composants réutilisés partout (snackbar, bandeau…)
│
├── features/          ── LES ÉCRANS, un dossier par domaine métier ──
│   ├── auth/          Présentation initiale + connexion
│   ├── inbox/         Conversations, chat, notifications, commentaires
│   ├── payments/      Liens de paiement et transactions
│   ├── profile/       Profil utilisateur et canaux connectés
│   └── stats/         Tableau de bord
│
└── shared/            ── CE QUI EST PARTAGÉ ENTRE PLUSIEURS ÉCRANS ──
    ├── services/      Appels à l'API Score360 (un fichier par domaine)
    ├── models/        Structures de données (traduction du JSON de l'API)
    └── mock/          Données de démonstration + définition de certains modèles
```

### La règle de circulation à respecter

```
  features/  ──appelle──▶  shared/services/  ──appelle──▶  API Score360
     │                            │
     └──utilise──▶  core/  ◀──utilise──┘
```

**Un écran ne parle jamais directement au réseau.** Il passe toujours par un
service de `shared/services/`. C'est cette règle qui permet d'ajouter une
fonctionnalité sans casser le reste.

### Signification de chaque fichier de `core/`

| Chemin | Rôle |
|---|---|
| `core/constants/app_colors.dart` | Toutes les couleurs de la charte. **Jamais de couleur écrite en dur ailleurs.** |
| `core/navigation/app_router.dart` | **Liste de toutes les pages de l'application** et de leurs adresses (`/inbox`, `/payments`…). C'est le premier fichier à ouvrir pour ajouter un écran. |
| `core/navigation/app_shell.dart` | La barre de navigation du bas (4 onglets + bouton ✚) et le menu d'actions rapides. |
| `core/services/api_client.dart` | **Le client HTTP unique.** Contient l'adresse du serveur, ajoute automatiquement le jeton d'authentification à chaque requête et renouvelle la session quand elle expire. |
| `core/services/session_service.dart` | Mémorise localement la session (jetons, nom, email, organisation) pour que l'utilisateur reste connecté entre deux ouvertures. |
| `core/services/network_service.dart` | Surveille la connexion internet toutes les 5 secondes. |
| `core/services/navigation_service.dart` | Permet de naviguer depuis un endroit qui n'est pas un écran (ex. le tap sur une notification). |
| `core/theme/app_theme.dart` | Le thème global : couleurs, forme des boutons, apparence des champs. |
| `core/theme/app_text_styles.dart` | Les styles de texte (titres, corps, libellés) en police Outfit. |
| `core/utils/responsive.dart` | Calcule les tailles selon l'écran du téléphone. |
| `core/widgets/app_snackbar.dart` | Les messages de succès et d'erreur, uniformisés. |
| `core/widgets/network_banner.dart` | Le bandeau « hors connexion » en haut de l'écran. |
| `core/widgets/shimmer_box.dart` | Les rectangles gris animés affichés pendant un chargement. |

### Signification de chaque fichier de `shared/`

| Chemin | Rôle |
|---|---|
| `shared/services/auth_service.dart` | Connexion, activation de compte, mot de passe oublié |
| `shared/services/inbox_service.dart` | Conversations, messages, envois, cache, indicateur de saisie |
| `shared/services/websocket_service.dart` | La connexion permanente qui reçoit les événements en temps réel |
| `shared/services/catalog_service.dart` | Produits du catalogue et canaux connectés de l'organisation |
| `shared/services/payment_service.dart` | Création, consultation et annulation des liens de paiement |
| `shared/services/comments_service.dart` | Publications et commentaires Facebook / Instagram / TikTok |
| `shared/services/stats_service.dart` | Tableau de bord |
| `shared/services/notification_service.dart` | Notifications push (Firebase) et leur historique |
| `shared/services/livreur_service.dart` | ⚪ Recherche de livreurs — **données de démonstration uniquement** |
| `shared/models/payment_link.dart` | Un lien de paiement tel que l'API le renvoie |
| `shared/models/dashboard_model.dart` | Les données du tableau de bord |
| `shared/models/notification_model.dart` | Une notification |
| `shared/models/lien_paiement_model.dart` | ⚪ Un lien de paiement avec livraison (modèle interne) |
| `shared/models/livreur_model.dart` | ⚪ Un livreur |
| `shared/mock/threads_mock.dart` | **Contient le modèle `Thread`** (une conversation) + conversations d'exemple |
| `shared/mock/messages_mock.dart` | **Contient le modèle `Message`** + messages d'exemple |
| `shared/mock/publications_mock.dart` | **Contient les modèles `Publication` et `PublicationComment`** + exemples |
| `shared/mock/products_mock.dart` | ⚪ Produits d'exemple (encore utilisés par le devis rapide) |
| `shared/mock/payments_mock.dart`, `stats_mock.dart`, `livreurs_mock.dart`, `delivery_mock.dart`, `users_mock.dart` | Données d'exemple servant de repli en développement |

> ⚠️ **Point d'attention pour la suite** : les modèles `Thread`, `Message`,
> `Publication` sont définis dans `shared/mock/` alors qu'ils devraient être dans
> `shared/models/`. C'est un héritage du démarrage du projet. Les déplacer est
> une amélioration possible mais elle touche une trentaine de fichiers.

---

## 1 — Démarrage de l'application

**Chemin : `lib/main.dart`** (34 lignes)

Quatre opérations dans l'ordre, avant que le premier écran s'affiche :

| Ordre | Action | Fichier appelé |
|---|---|---|
| 1 | Initialise Firebase | `firebase_core` |
| 2 | Recharge la session enregistrée sur le téléphone | `core/services/session_service.dart` |
| 3 | Prépare le client HTTP (adresse du serveur, jeton, délais) | `core/services/api_client.dart` |
| 4 | Démarre la surveillance réseau et les notifications | `core/services/network_service.dart`, `shared/services/notification_service.dart` |

✅ **Reconnexion automatique** — si un jeton valide existe, l'utilisateur arrive
directement dans l'inbox sans repasser par la connexion.

---

## 2 — Présentation initiale (onboarding)

**Chemin : `lib/features/auth/onboarding/onboarding_screen.dart`** (1 124 lignes)

| Fonctionnalité | État |
|---|---|
| 4 diapositives faites défiler horizontalement | ✅ |
| Indicateur de progression (points) | ✅ |
| Bouton « Passer » sur les 3 premières | ✅ |
| Mémorisation « présentation déjà vue » — ne se réaffiche jamais | ✅ `session_service.dart` |
| Barre de statut adaptée au fond de chaque diapositive | ✅ |

**Dossier annexe : `lib/features/auth/onboarding/painters/`** — trois fichiers
(`slide1_painter.dart`, `slide2_painter.dart`, `slide3_painter.dart`) qui
**dessinent les illustrations en code** plutôt que d'utiliser des images.

---

## 3 — Connexion et mot de passe

**Dossier : `lib/features/auth/login/`** — 6 écrans
**Service : `lib/shared/services/auth_service.dart`** (319 lignes)

| Écran | Chemin du fichier | Fonctionnalité | État |
|---|---|---|---|
| Étape 1 | `login_page1_screen.dart` | Saisie de l'identifiant (email ou téléphone) | ✅ |
| Étape 2 | `login_page2_screen.dart` | Saisie du mot de passe → `POST /auth/login` | ✅ |
| Activation | `set_password_screen.dart` | Premier mot de passe d'un compte invité → `POST /auth/first-login` | ✅ |
| Mot de passe oublié | `forgot_password_screen.dart` | Demande d'un code par email | ✅ |
| Code de vérification | `otp_screen.dart` | Saisie du code à 6 chiffres + renvoi | ✅ |
| Nouveau mot de passe | `reset_password_screen.dart` | Définition du nouveau mot de passe | ✅ |

### Ce que la connexion fait en coulisses

1. `POST /auth/login` → jetons + profil de l'utilisateur
2. `GET /auth/me` → identifiant de l'organisation (**indispensable** : presque
   toutes les autres requêtes en ont besoin)
3. Enregistrement du jeton Firebase pour recevoir les notifications

✅ **Gestion fine des erreurs** — l'identifiant est masqué à l'écran, les messages
d'erreur du serveur sont traduits en français, et un compte non activé est
redirigé automatiquement vers l'écran d'activation.

---

## 4 — Navigation générale

**Chemins :**
- `lib/core/navigation/app_router.dart` (212 lignes) — **la liste de toutes les pages**
- `lib/core/navigation/app_shell.dart` (297 lignes) — la barre du bas

### Les 15 adresses déclarées

| Adresse | Écran | Barre du bas ? |
|---|---|---|
| `/onboarding` | Présentation initiale | non |
| `/login` + `/login/password` + `/login/set-password` | Connexion | non |
| `/forgot-password`, `/otp-verification`, `/reset-password`, `/set-password` | Mot de passe | non |
| **`/inbox`** | Liste des conversations | **oui — onglet 1** |
| **`/stats`** | Tableau de bord | **oui — onglet 2** |
| **`/payments`** | Liste des paiements | **oui — onglet 3** |
| **`/profile`** | Profil | **oui — onglet 4** |
| `/inbox/:threadId` | Une conversation | non (plein écran) |
| `/create-link` | Création d'un lien de paiement | non (plein écran) |
| `/payment-detail` | Détail d'une transaction | non (plein écran) |

### La barre du bas et le bouton ✚

✅ 5 emplacements affichés pour 4 onglets réels — le 3ᵉ est le bouton ✚ vert, qui
n'est pas un onglet mais ouvre une feuille d'actions rapides :

| Action rapide | Destination | État |
|---|---|---|
| Nouvelle conversation | `/inbox` | ⚠️ ramène à la liste, ne crée rien |
| Nouveau lien de paiement | `/create-link` | ✅ |
| Voir les stats | `/stats` | ✅ |

✅ **L'état de chaque onglet est préservé** quand on passe d'un onglet à l'autre
(technique `StatefulShellRoute.indexedStack`).

✅ **Protection des écrans** — toute adresse hors connexion redirige vers
`/login` si l'utilisateur n'est pas connecté.

---

## 5 — Inbox : la liste des conversations

**Chemin : `lib/features/inbox/inbox_screen.dart`** (1 830 lignes)
**Service : `lib/shared/services/inbox_service.dart`**

| Fonctionnalité | État | Détail |
|---|---|---|
| Liste unifiée de toutes les conversations | ✅ | `GET /inbox/threads` |
| Recherche par nom de contact | ✅ | filtrage local |
| Filtres par canal (WhatsApp, SMS, Email, Facebook, Instagram, TikTok) | ✅ | |
| Filtre « non lus » | ✅ | |
| Feuille de filtres détaillés | ✅ | |
| Compteur de messages non lus par conversation | ✅ | |
| Tirer vers le bas pour rafraîchir | ✅ | |
| **Défilement infini** — charge 50 conversations de plus en bas de liste | ✅ | |
| **Affichage instantané puis rafraîchissement discret** | ✅ | cache de 3 minutes |
| Basculer sur la vue Commentaires | ✅ | `GET /comments/.../posts` |
| Cloche de notifications avec compteur | ✅ | |
| Message d'erreur avec bouton « Réessayer » | ✅ | |
| Indicateur « en train d'écrire » par conversation | ✅ | expire après 7 s |

### La stratégie d'affichage rapide (à connaître avant de modifier)

```
Ouverture de l'inbox
   │
   ├─ Données en cache et de moins de 3 min ?
   │     OUI → affichage IMMÉDIAT (aucun temps d'attente)
   │            puis appel serveur discret en arrière-plan,
   │            et mise à jour seulement si quelque chose a changé
   │     NON  → roue de chargement, puis appel serveur
```

---

## 6 — Le temps réel (WebSocket)

**Chemin : `lib/shared/services/websocket_service.dart`** (181 lignes)

Une **connexion permanente** au serveur qui reçoit les événements sans que
l'application ait besoin de demander.

`wss://ws.score360.africa/api/v1.2/inbox/ws`

### Les 9 événements traités

| Événement reçu | Effet dans l'application | Écran concerné |
|---|---|---|
| `new_message` | Le message apparaît instantanément | inbox + chat |
| `message_status_updated` | Les coches passent de ✓ à ✓✓ puis bleues | chat |
| `messages_read` | Marque les messages comme lus | chat |
| `contact_typing` | Affiche « en train d'écrire… » | inbox + chat |
| `contact_presence_updated` | Affiche « vu il y a X min » | chat |
| `thread_assigned` / `thread_unassigned` | Met à jour l'assignation | inbox |
| `thread_resolved` | Marque la conversation comme résolue | inbox |
| `new_comment` | Notification locale + rafraîchit les publications | inbox |
| `inbound_call` | Signale un appel entrant | chat |

✅ **Robustesse** : reconnexion automatique après 5 secondes, signal de vie
toutes les 30 secondes, déconnexion forcée si le serveur refuse le jeton, et
**jeton masqué dans les journaux** pour ne pas l'exposer.

---

## 7 — Le chat : une conversation

**Chemin : `lib/features/inbox/chat_screen.dart`** (6 659 lignes — **le plus gros fichier du projet**)

### 7.1 Envois

| Fonctionnalité | État | Détail |
|---|---|---|
| Envoyer un message texte | ✅ | `POST /inbox/{canal}/messages` |
| Insérer des émojis | ✅ | sélecteur intégré |
| Partager sa position GPS | ✅ | via `geolocator` |
| **Envoyer un carrousel de produits** | ✅ | jusqu'à 10 produits du catalogue |
| Créer un lien de paiement depuis la conversation | ✅ | |
| **Signaler « en train d'écrire » au client** | ✅ | Messenger uniquement |
| Envoyer une photo | ✅ | `POST /media/upload` (téléversement) puis `POST /inbox/{canal}/messages` |
| Devis rapide (produit + quantité + prix) | ⚪ | produits d'exemple |
| Message promotionnel, demande d'avis, suivi de commande | ⚪ | |

### 7.2 Affichage des messages

✅ **10 types de bulles différentes**, chacune avec son apparence :

| Type | Ce qui est affiché |
|---|---|
| Texte | Bulle classique, coin aplati côté émetteur |
| **Image** | ✅ Vraie image, réseau ou locale, avec barre de progression |
| Lien de paiement | Carte violette avec montant et statut |
| Position | Carte avec coordonnées |
| Carrousel | Aperçu du catalogue envoyé |
| Contact | Fiche de contact |
| Audio / Vidéo / Document | ⚠️ Bulle affichée, **lecture non disponible** |
| Aperçu de lien | Vignette du site |

✅ **Coches de statut** : horloge (en cours) → ✓ (envoyé) → ✓✓ gris (reçu) →
✓✓ bleu (lu)

✅ **Envoi optimiste** : le message apparaît immédiatement, avant la réponse du
serveur, et est retiré avec un message d'erreur clair si l'envoi échoue.

### 7.3 Gestion des messages

| Fonctionnalité | État |
|---|---|
| Charger les messages plus anciens en remontant | ✅ |
| Menu contextuel par appui long | ✅ |
| Copier un message | ✅ |
| Sélection multiple | ✅ |
| Voir les informations d'un message (statut, horodatage) | ✅ |
| Répondre en citant, étoiler, épingler, modifier, supprimer, transférer, réagir | ⚪ |

### 7.4 Gestion de la conversation

| Fonctionnalité | État |
|---|---|
| Rechercher dans la conversation | ✅ |
| Voir les messages étoilés | ✅ |
| Consulter la fiche du client | ✅ |
| Statistiques de la conversation | ✅ |
| Exporter la conversation en texte | ✅ |
| Accusés de lecture automatiques | ✅ |
| Mettre en sourdine, bloquer, supprimer la conversation | ⚪ |
| Appel audio et vidéo | ⚪ |

---

## 8 — Le catalogue produits

**Chemin : `lib/shared/services/catalog_service.dart`** (155 lignes)

| Fonctionnalité | État |
|---|---|
| Charger les produits de l'organisation | ✅ `GET /organizations/{id}/products` |
| Ne garder que les produits actifs | ✅ |
| Filtrer Tous / Produits / Services | ✅ |
| Cache de 30 minutes partagé par tous les écrans | ✅ |
| Nettoyage du HTML dans les descriptions | ✅ |
| Charger les canaux connectés | ✅ `GET /organizations/{id}/accounts` |

**Trois écrans consomment ce service** — le chat (carrousel), la création de lien
en plein écran, et la création de lien en feuille modale. Le cache étant partagé,
le second écran ouvert affiche les produits instantanément.

---

## 9 — Les paiements

**Dossier : `lib/features/payments/`** — 4 fichiers
**Service : `lib/shared/services/payment_service.dart`** (263 lignes)

| Écran | Chemin | Rôle |
|---|---|---|
| Liste | `payments_screen.dart` (695 l.) | Toutes les transactions + export |
| Création plein écran | `create_link_screen.dart` (1 818 l.) | Parcours en 3 étapes, depuis le bouton ✚ ou le chat |
| Création en feuille | `create_link_sheet.dart` (1 667 l.) | Même parcours, depuis l'écran Paiements |
| Détail | `transaction_detail_screen.dart` (421 l.) | Détail, annulation, reçu PDF |

### Le parcours de création en 3 étapes

```
Étape 1 — Client        Étape 2 — Produit         Étape 3 — Livraison + Paiement
choisir le contact  →   choisir dans le        →   livraison à domicile ?
(GET /inbox/threads)    catalogue réel             adresse + mode de paiement
                        (montant pré-rempli)       parmi 7 fournisseurs
                                                          ↓
                                          POST /payment-links/.../product
```

| Fonctionnalité | État |
|---|---|
| Liste des liens avec statut coloré (Payé / En attente / Créé / Expiré) | ✅ |
| Filtres par statut | ✅ |
| Générer un lien de paiement | ✅ |
| 7 fournisseurs : Wave, Orange Money, MTN, Moov, Djamo, CinetPay, FedaPay | ✅ |
| Copier et partager le lien | ✅ |
| Annuler un lien non payé | ✅ |
| Reçu au format PDF | ✅ |
| Export CSV et Excel avec filtres de période | ✅ |
| Livraison à domicile (adresse complète) | ⚠️ saisie enregistrée, frais fixes à 2 000 F |
| Recherche d'un livreur | ⚪ simulation de 2 secondes, livreur toujours identique |

> ⚠️ **À savoir avant d'intervenir** : les deux écrans de création font
> **exactement la même chose** avec deux fichiers séparés (3 485 lignes au
> total). Toute modification du parcours doit être faite **deux fois**. Les
> fusionner est l'amélioration la plus rentable du projet.

---

## 10 — Les commentaires des réseaux sociaux

**Chemins :**
- `lib/features/inbox/inbox_screen.dart` — l'onglet « Commentaires » de l'inbox
- `lib/features/inbox/publication_detail_screen.dart` (532 lignes) — une publication
- `lib/shared/services/comments_service.dart` (149 lignes)

| Fonctionnalité | État |
|---|---|
| Liste des publications de l'organisation | ✅ `GET /comments/.../posts` |
| Filtrer par réseau (Facebook, Instagram, TikTok) | ✅ |
| Lire les commentaires d'une publication | ✅ `GET /comments/organizations/{id}` |
| **Répondre publiquement à un commentaire** | ✅ `POST /comments/{id}/reply` |
| Affichage en arborescence (réponses imbriquées) | ✅ |
| Annuler le ciblage d'une réponse en cours | ✅ |

✅ La réponse n'apparaît dans le fil **qu'après confirmation du serveur** — une
réponse rejetée par Facebook ne s'affiche donc jamais comme publiée.

---

## 11 — Les statistiques

**Chemin : `lib/features/stats/stats_screen.dart`** (677 lignes)
**Service : `lib/shared/services/stats_service.dart`** (54 lignes)

Un seul appel : `GET /analytics/organizations/{id}/dashboard`

| Élément affiché | État |
|---|---|
| Carte Revenus + taux d'évolution | ✅ |
| Carte Conversations + évolution | ✅ |
| Carte Taux de réponse + évolution | ✅ |
| **Une baisse s'affiche en rouge avec une flèche descendante** | ✅ |
| Graphique en anneau : répartition par canal | ✅ dessiné à la main |
| Courbe d'évolution des revenus | ✅ dessinée à la main |
| Sélecteur de période : 7 jours / 30 jours / ce mois | ✅ |
| Message « Aucune donnée pour cette période » | ✅ |
| Écran d'erreur avec « Réessayer » | ✅ |

✅ **Plus aucune donnée fabriquée** — si le serveur ne répond pas, l'écran
affiche une erreur au lieu de chiffres inventés.

⚠️ **Non exploité** : la réponse du serveur contient aussi `signals`, `campaigns`,
`activity` et `tasks`, déjà lues par `shared/models/dashboard_model.dart` mais
affichées nulle part. **C'est le gain le plus rapide pour enrichir cet écran :
les données arrivent déjà, il ne manque que l'affichage.**

---

## 12 — Les notifications push

**Chemins :**
- `lib/shared/services/notification_service.dart` (287 lignes) — Firebase
- `lib/features/inbox/notifications_screen.dart` (457 lignes) — l'historique
- `lib/features/inbox/widgets/notification_item.dart` (441 lignes) — une ligne de la liste

> Ce module utilise un **second serveur**, distinct de l'API Score360 :
> `e-signal-v2-backend-notifications.onrender.com`

| Fonctionnalité | État |
|---|---|
| Enregistrement du téléphone auprès du serveur après connexion | ✅ |
| Réception des notifications (application ouverte, en arrière-plan, fermée) | ✅ |
| Ouverture de la bonne conversation au tap sur la notification | ✅ |
| Historique groupé par période (Aujourd'hui, Hier…) | ✅ |
| Filtres : Tous / Messages / Appels / Paiements | ✅ |
| **Réponse rapide sans ouvrir la conversation** | ✅ |
| Rappeler le contact depuis une notification | ✅ |
| Marquer comme lue, tout marquer comme lu | ✅ Firestore |
| Archiver / supprimer par glissement latéral | ✅ Firestore |
| Compteur sur la cloche de l'inbox | ✅ |

---

## 13 — Le profil

**Chemin : `lib/features/profile/profile_screen.dart`** (489 lignes)

| Élément | Source de la donnée | État |
|---|---|---|
| Nom, initiales, email, téléphone | Réponse de `POST /auth/login`, enregistrée sur le téléphone | ✅ |
| Niveau KYC, statut du compte | idem | ✅ |
| **Liste des canaux connectés** | `GET /organizations/{id}/accounts` | ✅ |
| Déconnexion avec confirmation | local | ✅ |
| Modifier mes informations | — | ❌ « Bientôt disponible » |
| Changer le mot de passe | — | ❌ « Bientôt disponible » |
| Connecter un canal | — | ❌ « Bientôt disponible » |
| Aide & Support | — | ❌ « Bientôt disponible » |
| Interrupteur Notifications | — | ⚪ non enregistré |
| Photo de profil | — | ⚪ icône décorative sans action |

⚠️ Les informations personnelles sont **figées à la date de connexion**. Si le
niveau KYC change côté back-office, le profil affiche l'ancienne valeur jusqu'à
la prochaine reconnexion.

---

## 14 — Récapitulatif : les 28 endpoints intégrés

**Serveur principal** : `https://ws.score360.africa/api/v1.2`

| Domaine | Méthode et adresse | Fichier |
|---|---|---|
| **Auth** | `POST /auth/login` | `shared/services/auth_service.dart` |
| | `POST /auth/first-login` | idem |
| | `GET /auth/me` | idem |
| | `POST /auth/refresh` | `core/services/api_client.dart` (automatique) |
| | `POST /auth/forgot-password/request-otp` | `auth_service.dart` |
| | `PATCH /auth/forgot-password/reset` | idem |
| | `POST /auth/forgot-password` | idem — ⚠️ codé, jamais appelé |
| **Inbox** | `GET /inbox/threads` | `shared/services/inbox_service.dart` |
| | `GET /inbox/threads/{id}/messages` | idem |
| | `POST /inbox/{canal}/messages` | idem (texte, média **et** carrousel) |
| | `POST /inbox/threads/{id}/read` | idem |
| | `POST /inbox/messenger/sender-action` | idem |
| | `WSS /inbox/ws` | `shared/services/websocket_service.dart` |
| **Organisation** | `GET /organizations/{id}/products` | `shared/services/catalog_service.dart` |
| | `GET /organizations/{id}/accounts` | idem |
| **Paiements** | `GET /payment-links/organizations/{id}` | `shared/services/payment_service.dart` |
| | `POST /payment-links/organizations/{id}/product` | idem |
| | `GET /payment-links/organizations/{id}/{lien}` | idem |
| | `POST /payment-links/organizations/{id}/{lien}/cancel` | idem |
| | `GET /payment-links/organizations/{id}/summary` | idem — ⚠️ codé, jamais appelé |
| **Commentaires** | `GET /comments/organizations/{id}/posts` | `shared/services/comments_service.dart` |
| | `GET /comments/organizations/{id}` | idem |
| | `POST /comments/{id}/reply` | idem |
| | `POST /comments/{id}/like` | idem — ⚠️ codé, jamais appelé |
| | `PATCH /comments/{id}/status` | idem — ⚠️ codé, jamais appelé |
| **Statistiques** | `GET /analytics/organizations/{id}/dashboard` | `shared/services/stats_service.dart` |
| **Notifications** | `POST /api/notifications/register-token` | `shared/services/notification_service.dart` |
| | `GET /api/notifications/history/{user}` | idem |

**Synthèse** : 25 endpoints REST Score360 + 1 connexion WebSocket + 2 endpoints
du serveur de notifications = **28 intégrations**, dont **4 déjà codées mais
sans bouton dans l'interface** — un bouton suffirait à les activer.

---

## 15 — Où ajouter une nouvelle fonctionnalité

### La recette en 4 étapes

| Étape | Fichier à modifier ou créer | Ce qu'on y fait |
|---|---|---|
| **1. Le contrat** | `lib/shared/services/<domaine>_service.dart` | Déclarer la méthode avec l'adresse de l'API en commentaire |
| **2. L'appel réseau** | même fichier, dans la classe `Http…Service` | Écrire l'appel, **vérifier le code de retour**, lever une exception claire |
| **3. L'écran** | `lib/features/<domaine>/<nom>_screen.dart` | Créer l'écran avec ses 3 états : chargement, erreur + « Réessayer », données |
| **4. L'adresse** | `lib/core/navigation/app_router.dart` | Ajouter la route — **dans** le `StatefulShellRoute` si l'écran garde la barre du bas, **en dehors** s'il est plein écran |

### Les 6 règles à ne pas enfreindre

1. **Aucun appel réseau dans `features/`** — toujours passer par `shared/services/`.
   *(Aujourd'hui respecté à 100 % : zéro appel HTTP dans les écrans.)*
2. **Aucune couleur écrite en dur** — utiliser `AppColors.xxx`.
3. **Toujours vérifier `resp.statusCode`** — le client HTTP est configuré pour ne
   jamais lever d'exception tout seul, y compris sur une erreur 500.
4. **Jamais de données d'exemple en cas d'erreur** — afficher une erreur avec
   bouton « Réessayer ». *(Nettoyé sur tout le projet.)*
5. **Trois états obligatoires par écran** : chargement, erreur, données.
6. **`flutter analyze` doit rester à 0 anomalie** avant chaque livraison.

### Les 5 fonctionnalités les plus rapides à ajouter

Classées par rapport effort / bénéfice :

| # | Fonctionnalité | Pourquoi c'est rapide | Fichiers concernés |
|---|---|---|---|
| 1 | **Enrichir les statistiques** | Les données `signals`, `campaigns`, `activity`, `tasks` sont **déjà reçues et décodées** — il ne manque que l'affichage | `features/stats/stats_screen.dart` |
| 2 | **Aimer un commentaire** et **changer son statut** | Les deux appels API sont **déjà écrits et testés**, il manque juste un bouton | `features/inbox/publication_detail_screen.dart` |
| 3 | **Récapitulatif des paiements** | L'appel `GET .../summary` est **déjà écrit** | `features/payments/payments_screen.dart` |
| 4 | **Fusionner les deux écrans de création de lien** | Supprime 1 600 lignes dupliquées et divise par deux le coût de toute évolution future | `features/payments/create_link_*.dart` |
| 5 | **Envoi réel de photos** | L'affichage et le choix de l'image fonctionnent déjà, il manque l'envoi au serveur | `features/inbox/chat_screen.dart` + `shared/services/inbox_service.dart` |

### Les chantiers nécessitant le backend

| Fonctionnalité | Ce qui manque |
|---|---|
| Modifier son profil, changer son mot de passe | Endpoints correspondants |
| Connecter un canal depuis l'application | Parcours d'autorisation Meta / TikTok |
| Appels audio et vidéo | Infrastructure temps réel dédiée |
| Modifier / supprimer / épingler un message | Endpoints correspondants |
| Recherche réelle de livreurs | Service de livraison |
| Lecture des audio, vidéo et documents reçus | `GET /inbox/messages/{id}/media` |

---

## Chiffres clés

| | |
|---|---|
| Fichiers Dart | **58** |
| Lignes de code | **23 014** |
| Écrans | **17** |
| Services | **9** |
| Endpoints intégrés | **28** |
| Événements temps réel gérés | **9** |
| Types de bulles de message | **10** |
| Fournisseurs de paiement | **7** |
| Canaux de messagerie | **6** |
| Bibliothèques externes | **22** (toutes libres et gratuites) |
| Anomalies `flutter analyze` | **0** |
