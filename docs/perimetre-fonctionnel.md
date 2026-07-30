# Contraintes fonctionnelles — Périmètre du système e-Signal

> Définition des **limites du système** au sens du cours UML n°2 § 2-1 :
> *« la première tâche consiste à définir les limites du système (c.-à-d. ce qui est
> inclus ou pas dans le système) »*.
> Source : analyse du code de la branche `feature/retouch`.

**Frontière retenue** : le système = **plateforme e-Signal** (application mobile Flutter
+ API backend `ws.score360.africa/api/v1.2`).

---

## 1. Tableau de synthèse global

| ✅ INCLUS dans le périmètre | ❌ EXCLU du périmètre |
|---|---|
| Réception et affichage unifiés des conversations de 6 canaux (WhatsApp, Messenger, Instagram, TikTok, SMS, Email) | Hébergement et exploitation des canaux eux-mêmes (serveurs Meta, opérateurs SMS) |
| Envoi de messages texte vers le canal d'origine du client | Rédaction automatique / réponses par intelligence artificielle |
| Envoi de la position GPS du commercial | Cartographie et calcul d'itinéraire |
| Envoi d'un carrousel produits (max 10 articles) | Composition graphique du carrousel (faite par WhatsApp/Meta) |
| Consultation du catalogue produits de l'organisation | Création, modification, suppression de produits (back-office web) |
| Génération de liens de paiement mobile money (7 fournisseurs) | Encaissement, débit du client, reversement des fonds (passerelles) |
| Consultation, annulation et export des transactions | Rapprochement bancaire, comptabilité, facturation légale |
| Consultation et réponse aux commentaires Facebook / Instagram / TikTok | Publication de nouveaux posts sur les réseaux sociaux |
| Tableau de bord (revenus, conversations, taux de réponse, canaux) | Construction des indicateurs (calculés par le backend d'analytique) |
| Authentification, activation de compte, réinitialisation du mot de passe | Création des comptes utilisateurs et des organisations (administration) |
| Réception de notifications push | Infrastructure de notification (Firebase Cloud Messaging) |
| Consultation du profil et des canaux connectés | Connexion / configuration d'un nouveau canal d'intégration |
| Fonctionnement mobile Android et iOS | Version web ou de bureau |
| Interface en français, montants en FCFA / XOF | Multilingue, multidevise, conversion de devises |

---

## 2. Détail par domaine fonctionnel

### 2.1 Messagerie

| ✅ Inclus | ❌ Exclu |
|---|---|
| Liste unifiée des conversations, tous canaux confondus | Création d'une conversation à froid (le client initie toujours l'échange) |
| Filtrage par canal, par non-lus, par commentaires | Filtrage par commercial assigné, par date, par étiquette |
| Recherche d'une conversation par nom de contact | Recherche globale multi-conversations |
| Consultation de l'historique paginé d'une conversation | Archivage et conservation longue durée des messages (backend) |
| Marquage automatique des messages comme lus | Accusé de lecture émis par le client (produit par la plateforme) |
| Envoi de messages **texte** | Envoi de messages vocaux, vidéo, documents *(affichage supporté, envoi non implémenté)* |
| Partage de la position GPS | Partage de contact, sondage, bouton de réponse rapide |
| Réception des messages en temps réel | Notification des messages hors ligne autrement que par push |
| Recherche dans une conversation | Recherche dans les pièces jointes |
| Export d'une conversation au format texte | Export au format PDF ou archive certifiée |
| Consultation du profil du client et de sa présence | Modification de la fiche client (CRM) |
| Appel téléphonique du client via l'application téléphone | Téléphonie intégrée (VoIP), appel vidéo, enregistrement d'appel |

### 2.2 Catalogue

| ✅ Inclus | ❌ Exclu |
|---|---|
| Consultation des produits **actifs** de l'organisation | Consultation des produits inactifs ou en brouillon |
| Filtrage produits / services | Recherche par mot-clé, tri par prix |
| Sélection de 1 à 10 produits pour un envoi | Envoi de plus de 10 produits (limite des plateformes Meta) |
| Affichage image, nom, description, prix, référence (SKU) | Gestion des stocks, des variantes (taille, couleur), des remises |
| — | Création / modification / suppression d'un produit |
| — | Import en masse du catalogue (CSV, tableur) |

### 2.3 Paiement

| ✅ Inclus | ❌ Exclu |
|---|---|
| Création d'un lien de paiement en 3 étapes (client → produit → paiement) | Saisie d'un montant libre sans produit du catalogue |
| Choix parmi 7 fournisseurs (Wave, Orange Money, MTN, Moov, Djamo, CinetPay, FedaPay) | Paiement par carte bancaire, virement, espèces |
| Partage du lien dans la conversation ou par copie | Relance automatique du client en cas de non-paiement |
| Suivi des statuts : Créé / En attente / Payé / Expiré | Le processus de paiement lui-même (page de la passerelle) |
| Annulation d'un lien non encore payé | Remboursement, paiement partiel, échelonnement |
| Téléchargement du reçu au format PDF | Facture fiscale conforme, mentions légales, TVA |
| Export des transactions en CSV et Excel | Connexion à un logiciel comptable |
| Consultation du récapitulatif des montants | Gestion de la trésorerie, prévisionnel |

### 2.4 Livraison

| ✅ Inclus | ❌ Exclu |
|---|---|
| Option de livraison à domicile lors de la création d'un lien (+2 000 FCFA) | Tarification variable selon la distance ou le poids |
| Saisie de l'adresse (destinataire, téléphone, commune, quartier, secteur) | Géocodage / validation de l'adresse |
| Affichage du livreur assigné (nom, note, délai estimé) | Suivi en temps réel de la position du livreur |
| — | Application dédiée au livreur, acceptation / refus de course |
| — | Rémunération du livreur, gestion des litiges de livraison |
| ⚠️ *Fonctionnalité actuellement simulée : le service livreur n'est pas connecté au backend réel.* | |

### 2.5 Commentaires réseaux sociaux

| ✅ Inclus | ❌ Exclu |
|---|---|
| Consultation des publications de l'organisation | Publication d'un nouveau post, programmation de contenu |
| Consultation du fil de commentaires d'une publication | Modération automatique, détection de spam |
| Réponse publique à un commentaire | Message privé au commentateur depuis le commentaire |
| Mention « J'aime » sur un commentaire | Partage, republication |
| Changement de statut (Nouveau / Répondu / Masqué) | Suppression définitive du commentaire chez le réseau social |

### 2.6 Statistiques

| ✅ Inclus | ❌ Exclu |
|---|---|
| Consultation des revenus, du nombre de conversations, du taux de réponse | Calcul des indicateurs (réalisé par le backend d'analytique) |
| Répartition des conversations par canal | Statistiques par commercial, par produit, par zone géographique |
| Évolution des revenus sur la période | Projections, prévisions, objectifs commerciaux |
| Filtre sur 3 périodes : 7 jours, 30 jours, mois en cours | Période personnalisée, comparaison entre périodes |
| — | Export ou impression du tableau de bord |

### 2.7 Compte et sécurité

| ✅ Inclus | ❌ Exclu |
|---|---|
| Connexion par identifiant (email ou téléphone) + mot de passe | Connexion biométrique, code PIN, double authentification |
| Activation d'un compte invité (définition du premier mot de passe) | Création du compte lui-même (fait par un administrateur) |
| Réinitialisation du mot de passe par code OTP envoyé par email | Réinitialisation par SMS |
| Renouvellement automatique et transparent de la session | Gestion des sessions multi-appareils, révocation à distance |
| Déconnexion | Verrouillage automatique après inactivité |
| Consultation du profil (nom, email, téléphone, niveau KYC, statut) | Modification des informations personnelles *(prévu ultérieurement)* |
| Consultation des canaux connectés | Connexion d'un nouveau canal *(prévu ultérieurement)* |
| Activation / désactivation des notifications | Réglage fin par type de notification ou par canal |
| — | Changement du mot de passe depuis le profil *(prévu ultérieurement)* |
| — | Aide et support intégrés *(prévu ultérieurement)* |
| — | Vérification KYC (le niveau est affiché mais non modifiable) |

### 2.8 Notifications

| ✅ Inclus | ❌ Exclu |
|---|---|
| Réception des notifications push (message, appel, paiement) | Notifications par email ou SMS |
| Historique groupé par période (aujourd'hui, hier, cette semaine…) | Conservation illimitée de l'historique |
| Filtrage par type (Tous / Messages / Appels / Paiements) | Filtrage par conversation ou par client |
| Réponse rapide sans ouvrir la conversation | Réponse avec pièce jointe depuis la notification |
| Marquer comme lue, tout marquer, archiver, supprimer, tout effacer | Report d'une notification (« me le rappeler plus tard ») |

### 2.9 Gestion d'équipe *(hors périmètre mobile)*

| ✅ Inclus | ❌ Exclu |
|---|---|
| Affichage de l'état d'affectation d'une conversation | **Assignation** d'une conversation à un commercial |
| Prise en compte automatique de la clôture d'une conversation | **Clôture / résolution** d'une conversation |
| — | Gestion des utilisateurs, des rôles et des permissions |
| — | Supervision de l'activité des commerciaux |
| ⚠️ *L'application mobile **reçoit** les événements d'affectation et de clôture, mais ne peut pas les **déclencher** : ces actions relèvent du back-office web.* | |

---

## 3. Fonctionnalités présentes à l'écran mais non transmises au backend

⚠️ **À signaler dans votre rapport** : ces actions existent dans l'interface et donnent
un retour visuel au commercial, mais **ne quittent pas le téléphone**. Elles ne sont
donc **ni pleinement incluses, ni exclues** — elles constituent le périmètre à
consolider.

| Fonctionnalité | Comportement réel | Conséquence |
|---|---|---|
| Envoi d'une photo produit | Affichée dans le fil, image conservée en local | Le client ne la reçoit pas |
| Envoi d'un devis rapide | Message affiché en local | Le client ne le reçoit pas |
| Envoi d'une promotion | Message affiché en local | Le client ne le reçoit pas |
| Demande d'avis client | Message affiché en local | Le client ne le reçoit pas |
| Envoi d'un suivi de commande | Carte affichée en local | Le client ne le reçoit pas |
| Transfert d'un message | Confirmation affichée | Aucun envoi réel |
| Modification / suppression d'un message | Modifié dans la liste locale | Réapparaît au rechargement |
| Épinglage / marquage d'un message | État conservé en mémoire | Perdu à la fermeture de l'écran |
| Réaction par emoji | Affichée en local | Non visible par le client |
| Mise en sourdine d'une conversation | Indicateur visuel | Les notifications continuent |
| Blocage d'un contact | Message de confirmation | Le contact peut toujours écrire |
| Suppression d'une conversation | Message de confirmation | La conversation revient au rechargement |
| Appel audio / vidéo | Message « Appel en cours… » | Aucun appel n'est établi |

➡️ **Recommandation de formulation pour votre rapport** :
> « Le périmètre de la version actuelle couvre l'envoi de messages texte, de
> localisation et de carrousels produits. L'envoi de médias (photo, audio, vidéo,
> document) ainsi que les actions de gestion des messages (modification, suppression,
> épinglage) sont implémentés côté interface et restent à raccorder au backend. »

---

## 4. Contraintes fonctionnelles transversales

| Contrainte | Valeur imposée |
|---|---|
| Nombre maximum de produits par carrousel | **10** (limite des plateformes Meta) |
| Délai de réponse à un client WhatsApp | **24 h** au-delà desquelles l'envoi est refusé par la plateforme |
| Frais de livraison à domicile | **2 000 FCFA** (montant fixe) |
| Durée de validité d'un lien de paiement | Définie par la passerelle, affichée dans le détail de la transaction |
| Devise unique | **FCFA / XOF** |
| Langue unique de l'interface | **Français** |
| Longueur minimale du mot de passe | **8 caractères** |
| Un lien de paiement porte **un seul** produit | Pas de panier multi-articles |
| Le client doit avoir écrit en premier | Aucune prospection sortante possible |
| Une organisation par utilisateur connecté | Pas de bascule multi-organisations |
| Connexion internet obligatoire | Pas de mode hors ligne (seule une consultation du cache récent est possible) |
