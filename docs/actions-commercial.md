# Liste des actions possibles pour le commercial

> Inventaire exhaustif des actions déclenchables depuis l'interface de l'application,
> relevées écran par écran dans le code (branche `feature/retouch`).
>
> **Légende** : ⚪ = l'action n'émet aucune requête réseau, son effet reste limité à
> l'affichage sur le téléphone.

---

## A. Premier lancement et authentification

| # | Action |
|---|---|
| 1 | Parcourir les 3 écrans de présentation de l'application |
| 2 | Passer la présentation |
| 3 | Saisir son identifiant (email ou numéro de téléphone) |
| 4 | Saisir son mot de passe |
| 5 | Se connecter |
| 6 | Activer son compte invité en définissant son premier mot de passe |
| 7 | Demander la réinitialisation de son mot de passe |
| 8 | Saisir le code de vérification reçu par email |
| 9 | Demander le renvoi du code de vérification |
| 10 | Définir un nouveau mot de passe |
| 11 | Se déconnecter |

## B. Navigation générale

| # | Action |
|---|---|
| 12 | Basculer entre les 4 onglets : Inbox, Stats, Paiements, Profil |
| 13 | Ouvrir le menu d'actions rapides (bouton +) |
| 14 | Lancer « Nouvelle conversation » depuis ce menu |
| 15 | Lancer « Nouveau lien de paiement » depuis ce menu |
| 16 | Lancer « Voir les stats » depuis ce menu |

## C. Liste des conversations

| # | Action |
|---|---|
| 17 | Consulter la liste unifiée de toutes les conversations |
| 18 | Rechercher une conversation par nom de contact |
| 19 | Filtrer par canal : Tous, WhatsApp, SMS, Email, Facebook, Instagram, TikTok |
| 20 | Filtrer les conversations non lues |
| 21 | Basculer sur la vue Commentaires |
| 22 | Ouvrir la feuille de filtres détaillés (canal + non lus uniquement) |
| 23 | Rafraîchir la liste en tirant vers le bas |
| 24 | Ouvrir une conversation |
| 25 | Ouvrir l'écran des notifications (icône cloche) |
| 26 | Relancer le chargement après une erreur |

## D. Conversation — envois

| # | Action |
|---|---|
| 27 | Envoyer un message texte |
| 28 | Insérer des émojis dans le message |
| 29 | ⚪ Envoyer une photo depuis la galerie |
| 30 | Partager sa position GPS |
| 31 | Envoyer un carrousel de produits |
| 32 | Filtrer le catalogue : Tous / Produits / Services |
| 33 | Sélectionner jusqu'à 10 produits |
| 34 | ⚪ Envoyer un devis rapide (produit + quantité + prix) |
| 35 | ⚪ Envoyer un message promotionnel |
| 36 | ⚪ Demander un avis au client |
| 37 | ⚪ Envoyer une carte de suivi de commande |
| 38 | Créer un lien de paiement directement depuis la conversation |
| 39 | Ouvrir un lien présent dans un message (carte, paiement) |

## E. Conversation — gestion des messages

| # | Action |
|---|---|
| 40 | Faire défiler vers le haut pour charger les messages plus anciens |
| 41 | Ouvrir le menu contextuel d'un message (appui long) |
| 42 | Copier le contenu d'un message |
| 43 | ⚪ Répondre à un message en le citant |
| 44 | ⚪ Marquer un message d'une étoile |
| 45 | ⚪ Épingler un message |
| 46 | ⚪ Modifier un de ses propres messages |
| 47 | ⚪ Supprimer un ou plusieurs messages |
| 48 | ⚪ Transférer un message vers une autre conversation |
| 49 | ⚪ Réagir à un message par un émoji |
| 50 | Consulter les informations d'un message (statut, horodatage) |
| 51 | Activer la sélection multiple de messages |
| 52 | Créer un lien de paiement à partir d'un message reçu |

## F. Conversation — gestion du fil

| # | Action |
|---|---|
| 53 | Rechercher un message dans la conversation ouverte |
| 54 | Consulter les messages marqués d'une étoile |
| 55 | Consulter la fiche du client |
| 56 | Consulter les statistiques de la conversation |
| 57 | ⚪ Mettre la conversation en sourdine |
| 58 | ⚪ Bloquer le contact |
| 59 | ⚪ Supprimer la conversation |
| 60 | Exporter la conversation au format texte (partage) |
| 61 | ⚪ Lancer un appel audio |
| 62 | ⚪ Lancer un appel vidéo |
| 63 | Revenir à la liste des conversations |

## G. Commentaires des réseaux sociaux

| # | Action |
|---|---|
| 64 | Consulter les publications de l'organisation |
| 65 | Filtrer les publications par réseau : Facebook, Instagram, TikTok |
| 66 | Ouvrir une publication et lire ses commentaires |
| 67 | Répondre publiquement à un commentaire |
| 68 | Annuler le ciblage d'une réponse en cours |

## H. Paiements

| # | Action |
|---|---|
| 69 | Consulter la liste des liens de paiement |
| 70 | Ouvrir le détail d'une transaction |
| 71 | Créer un lien : sélectionner le client destinataire |
| 72 | Créer un lien : sélectionner le produit (montant pré-rempli) |
| 73 | Créer un lien : filtrer le catalogue Tous / Produits / Services |
| 74 | Créer un lien : activer la livraison à domicile |
| 75 | Créer un lien : saisir l'adresse (destinataire, téléphone, commune, quartier, secteur) |
| 76 | ⚪ Relancer la recherche d'un livreur |
| 77 | Créer un lien : choisir le mode de paiement parmi 7 fournisseurs |
| 78 | Générer le lien de paiement |
| 79 | Copier le lien généré |
| 80 | Partager le lien depuis le détail de la transaction |
| 81 | Annuler un lien de paiement non encore payé |
| 82 | Télécharger le reçu au format PDF |
| 83 | Exporter les transactions au format CSV |
| 84 | Exporter les transactions au format Excel |
| 85 | Filtrer l'export : Toutes, Payées, En attente, Ce mois, Ce trimestre |
| 86 | Rafraîchir la liste des transactions |

## I. Statistiques

| # | Action |
|---|---|
| 87 | Consulter le tableau de bord (revenus, conversations, taux de réponse) |
| 88 | Consulter la répartition des conversations par canal |
| 89 | Changer la période : 7 derniers jours, 30 derniers jours, ce mois |
| 90 | Relancer le chargement après une erreur |

## J. Profil

| # | Action |
|---|---|
| 91 | Consulter ses informations (nom, email, téléphone, niveau KYC, statut) |
| 92 | Consulter la liste des canaux connectés |
| 93 | ⚪ Activer ou désactiver les notifications |
| 94 | Se déconnecter |

## K. Notifications

| # | Action |
|---|---|
| 95 | Consulter l'historique des notifications, groupé par période |
| 96 | Filtrer : Tous, Messages, Appels, Paiements |
| 97 | Ouvrir la conversation concernée depuis une notification |
| 98 | Répondre rapidement sans ouvrir la conversation |
| 99 | Rappeler le contact depuis une notification |
| 100 | Marquer une notification comme lue |
| 101 | Marquer toutes les notifications comme lues |
| 102 | Archiver une notification (glissement latéral) |
| 103 | Supprimer une notification (glissement latéral) |
| 104 | Effacer toutes les notifications |

---

## Synthèse

| Catégorie | Nombre d'actions |
|---|---|
| Authentification et premier lancement | 11 |
| Navigation générale | 5 |
| Liste des conversations | 10 |
| Conversation — envois | 13 |
| Conversation — gestion des messages | 13 |
| Conversation — gestion du fil | 11 |
| Commentaires réseaux sociaux | 5 |
| Paiements | 18 |
| Statistiques | 4 |
| Profil | 4 |
| Notifications | 10 |
| **Total** | **104** |

Sur ces 104 actions, **19 sont marquées ⚪** : elles produisent un retour visuel mais
n'émettent aucune requête réseau.

---

## Actions annoncées mais indisponibles

Ces éléments sont présents à l'écran et signalent explicitement leur indisponibilité
(message « Bientôt disponible ») :

| Écran | Élément |
|---|---|
| Profil | Modifier mes informations |
| Profil | Changer le mot de passe |
| Profil | Connecter un canal |
| Profil | Aide & Support |

## Fonctions présentes dans le code mais sans point d'entrée dans l'interface

Aucun bouton ni geste ne les déclenche actuellement :

| Fonction | Service |
|---|---|
| Aimer un commentaire | `commentsService.likeComment()` |
| Changer le statut d'un commentaire | `commentsService.updateCommentStatus()` |
| Demander une réinitialisation par mot de passe oublié | `authService.forgotPassword()` — les écrans utilisent `requestOtp()` |
