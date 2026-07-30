# Contraintes fonctionnelles — Périmètre de l'application e-Signal

> Définition des **limites du système** au sens du cours UML n°2 § 2-1 :
> *« la première tâche consiste à définir les limites du système (c.-à-d. ce qui est
> inclus ou pas dans le système) »*.
>
> **Portée de ce document** : ce qui est présent ou absent **dans l'application
> mobile**, tel que constaté dans le code de la branche `feature/retouch`.
> Aucune hypothèse n'est faite sur l'état du backend.

---

## 1. Tableau de synthèse

| ✅ INCLUS dans l'application | ❌ EXCLU de l'application |
|---|---|
| Réception et affichage unifiés des conversations de 6 canaux (WhatsApp, Messenger, Instagram, TikTok, SMS, Email) | Prospection sortante : l'application ne permet pas d'initier une conversation avec un nouveau contact |
| Envoi de messages **texte** | Partage d'une fiche contact, d'un sondage ou de boutons de réponse rapide |
| Envoi de la position GPS du commercial | Affichage d'une carte dans l'application |
| Envoi d'un carrousel de produits (1 à 10 articles) | Envoi de plus de 10 produits en une fois |
| Consultation du catalogue produits | Création, modification, suppression d'un produit |
| Génération de liens de paiement mobile money (7 fournisseurs) | Modification d'un lien déjà créé, relance automatique du client |
| Consultation, annulation et export des transactions (CSV, Excel, reçu PDF) | Remboursement, paiement partiel ou échelonné |
| Consultation et réponse aux commentaires Facebook / Instagram / TikTok | Publication de nouveaux posts sur les réseaux sociaux |
| Affichage du tableau de bord (revenus, conversations, taux de réponse, canaux) | Export ou impression du tableau de bord |
| Authentification, activation d'un compte invité, réinitialisation du mot de passe par OTP | Création de comptes utilisateurs et d'organisations |
| Réception et gestion des notifications push | Réglage fin des notifications par canal ou par type |
| Consultation du profil et de la liste des canaux connectés | Modification du profil, changement de mot de passe, connexion d'un nouveau canal |
| Fonctionnement Android et iOS | Version web ou de bureau |
| Interface en français, montants en FCFA / XOF | Multilingue, multidevise |

---

## 2. Détail par domaine

### 2.1 Messagerie

| ✅ Inclus | ❌ Exclu |
|---|---|
| Liste unifiée des conversations, tous canaux confondus | Démarrer une conversation avec un contact qui n'a jamais écrit |
| Filtrage par canal, par messages non lus, par commentaires | Filtrage par commercial, par date, par étiquette |
| Recherche d'une conversation par nom de contact | Recherche portant sur le contenu de toutes les conversations |
| Consultation de l'historique, chargement par pages | Consultation des pièces jointes regroupées |
| Marquage des messages comme lus à l'ouverture | Marquer manuellement une conversation comme non lue |
| Envoi de messages texte avec émojis, partage de la position GPS | Partage d'une fiche contact, d'un sondage, de boutons de réponse rapide |
| Réception des messages en temps réel | Consultation hors connexion (seul un affichage temporaire du cache est possible) |
| Recherche dans une conversation ouverte | Recherche avancée (par date, par type de message) |
| Export d'une conversation au format texte | Export au format PDF |
| Consultation de la fiche du client et de son état de présence | Modification de la fiche client, ajout de notes internes |
| Lancement d'un appel via l'application téléphone du terminal | Appel intégré à l'application, appel vidéo, enregistrement d'appel |
| Affichage des indicateurs de saisie et de lecture | Envoi d'un indicateur de saisie vers le client |

### 2.2 Catalogue

| ✅ Inclus | ❌ Exclu |
|---|---|
| Consultation des produits **actifs** | Consultation des produits inactifs ou en brouillon |
| Filtrage entre produits et services | Recherche par mot-clé, tri par prix |
| Sélection de 1 à 10 produits en vue d'un envoi | Sélection de plus de 10 produits |
| Affichage de l'image, du nom, de la description, du prix et de la référence | Affichage des stocks, des variantes (taille, couleur), des remises |
| — | Création, modification, suppression d'un produit |
| — | Import du catalogue depuis un fichier |

### 2.3 Paiement

| ✅ Inclus | ❌ Exclu |
|---|---|
| Création d'un lien de paiement en 3 étapes : client → produit → mode de paiement | Paiement par carte bancaire, virement ou espèces |
| Choix parmi 7 fournisseurs (Wave, Orange Money, MTN Money, Moov Money, Djamo, CinetPay, FedaPay) | Relance automatique du client s'il ne paie pas |
| Insertion du lien dans la conversation, copie du lien | Remboursement, paiement partiel, paiement échelonné |
| Affichage des statuts : Créé / En attente / Payé / Expiré | Modification d'un lien déjà créé |
| Annulation d'un lien non encore payé | Notification du commerçant à l'échéance d'un lien |
| Téléchargement d'un reçu au format PDF | Édition d'une facture avec mentions légales et TVA |
| Export des transactions en CSV et en Excel | Envoi de l'export par email, connexion à un logiciel de comptabilité |
| Consultation du détail d'une transaction | Filtrage des transactions par client ou par produit |

### 2.4 Livraison

| ✅ Inclus | ❌ Exclu |
|---|---|
| Option de livraison à domicile lors de la création d'un lien (+2 000 FCFA) | Tarif variable selon la distance, le poids ou la zone |
| Saisie de l'adresse : destinataire, téléphone, commune, quartier, secteur | Vérification ou géolocalisation de l'adresse saisie |
| Affichage d'un livreur assigné (nom, note, délai estimé) | Suivi de la position du livreur en temps réel |
| — | Choix manuel du livreur parmi plusieurs propositions |
| — | Notification du livreur, acceptation ou refus de la course |
| ⚠️ *L'application affiche pour l'instant un livreur de démonstration : la recherche de livreur n'effectue aucun appel réseau.* | |

### 2.5 Commentaires des réseaux sociaux

| ✅ Inclus | ❌ Exclu |
|---|---|
| Consultation des publications de l'organisation | Publication d'un post, programmation de contenu |
| Consultation du fil de commentaires d'une publication | Détection automatique du spam, modération assistée |
| Réponse publique à un commentaire | Passage du commentaire en message privé |
| Mention « J'aime » sur un commentaire | Partage ou republication |
| Changement de statut : Nouveau / Répondu / Masqué | Suppression définitive d'un commentaire |

### 2.6 Statistiques

| ✅ Inclus | ❌ Exclu |
|---|---|
| Affichage des revenus, du nombre de conversations et du taux de réponse | Statistiques par commercial, par produit, par zone |
| Répartition des conversations par canal | Comparaison entre deux périodes |
| Courbe d'évolution des revenus | Projections, objectifs commerciaux |
| Choix de la période : 7 jours, 30 jours, mois en cours | Période personnalisée (dates au choix) |
| — | Export ou partage du tableau de bord |

### 2.7 Compte et sécurité

| ✅ Inclus | ❌ Exclu |
|---|---|
| Connexion par identifiant (email ou téléphone) puis mot de passe | Connexion biométrique, code PIN, double authentification |
| Activation d'un compte invité par définition du premier mot de passe | Création du compte lui-même |
| Réinitialisation du mot de passe par code OTP reçu par email | Réinitialisation par SMS |
| Maintien de la session sans reconnexion manuelle | Gestion de plusieurs appareils, déconnexion à distance |
| Déconnexion manuelle | Verrouillage automatique après une période d'inactivité |
| Consultation du profil : nom, email, téléphone, niveau KYC, statut | Modification des informations personnelles |
| Consultation de la liste des canaux connectés | Connexion d'un nouveau canal depuis l'application |
| Activation ou désactivation générale des notifications | Changement de mot de passe depuis le profil |
| — | Aide et support intégrés |
| — | Envoi de pièces justificatives pour la vérification KYC |
| — | Bascule entre plusieurs organisations |

### 2.8 Notifications

| ✅ Inclus | ❌ Exclu |
|---|---|
| Réception des notifications push : message, appel, paiement | Notifications par email ou par SMS |
| Historique groupé par période (aujourd'hui, hier, cette semaine, plus ancien) | Recherche dans l'historique des notifications |
| Filtrage par type : Tous / Messages / Appels / Paiements | Filtrage par conversation ou par client |
| Réponse rapide sans ouvrir la conversation | Réponse avec pièce jointe depuis la notification |
| Rappel du contact depuis la notification | Report d'une notification |
| Marquer comme lue, tout marquer, archiver, supprimer, tout effacer | Restauration d'une notification supprimée |

### 2.9 Travail en équipe

| ✅ Inclus | ❌ Exclu |
|---|---|
| Affichage de l'état d'affectation d'une conversation | **Assigner** une conversation à un commercial |
| Prise en compte automatique de la clôture d'une conversation | **Clôturer** ou **rouvrir** une conversation |
| — | Consultation de la liste des membres de l'équipe |
| — | Gestion des rôles et des droits d'accès |
| — | Notes internes ou discussion entre commerciaux sur une conversation |
| ⚠️ *L'application est informée qu'une conversation a été affectée ou clôturée et met sa liste à jour, mais elle n'offre aucun écran permettant de déclencher ces actions.* | |

---

## 3. Fonctionnalités présentes dans l'interface mais sans effet réel

⚠️ **Constat côté application** : les actions ci-dessous existent à l'écran et
affichent une confirmation au commercial, mais l'application **n'émet aucune requête
réseau** — l'effet reste donc limité à l'affichage sur le téléphone. Elles ne sont ni
pleinement incluses, ni exclues : c'est le périmètre à consolider.

| Action | Ce que fait réellement l'application |
|---|---|
| Envoyer une photo produit | Ajoute l'image au fil, en conservant le chemin du fichier sur le téléphone |
| Envoyer un devis rapide | Ajoute le message formaté au fil |
| Envoyer une promotion | Ajoute le message pré-rédigé au fil |
| Demander un avis client | Ajoute le message pré-rédigé au fil |
| Envoyer un suivi de commande | Ajoute une carte de suivi au fil |
| Transférer un message | Affiche une confirmation de transfert |
| Modifier un message | Modifie le texte dans la liste affichée |
| Supprimer un message | Retire le message de la liste affichée |
| Épingler ou marquer un message | Conserve l'état en mémoire jusqu'à la fermeture de l'écran |
| Réagir par un émoji | Ajoute la réaction sous le message affiché |
| Mettre une conversation en sourdine | Change l'icône de sourdine |
| Bloquer un contact | Affiche un message de confirmation |
| Supprimer une conversation | Affiche un message de confirmation |
| Appel audio ou vidéo | Affiche « Appel en cours… » |
| Rechercher un livreur | Affiche un livreur de démonstration après 2 secondes |

**Actions qui, à l'inverse, émettent bien une requête réseau** : envoi d'un message
texte, envoi de la localisation, envoi d'un carrousel produits, marquage des messages
comme lus, chargement des conversations et des messages, chargement du catalogue,
création et annulation d'un lien de paiement, réponse à un commentaire, mention
« J'aime » sur un commentaire, changement de statut d'un commentaire, chargement du
tableau de bord, connexion et réinitialisation du mot de passe, enregistrement du
terminal pour les notifications.

➡️ **Formulation suggérée pour le rapport** :
> « La version actuelle de l'application couvre l'envoi de messages texte, de la
> localisation et de carrousels produits. L'envoi de médias et les actions de gestion
> des messages (modification, suppression, épinglage, transfert) sont réalisés au
> niveau de l'interface et restent à finaliser. »

---

## 4. Contraintes fonctionnelles transversales

| Contrainte | Valeur |
|---|---|
| Nombre maximum de produits par carrousel | **10** |
| Frais de livraison à domicile | **2 000 FCFA**, montant fixe |
| Longueur minimale du mot de passe | **8 caractères** |
| Devise | **FCFA / XOF** uniquement |
| Langue de l'interface | **Français** uniquement |
| Périodes disponibles pour les statistiques | 7 jours, 30 jours, mois en cours |
| Fournisseurs de paiement proposés | 7 (Wave, Orange Money, MTN Money, Moov Money, Djamo, CinetPay, FedaPay) |
| Canaux de messagerie pris en charge | 6 (WhatsApp, Messenger, Instagram, TikTok, SMS, Email) |
| Point de départ d'une conversation | Le client écrit toujours en premier |
| Organisation active | Une seule à la fois, celle du compte connecté |
| Connexion internet | Obligatoire pour toute action ; hors connexion, seules les données récemment consultées s'affichent |
