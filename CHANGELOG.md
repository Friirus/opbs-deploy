# Changelog

Format inspiré de [Keep a Changelog](https://keepachangelog.com/). Les versions suivent SemVer
appliqué à un produit auto-hébergé, pas à des paquets publiés : **MAJEUR** = une mise à jour exige
une intervention de l'hébergeur (variable d'environnement renommée/supprimée, étape manuelle,
changement de comportement qui casse un usage existant) ; **MINEUR** = nouvelle fonctionnalité,
mise à jour sans intervention ; **CORRECTIF** = correction de bug, sans changement de comportement
voulu. Les migrations de base de données s'appliquent automatiquement au démarrage
(`docker-entrypoint.sh` → `prisma migrate deploy`) : ce n'est jamais, à lui seul, ce qui justifie
un MAJEUR.

## [Non publié]

### Ajouté

- **Réglages de thème liés à la feuille de style** (contrat `0.33.0`). Un réglage de thème peut
  remplacer un token (`token`) ou poser une variable CSS du thème (`cssVar`) ; nouveaux types
  `color` (sélecteur + contraste) et `order` (ordre des blocs, liste déplaçable), curseur pour un
  nombre borné, champs conditionnels (`visibleWhen`) et palettes (`options[].sets`). Les réglages
  s'insèrent entre les tokens du thème et la marque de Paramètres › Identité, qui garde le dernier
  mot — le panel signale le champ ainsi remplacé. Le thème « Argile » passe de 25 à 78 réglages :
  palettes, couleurs, arrondi, densité, largeur, polices, style de barre, dispositions du hero et
  des pages de connexion, ordre des blocs de l'accueil, colonnes, catalogue en liste, pied compact
  ou encre, liens sociaux. Les thèmes et modules tiers doivent déclarer `^0.33.0`.
- **Contenu d'hébergeur dans un thème** (contrat `0.33.0`) : réglages de type `list` (éléments
  composés, ajoutés et ordonnés au panel) et textes `localized` (une valeur par langue, saisie
  par onglets ; le portail relaie la langue du visiteur aux rendus publics). « Argile » 1.2.0
  gagne un bandeau d'annonce, des avis clients, des logos partenaires et une FAQ, et tous ses
  textes sont traduisibles. Une liste peut porter le contenu d'origine du thème (`defaultValue`
  en JSON) : « Argile » 1.3.0 rend ainsi modifiables ses six contenus jusque-là écrits en dur —
  ligne de confiance, étapes du déroulé, rubriques de l'espace client, cartes de ressources,
  points du bandeau de fin — avec choix d'icône par élément, et le pied de page accepte trois
  colonnes de liens libres.
- **Thèmes traduisibles** (contrat `0.33.0`). Un thème livre ses libellés dans `locales/<langue>.json`
  et les lit sous `t` ; la langue du visiteur s'applique, avec repli clé par clé sur celle de
  l'instance. « Argile » 1.5.0 est traduit en français, anglais et allemand (120 libellés, contenus livrés compris) — ses
  pages ne mélangent plus ses propres textes, jusque-là francophones, avec ceux du noyau, eux
  traduits. Les titres et accroches du panier, des domaines, de l'aide, de l'inscription et des
  cinq documents légaux deviennent en outre des réglages.
- **Mode sombre** (contrat `0.33.0`). Un thème déclare sa palette sombre (`theme.tokensDark`) et
  l'hébergeur choisit l'apparence du site : toujours claire, toujours sombre, ou selon le système
  du visiteur. Les couleurs de marque de Paramètres › Identité s'appliquent aux deux palettes, et
  les couleurs de texte lisibles sur un aplat sont recalculées pour chacune. « Argile » 1.4.0
  livre sa palette « nuit » et expose ses sept couleurs sombres.
- **Réglages de thème : images, longueurs maximales et captures** (contrat `0.28.0`). Un réglage
  peut être de type `image` (thèmes seulement) et déclarer `maxLength` ; un thème peut livrer une
  capture d'écran (`theme.screenshot`) pour le sélecteur. Le thème « Argile » déclare son image
  d'accueil en `image` et borne ses textes. Les thèmes tiers doivent déclarer `^0.28.0`. Une
  adresse de réglage qui n'est ni `https:`, ni `http:`, ni un chemin du site n'atteint jamais un
  gabarit : Liquid échappe le HTML, pas le protocole, et un `javascript:` dans un `href`
  s'exécuterait.
- **Les réglages d'un thème passent par un brouillon.** Chaque modification est enregistrée en
  brouillon pendant la saisie, invisible des visiteurs, puis publiée (ou abandonnée) d'un clic. Deux
  administrateurs sur la même page ne s'écrasent plus : le second est prévenu que le brouillon a
  changé. Publication et abandon sont inscrits au journal d'audit.
- **Aperçu d'un thème avant de le publier ou de l'appliquer.** La page d'un thème montre la vitrine
  dans un cadre, avec le brouillon en cours : choix de la page (accueil, catalogue, connexion…) et de
  la largeur (mobile, tablette, bureau), rechargement après chaque enregistrement. Fonctionne aussi
  pour un thème qui n'est pas appliqué, depuis le lien « Aperçu » du sélecteur. Les visiteurs ne
  voient jamais le brouillon : l'aperçu passe par un jeton lié à la session du panel, revérifié à
  chaque page (compte actif, session ouverte, droit `themes.write`).
- **Téléversement d'images dans les réglages de thème.** Un réglage `image` propose « Téléverser /
  Remplacer / Retirer » : PNG, JPEG ou WebP, 5 Mo au plus. Le type est vérifié sur les octets (un
  fichier renommé n'y change rien, le SVG est refusé) et les métadonnées — position GPS d'une photo
  de téléphone, commentaires — sont retirées avant stockage. Les images vivent en base (table
  `theme_media`), donc dans les sauvegardes `backup.sh` existantes, dans la limite de 200 fichiers et
  150 Mo ; celles que plus aucun réglage ne cite sont supprimées 24 h après leur envoi, lors d'une
  publication ou d'un abandon.
- **Vignettes dans le sélecteur de thèmes.** Chaque carte montre la capture du thème (`classic`,
  `encre`, « Argile » et « Kiosque » en livrent une) ou, à défaut, une page miniature dessinée avec
  ses propres couleurs, son rayon et sa police de titres. Un badge signale un brouillon non publié.
  La description de « Classique » disait encore « sombre et violet » : elle décrit désormais le
  thème clair qu'il est devenu.
- **Formulaire de réglages plus lisible.** Les cases « Activé / Désactivé » deviennent des
  interrupteurs, une image s'affiche en vignette (et le dit quand l'adresse ne mène à rien), un texte
  borné montre son compteur. Sur la page d'un thème, chaque champ modifié porte une pastille « Non
  publié » et un bouton pour revenir à sa valeur d'origine, et une barre de sections mène à chaque
  groupe. Interrupteur, vignette et compteur valent aussi pour la configuration des modules.
- **Un thème a sa page de configuration** (contrat `0.27.0`). Il déclare `theme.settings` dans son
  manifeste — les mêmes `ConfigField` que les modules, avec un `group` pour les répartir en
  sections et un nouveau type `url` pour les images — et le panel en rend le formulaire dans
  Paramètres › Système › Thèmes › Configurer. Les valeurs arrivent aux gabarits sous `settings`,
  dans l'enveloppe comme dans chaque vue. Jusqu'ici un thème n'était paramétrable que par ses
  couleurs : tout le reste — titres, accroches, libellés de boutons, image de présentation, blocs à
  montrer ou non — vivait en dur dans ses gabarits, et un hébergeur qui voulait changer une phrase
  devait éditer un `.liquid` par SSH, pour le perdre à la mise à jour suivante du thème.
  `password` et `provider` y sont refusés : un thème n'exécute aucun code, il n'a ni secret à garder
  ni fournisseur à piloter.
- **Le thème d'exemple « Argile » déclare 25 réglages**, répartis en quatre sections (Navigation,
  Accueil — en-tête, Accueil — sections, Présentation) : de quoi refaire sa vitrine sans ouvrir un
  fichier.
- **Le contexte d'un thème porte le catalogue là où il en a besoin** (contrat `0.26.0`, purement
  additif). La page d'accueil reçoit `sections`, `bundles` et `commitments` ; l'enveloppe reçoit
  `catalogFamilies` — **l'arbre des catégories publiées**, chacune avec ses sous-familles, ses
  offres, son prix d'appel et le compte de sa branche —, de quoi écrire le menu déroulant à
  colonnes qu'a toute vitrine d'hébergeur ; chaque section porte `fromPriceFormatted`, le prix de
  son offre la moins chère. Sans eux, un gabarit ne pouvait annoncer une offre ou un prix de départ
  qu'en l'écrivant en dur — c'est-à-dire en publiant le catalogue d'un autre hébergeur que celui
  qui installe le thème. `fromPriceFormatted` est calculé par le noyau parce qu'un gabarit ne le
  peut pas : les prix lui arrivent déjà mis en forme, et trier des chaînes place « 11,88 » avant
  « 2,39 ».
- **Thème d'exemple « Argile »** (`examples/extensions/theme-argile`) : colonne unique, cartes
  arrondies, navigation en pilule flottante à deux étages avec menu des familles. Couvre les 12
  vues de la vitrine et les 8 pages d'authentification, sans une seule couleur littérale dans sa
  feuille — tout descend des tokens, donc la couleur de marque du panel recolore la page entière.
- `pnpm check-extension` refuse un `{% render %}` / `{% include %}` dont la cible n'existe pas dans
  le thème. Le chemin part de la racine du thème, pas du gabarit qui l'écrit : en relatif, LiquidJS
  lève une erreur, le noyau retombe sur son écran React et la page reste parfaitement
  présentable — sans qu'une ligne du thème ne s'affiche, et sans que rien ne le signale.
- **Fiche client en onglets** (vue d'ensemble, services, facturation, support, sécurité), avec un
  bandeau « À traiter » (compte verrouillé, e-mail rejeté ou jamais vérifié, factures impayées, SLA
  dépassé, risque élevé, double authentification absente), les tickets, sous-utilisateurs, moyens de
  paiement et connexions récentes du client, des actions rapides, une chronologie filtrable et des
  notes internes épinglables (`customers.notes.write`). Un cycle de facturation par abonnement :
  période courante, prochaine échéance, résiliation programmée.
- **Liste des clients** : filtres Revendeurs et Verrouillés, colonne et tri par impayé, recherche
  par numéro de facture. **Liste des abonnements** : recherche, filtres par statut avec compteurs,
  tri par échéance ou par client, résiliation programmée, menu d'actions par ligne et panneau de
  création. **Catalogue** : l'arbre des catégories passe dans la page Produits (glisser-déposer,
  renommer, masquer, supprimer), et le tableau change la catégorie d'un produit sur place.
- **Installation en une commande** : `install.sh` (miroir `opbs-deploy`) vérifie Docker, récupère
  les fichiers de déploiement, demande le domaine et l'adresse Let's Encrypt, contrôle le DNS des
  trois noms, laisse de côté le Caddy fourni si les ports 80/443 sont pris, écrit lui-même le `.env`
  (aucun secret), démarre l'instance puis affiche la clé de chiffrement à conserver et le lien de
  l'assistant, jeton compris. Relancé, il ne régénère rien : c'est aussi la commande de mise à jour.
  Mode sans terminal par variables (`OPBS_DOMAIN`, `OPBS_ACME_EMAIL`, `OPBS_KEY_FILE`…).
- **Sauvegarde de la clé de chiffrement** : `backup.sh --export-key [fichier]` l'affiche ou l'écrit
  (lisible par son seul propriétaire) ; elle ne change jamais et ne va jamais dans un dump.
  `restore.sh --key-file <clé> [dump]` la restaure sur un nouveau serveur, puis attend que l'API
  redevienne saine. `backup.sh` et `restore.sh` n'exigent plus de `.env`.
- **`reset-2fa`** : `docker compose run --rm api node dist/cli/reset-2fa.js <email>` (`--client`
  pour un client final) désactive la double authentification d'un compte dont le code ne peut plus
  être vérifié — clé perdue, ou unique administrateur sans son téléphone —, lève son verrouillage et
  l'inscrit au journal d'audit. L'application seule ne le permet pas : désactiver la double
  authentification y exige un code valide.
- **Assistant d'installation : e-mail sortant et encaissement.** Deux étapes, après la création de
  l'administrateur et sous sa session, règlent le module SMTP et une passerelle de paiement choisie
  parmi les modules `payment` installés, avec l'adresse de notification à déclarer chez elle. Les
  deux sont passables. Un e-mail d'essai part vers l'adresse de l'administrateur
  (`POST /settings/email-test`, `settings.write`) avec des délais courts, et la raison d'un échec
  s'affiche telle quelle — sans module SMTP actif, l'essai échoue au lieu de « réussir » en journal.
### Changé
- **MAJEUR : les secrets de l'instance ne vont plus dans `.env`.** Mot de passe Postgres,
  `CREDENTIALS_ENCRYPTION_KEY`, secrets JWT et jeton d'installation sont générés au premier
  démarrage par le service `init-secrets`, dans deux volumes hors de la base (`secrets_db`,
  `secrets_app`) que l'API et le worker chargent par leur entrypoint. Une instance existante n'a
  rien à faire au moment de la mise à jour : au premier démarrage, les valeurs de son `.env`
  initialisent les volumes, qui font foi ensuite — ces lignes peuvent alors quitter le fichier.
  Une installation neuve démarre sans aucun `.env`.
- **MAJEUR : le reverse proxy fourni démarre par défaut.** `COMPOSE_PROFILES=bundled-proxy`
  disparaît ; `OPBS_BUNDLED_PROXY=0` retire Caddy quand nginx, Apache ou Traefik occupent déjà les
  ports 80/443, y compris un Caddy déjà lancé (un profil désactivé le laissait tourner). Une
  instance qui avait vidé `COMPOSE_PROFILES` doit poser `OPBS_BUNDLED_PROXY=0`, sinon Caddy
  réclame ces ports au démarrage.
- **L'API et le worker refusent de démarrer sur un secret absent ou faible** — clé qui ne décode
  pas en 32 octets, secret JWT manquant, de moins de 32 caractères ou commun à deux contextes —
  au lieu d'échouer au premier usage. Un témoin chiffré (`credentials_key_checks`) refuse aussi une
  clé qui n'est pas celle de la base, procédure à l'appui dans le journal ;
  `OPBS_ACCEPT_NEW_CREDENTIALS_KEY=1` accepte consciemment une nouvelle clé. Le worker démarre
  désormais après l'API.
- **`pnpm dev:env`** complète le `.env` de développement (secrets générés, `DATABASE_URL`), et
  `pnpm dev` le lit enfin depuis la racine du dépôt pour l'API et le worker.
- **L'écran Catalogue › Catégories disparaît** : l'arbre de la page Produits le remplace. Aucune
  route d'API ne change.
- Le formulaire de facture manuelle est replié sous la liste ; `/invoices?customer=<id>` le déplie
  avec le client choisi. La console des tickets lit ses compteurs en un appel
  (`GET /tickets/counts`, `support.tickets.read`) au lieu de cinq lectures de `GET /tickets`, qui
  épuisaient le budget de la route (60 requêtes par minute pour toute l'instance) et faisaient
  tomber la page en erreur.
- **Le portail ne peut plus être affiché dans un cadre**, sauf par le panel
  (`Content-Security-Policy: frame-ancestors 'self' <WEB_ADMIN_URL>`). N'importe quel site pouvait
  jusqu'ici l'encadrer (détournement de clic). `WEB_ADMIN_URL` est désormais transmise au service
  `web-portal` par `infra/docker-compose.yml`, avec la même valeur par défaut que pour l'API : aucune
  action requise sur une installation standard.
### Supprimé
- **MAJEUR : `SMTP_*`, `STRIPE_SECRET_KEY` et `STRIPE_WEBHOOK_SECRET` ne sont plus lues.** SMTP et
  Stripe sont des modules réglés au panel depuis la 1.0.0 ; les services qui recopiaient ces
  variables en base au démarrage (`SmtpAdoptionService`, `StripeAdoptionService`) disparaissent
  avec elles. Une instance démarrée au moins une fois en 1.0.0 a déjà sa configuration en base.
  Sinon, la saisir dans Paramètres › Extensions avant la mise à jour : sans elle, les e-mails ne
  sont plus que journalisés et le paiement en ligne s'arrête.
### Corrigé
- **Les options configurables d'un client facturé hors devise de base se renouvelaient au mauvais
  prix.** À la commande, la facture convertissait le delta d'une option dans la devise du client,
  mais la sélection mémorisait la valeur du catalogue, en devise de base ; le renouvellement (et le
  renouvellement anticipé, et le total « prochaine facture » de la fiche client) l'ajoutait tel
  quel au prix de l'abonnement, déjà converti : 5,00 € d'option devenaient 5,00 $ au lieu de 5,50 $
  à 1,10, dès la deuxième échéance. Le montant converti est désormais figé sur la sélection à la
  commande, comme `unitPriceCents` et comme les add-ons, et relu tel quel ; la valeur du catalogue
  est gardée à part (`baseCurrencyPriceDeltaCents`). Une migration reprend les sélections
  existantes des abonnements en devise étrangère : le montant de leur toute première facture
  quand il est identifiable, sinon le rapport entre le prix converti de l'abonnement et son prix
  de base. Leur prochaine facture de renouvellement reprend donc ce montant ; les factures déjà
  émises avec l'ancien montant ne sont pas corrigées, une régularisation par avoir reste à la main.
- **`pnpm check-mirrors` ne regardait plus qu'une partie des fichiers.** Son contrôle
  `LocalizedText` retirait les littéraux de chaîne **avant** les commentaires : un backtick écrit
  dans un commentaire — `` `settings` `` dans une phrase, ce que font tous les en-têtes de ce dépôt
  — entrait dans l'appariement des littéraux gabarits, et l'expression avalait des dizaines de
  lignes de code réel. Le contrôle passait sur un fichier amputé sans jamais le dire, et masquait
  ainsi un accès `.fr` présent depuis plusieurs commits. Remplacé par un balayage caractère par
  caractère, qui sait à chaque position s'il est dans du code, une chaîne ou un commentaire.
- **Les liens visités ne repeignent plus les boutons.** `components.css` posait
  `a, a:visited { color: var(--brand-color-accent) }` : une pseudo-classe pesant autant qu'une
  classe, `a:visited` (0,1,1) l'emportait sur `.nw-pagination__link`, sur `.nw-button--primary` et
  sur les classes de bouton d'un thème. Tout bouton rendu par un `<a>` virait donc à la couleur
  d'accent — mais seulement chez les visiteurs ayant déjà ouvert la page de destination, ce qui
  rendait le défaut invisible sur un profil neuf et introuvable au navigateur, `getComputedStyle`
  mentant sur `:visited` pour la vie privée. La règle ne vise plus que les liens sans classe
  (`a:not([class])`), ce qu'elle avait toujours prétendu faire.
- **Les ressources d'un thème ne restaient plus figées une heure.** `stylesheet.css` et `script.js`
  étaient servis avec `max-age=3600` et aucun validateur : un thème corrigé sur le serveur
  continuait de s'afficher dans son état d'avant, le navigateur ne revalidant pas une seule fois.
  Désormais un `ETag` et une durée courte — le navigateur revalide et reçoit `304` tant que rien
  n'a bougé.
- **Les îlots placés dans l'enveloppe d'un thème sont montés sur les pages d'authentification.**
  `AuthShell` injectait l'en-tête et le pied en HTML brut : le sélecteur de langue et le bouton de
  consentement qu'un thème y plaçait n'étaient jamais montés (emplacement vide, rien en console), et
  le repli du sélecteur s'ajoutait sans condition — donc en double.
- **Le badge « SMTP configuré » de Paramètres › E-mails dit enfin vrai.** Il lisait `SMTP_HOST`,
  que l'envoi ne lit plus : un serveur réglé au panel s'affichait « non configuré ». Il suit
  désormais le module `smtp`.
- **L'assistant d'installation affiche les refus.** L'étape Pays et fiscalité passait à la suite
  même quand l'enregistrement était refusé ; le relais `/api/settings` changeait un refus en 500,
  et celui de la création d'administrateur affichait le corps JSON brut de l'API.

### Sécurité
- **Jeton d'installation.** Le premier visiteur de `/setup` après le démarrage devenait
  administrateur de l'instance, et des requêtes simultanées pouvaient en créer plusieurs. La
  création du premier administrateur exige désormais le jeton d'installation (`SETUP_TOKEN`),
  généré au premier démarrage et affiché dans le journal de l'API tant qu'aucun compte n'existe ;
  il est comparé en temps constant, la création se fait sous un verrou consultatif Postgres, est
  limitée à 5 essais par minute et inscrite au journal d'audit. Le reverse proxy fourni ferme en
  outre la route directe de l'API sur le domaine public.

## [1.0.0] - 2026-09-06

Première version **publiée** : les cinq images sont sur `ghcr.io/friirus/opbs-*` et les fichiers
de déploiement sur `Friirus/opbs-deploy`. Un tag `1.0.0` avait été posé localement le 2026-08-24,
sans jamais être publié ni installé nulle part ; cette entrée le remplace et couvre donc tout ce
qui a été livré depuis, l'historique détaillé antérieur restant dans les commits.

Les deux mentions **MAJEUR** ci-dessous décrivent le comportement de cette version, pas une
migration : personne n'exploitait la version précédente. À partir d'ici, la règle annoncée en tête
de fichier s'applique pleinement — toute mise à jour exigeant une action de l'hébergeur est
signalée comme telle.

### Ajouté

- **Canal de distribution sans accès au dépôt source.** Images versionnées publiées sur
  `ghcr.io/friirus/opbs-*` à chaque tag `vX.Y.Z`, et dépôt miroir public sans historique
  (`Friirus/opbs-deploy`) portant `docker-compose.images.yml`, le `Caddyfile`, les scripts de
  sauvegarde/restauration, le `.env.example` et ce changelog. Un hébergeur tiers déploie et met à
  jour une instance sans jamais avoir accès au code source du produit.
- **Le reverse proxy fourni est devenu facultatif.** Le service Caddy vit dans un profil Compose
  (`COMPOSE_PROFILES=bundled-proxy`, posé dans `.env.example`, donc actif par défaut). Un hébergeur
  qui a déjà nginx, Apache ou Traefik sur ce serveur vide la variable : Caddy ne démarre plus et
  laisse les ports 80/443, les quatre applications restant jointes sur `127.0.0.1:3001-3004`.
  Exemple de vhost nginx et points de vigilance (`X-Forwarded-For`, `DOMAIN` toujours requis) dans
  la section « Reverse proxy » du guide de déploiement. Sur une instance déjà démarrée avec Caddy,
  la bascule demande un `--profile bundled-proxy down` explicite : Compose ignore les conteneurs
  d'un profil désactivé au lieu de les arrêter, `down` compris — sans cette étape, l'ancien proxy
  garde les ports.
- `OPBS_PROJECT` et `OPBS_COMPOSE_FILE` dans `backup.sh`/`restore.sh`, pour sauvegarder ou
  restaurer une seconde pile (instance de test, essai de restauration) sans modifier les scripts.
  Valeurs par défaut inchangées : le projet `opbs` et le fichier compose voisin du script.
- **Dix passerelles de paiement livrées avec le produit**, contre trois auparavant (Stripe, PayPal,
  virement). S'y ajoutent Mollie (les cinq capacités, dont le prélèvement hors session), Coinbase
  Commerce, Razorpay, Mercado Pago, dLocal Go, PayU Europe et Midtrans — Europe, Inde, Amérique
  latine, Afrique, Asie du Sud-Est et cryptomonnaies. Chacune n'expose que ce qu'elle sait
  réellement faire : le panel ne montre pas un bouton « Rembourser » à une passerelle qui n'a pas
  d'API de remboursement.
- **Un thème peut rhabiller les 8 pages de la vitrine**, contre 3 auparavant (accueil, catalogue,
  politique de confidentialité). S'y ajoutent le panier, les noms de domaine, la base de
  connaissances (liste et article) et les CGV. Un thème qui ne fournit pas le gabarit d'une page
  retombe sur l'écran d'origine, page par page : appliquer un thème incomplet ne rend jamais
  l'instance inutilisable.
- **Îlots de thème.** Un gabarit place un marqueur (`data-island="order-button"`) et le noyau y
  monte le vrai composant — bouton de commande, panier, recherche de domaine, sélecteur de langue.
  Le thème décide de la structure et de la position, jamais du comportement : le tunnel d'achat
  reste du code de l'application, et un thème ne peut pas fabriquer un formulaire
  d'authentification.
- **JavaScript de thème.** Un thème peut livrer un fichier `.js` (`theme.script` dans son
  `extension.json`), servi par une route dédiée et chargé sur toutes les pages du portail. Réservé
  aux thèmes déposés sur le serveur : aucun réglage de marque saisi dans le panel ne peut injecter
  de script.
- `pnpm check-extension` refuse un gabarit de thème qui oublie un îlot obligatoire de sa page, ou
  qui en nomme un qui n'existe pas. Sans ce contrôle, un catalogue sans bouton de commande
  s'affiche parfaitement et ne vend rien.
- **Pages créées par l'hébergeur.** Le back-office peut publier ses propres pages de contenu
  (modèle `Page`, blocs structurés), thémables via la vue générique `content-page`.
- **42 pages sur 42 du portail sont désormais thémables** : les 25 vues de l'espace client
  (tableau de bord, services, factures, tickets, domaines, compte…) et les 8 pages
  d'authentification (connexion, inscription, mot de passe, SSO…) entrent au registre de vues. Les
  vues d'authentification ne reçoivent jamais de jeton, de ticket ni de code — seulement un
  booléen (`hasToken`, `hasTicket`…) ; le secret va directement de la page à l'îlot, jamais par la
  route de rendu.
- **Un thème peut apporter ses propres pages**, à des URL que le noyau ne connaissait pas jusqu'ici
  (`ThemeDefinition.pages`, gabarit libre, aucun îlot obligatoire). Une page créée au panel au même
  slug l'emporte toujours sur celle du thème.
- **Un module peut ajouter des pages au portail client**, en plus d'un écran d'administration :
  `/m/<moduleId>/<pageId>` côté client, `/x/<moduleId>/<pageId>` côté public. L'identité du client
  vient du jeton de session vérifié, jamais de l'URL.
- **Un écran de panel peut être rendu par le code du module** (`ContributedScreen.bundle`), et non
  plus seulement par le moteur déclaratif de sections — un fichier ESM déjà construit par l'auteur,
  importé par le panel à l'exécution. Un bundle refusé n'éteint pas le module : l'écran retombe sur
  ses sections avec un bandeau qui nomme la raison.
- **Un revendeur peut appliquer sa propre marque** aux clients qu'il gère : nom, logo, couleurs, et
  un domaine dédié (émission de certificat TLS à la demande, vérification de propriété par
  enregistrement TXT). Le `From:` des e-mails reste celui de l'hébergeur, seul aligné SPF/DKIM ;
  seuls le nom affiché et le `Reply-To` changent.
- **Un module tiers de provisioning est vendable de bout en bout.** `driverId` est désormais validé
  aussi contre le registre des extensions, pas seulement contre les drivers embarqués — le verrou
  touchait quatre points (validation d'entrée, déclenchement à l'activation, panel, catalogue), pas
  un seul. Avant ce correctif, un produit tiers pouvait être encaissé puis jamais livré, avec pour
  seule trace un `logger.warn`.
- **Une troisième langue, l'allemand**, preuve que `SUPPORTED_LOCALES` est réellement extensible :
  catalogues des deux fronts, `LOCALE_TAGS`, sélecteurs de langue.
- Le worker journalise en structuré (pino, JSON par ligne) au lieu de `console.*` — 61 appels
  dispersés remplacés, niveau réglable par `LOG_LEVEL` (nouvelle variable, défaut `info`).
- **La navigation de l'enveloppe thémée suit la locale du visiteur**, comme les layouts React
  qu'elle remplace — jusqu'ici figée en français (`NAV_BY_AREA`) quelle que soit la langue du
  client. `getThemeShell()` (portail) transmet la locale déjà résolue par next-intl ;
  `RenderShellQueryDto.locale` la reçoit, avec la locale d'instance en repli pour les rares
  appelants qui ne l'envoient pas encore. Les liens de pages d'hébergeur, de module et de thème
  ajoutés à cette même nav suivent désormais la même locale plutôt que celle de l'instance.
- **L'API journalise en structuré (`nestjs-pino`), comme le worker.** Les 18 fichiers à
  `new Logger(ClassName.name)` (`@nestjs/common`) passent par pino sans réécriture —
  `app.useLogger()` réoriente aussi les instances non injectées. `LOG_LEVEL` (déjà partagée avec le
  worker) pilote le niveau ; l'en-tête `Authorization` et les cookies sont retirés des lignes de
  requête HTTP journalisées, et `GET /api/v1/health` (appelé toutes les 10 s par le healthcheck
  compose) est tu plutôt que noyé dans le bruit.
- **Heartbeat et healthcheck du worker.** Le worker écrit un horodatage dans Redis toutes les 30 s ;
  le conteneur compose expose désormais un healthcheck (auto-vérification de fraîcheur, aucun
  `redis-cli` requis) ; `GET /health` gagne `checks.worker`, informatif — un worker mort ne rend
  jamais le conteneur *api* unhealthy — et le tableau de bord admin affiche un bandeau quand le
  battement dépasse 2 minutes sans écriture.
- **La page de statut publique suit la locale de l'instance**, jusqu'ici figée en français
  (`toLocaleString("fr-FR")` en dur). Le worker embarque `locale` dans l'instantané qu'il écrit ;
  la page reste sans infrastructure i18n (`output: "export"`) — un petit dictionnaire choisi par
  `snapshot.locale`, `<html lang>` mis à jour côté client au premier instantané.
- **Bannière cookies : bouton « Refuser »**, aussi visible que « J'ai compris » (exigence CNIL).
  Le stockage local distingue désormais un refus d'une acceptation
  (`cookie-consent-dismissed` vaut `"accepted"` ou `"refused"`, plus `"1"`) — rien ne le lit
  encore, la valeur est prête pour le jour où un script devra la consulter. `EXTENSIONS.md` § Le
  CSS et le JS avertit qu'un `theme.script` posant un traceur reste sous la responsabilité de
  l'hébergeur : la bannière ne couvre que les cookies du noyau.
- **Une option de module s'achète désormais en plusieurs exemplaires.** `quantity` existait dans le
  contrat (`AddonSubscriptionContext`) mais le noyau ne l'envoyait jamais qu'à `1` : un client qui
  voulait deux ports supplémentaires n'avait aucun chemin. Le sélecteur apparaît à l'ajout (portail
  client) ; prorata, ligne de facture et remboursement au retrait suivent la quantité choisie ;
  `onAttach`/`onDetach`/le rejeu reçoivent la quantité réelle plutôt qu'une valeur fixe. Changer la
  quantité d'une option déjà active reste à faire en la retirant puis en la rattachant — l'ajout
  incrémental n'est pas couvert par ce lot.
- **Bouton « Relancer » sur une option de module en échec.** `SubscriptionAddonsService.retryEffect`
  existait déjà côté API mais n'était appelable que par une requête manuelle ; la fiche client du
  panel affiche maintenant la note d'échec et un bouton qui rejoue `onAttach`, réservé au staff
  ayant `billing.subscription_addons.write`.
- **Module d'exemple `pterodactyl-ports` : retrait de l'offre quand la plage de ports est
  pleine.** Utilise `ctx.storage.keys(prefix)` (SDK 0.29.0) pour compter les ports déjà tenus dans
  `offeringsFor` et refuser de vendre l'option plutôt que de la laisser échouer, facturée, à
  `onAttach`.

- **Trois documents légaux publiables** : mentions légales, politique de remboursement et politique
  de cookies (Paramètres › Légal), à côté des CGV et de la politique de confidentialité qui
  existaient déjà. Servis sur `/legal/notice`, `/legal/refund` et `/legal/cookies`, thémables comme
  les autres pages. Les mentions légales et la politique de cookies sont proposées pré-remplies —
  les premières depuis la fiche société déjà saisie, la seconde depuis les traceurs que le produit
  dépose réellement. La politique de remboursement ne l'est pas : c'est un engagement commercial,
  et le produit ne promet rien au nom de l'hébergeur.
- **Pied de page légal.** La vitrine et l'espace client n'en avaient aucun : les documents publiés
  n'étaient atteignables qu'en tapant leur URL. Ne montre que les documents réellement rédigés, et
  l'onglet Légal signale à l'hébergeur ceux qui manquent.
- **Engagements de service** (Paramètres › Légal) : disponibilité, rétention des sauvegardes et
  délai de réponse du support, affichés par un thème qui les reprend. Laissés vides, ils ne sont
  pas publiés.
- **Lien d'évitement** au clavier sur les deux applications, et styles de focus dans le design
  system partagé — le panel en avait, la vitrine et l'espace client n'en avaient aucun.

### Modifié

- **MAJEUR — Fournisseurs de provisioning réunis sous « Infrastructure › Fournisseurs »**
  (`/providers`), qui remplace les entrées de sidebar « Hyperviseurs » et « Serveurs cPanel ».
  cPanel bascule intégralement sur le formulaire générique (`providerConfigFields`) : son écran
  dédié (`/cpanel-servers`) et son API (`CpanelServersController`/`Service`, DTOs) sont retirés —
  un hébergeur qui scriptait `POST /api/v1/cpanel-servers` doit migrer vers
  `POST /api/v1/provisioning-modules/cpanel/providers` (mêmes champs). Proxmox garde son écran
  dédié (`/proxmox-clusters`, table `ProxmoxCluster` non touchée) mais son formulaire de connexion
  se rend désormais depuis `providerConfigFields` ; au passage, `tlsFingerprintSha256` devient
  `tlsFingerprint` dans `POST/PATCH /proxmox-clusters` (nom aligné sur le contrat déclaratif et sur
  la colonne). L'assistant `/setup` propose désormais tout module `provisioning` installé au lieu
  de coder Proxmox en dur.
- Le thème livré **Encre** fournit désormais un gabarit pour les 8 pages de la vitrine, et le thème
  d'exemple **Kiosque** (`examples/extensions/`) pour l'accueil et le catalogue, avec son script.
- **Le français n'est plus une langue obligatoire.** `LocalizedText` devient
  `Partial<Record<SupportedLocale, string>>` ; seule l'exigence « au moins une langue renseignée »
  demeure, portée par validation. La résolution cascade : locale demandée → défaut de l'instance →
  première variante non vide → chaîne vide.
- **MAJEUR — Recouvrement : les délais migrent entièrement vers le panel.**
  `DUNNING_REMINDER_INTERVAL_DAYS` et `DUNNING_PENDING_PAYMENT_TIMEOUT_DAYS` (jusqu'ici lues
  uniquement depuis l'environnement par le worker) rejoignent `dunningSuspendAfterDays` dans
  l'onglet Paramètres › Recouvrement. `DUNNING_SUSPEND_AFTER_DAYS` — documentée et câblée dans le
  compose, mais qui n'a jamais été lue par aucun code, la vraie valeur venant déjà du panel — est
  supprimée avec les deux autres. Un hébergeur qui réglait ces variables doit reporter ses valeurs
  dans le panel après mise à jour ; les valeurs par défaut (3 jours / 10 jours) sont inchangées.
- Le contrat de la file de provisioning (`PROVISIONING_QUEUE`, `ProvisioningJobName`,
  `ProvisioningJobData`) vit désormais dans `@opbs/drivers`, plus dans `@opbs/proxmox` : il
  transporte les actions de tous les modules de provisioning, pas d'un seul hyperviseur. Le
  ré-export de compatibilité du chiffrement depuis `@opbs/proxmox` est retiré ; les appelants
  importent `@opbs/crypto` directement. Aucun effet pour un hébergeur — interne au monorepo.

- **Les modules d'options sont désormais interrogés dans la langue du client**, et non dans celle
  d'exploitation de l'instance. Le libellé qu'un module rend est figé sur la ligne d'option à
  l'ajout puis réapparaît sur la facture : un client anglophone se voyait vendre un intitulé
  français. Un hébergeur n'a rien à faire ; un module qui ne traduit pas ses libellés se comporte
  comme avant.

### Corrigé

- **Les scripts de sauvegarde et de restauration fonctionnent depuis le dépôt de déploiement.**
  Ils désignaient `infra/docker-compose.yml`, un chemin qui n'existe que dans le dépôt source :
  `backup.sh` aurait échoué chez tout hébergeur déployé par images, dès la première exécution, et
  en silence dans un cron. Le fichier compose est désormais résolu depuis l'emplacement du script
  (`OPBS_COMPOSE_FILE` pour forcer un autre chemin), et `pnpm check-mirrors` refuse tout chemin du
  monorepo dans un fichier destiné à être publié.
- **Le guide de déploiement annonçait deux enregistrements DNS au lieu de trois.**
  `status.<domaine>` manquait, alors que le reverse proxy fourni en demande le certificat : avec un
  `TLS_MODE` réglé sur une adresse e-mail, l'émission échouait en boucle jusqu'aux limites de taux
  de Let's Encrypt.
- **Un rejeu de notification de paiement rattrape un provisioning perdu.** Le provisioning, l'e-mail
  de confirmation et les événements s'exécutent après le commit du règlement ; un arrêt du process
  dans cette fenêtre laissait un abonnement payé, actif, jamais livré — et la garde d'idempotence
  faisait du rejeu de la passerelle un simple retour. Le rejeu relance désormais l'activation des
  abonnements de ce règlement restés sans service ni demande d'approbation (panier, offre groupée),
  et la reprise d'un service suspendu pour une facture réglée depuis moins de 72 h (renouvellement).
  Il ne renvoie ni e-mail ni événement, faute de savoir s'ils sont partis.

- **Les options fournies par un module sont libérées à la résiliation de l'abonnement.**
  `onDetach` n'était appelé que lorsqu'un client ou le staff retirait explicitement une option :
  un abonnement résilié emportait les siennes sans que le module en soit averti, et la ressource
  qu'il avait allouée (port réseau, règle de pare-feu, licence chez un tiers) restait réservée pour
  un service qui n'existe plus. Les deux chemins de résiliation sont couverts — immédiate côté
  panel, et à l'échéance pour une résiliation programmée par le client.

### Sécurité

- **Les cinq images tournent en utilisateur non privilégié.** Un défaut applicatif exploité ne
  donne plus `root` dans le conteneur. Conséquence pour l'hébergeur : le dossier des modules
  (`EXTENSIONS_DIR`) doit rester lisible par cet utilisateur — il est monté en lecture seule, rien
  n'a besoin d'y écrire.

### Pour les auteurs de modules

- **SDK 0.28.0 : `ExtensionStorage.setIfAbsent` et `AddonSubscriptionContext.remoteId`.** La
  première est la seule écriture atomique du magasin, celle qui permet de réserver une ressource
  rare sans que deux rattachements simultanés se l'attribuent ; la seconde dit à un module
  d'options sur quel serveur agir chez le prestataire. Voir `packages/extension-sdk/CHANGELOG.md`.
- **`pterodactyl-ports` 1.1.0 parle réellement à un panel Pterodactyl** (allocation créée sur le
  nœud, rattachée au serveur par `PATCH …/build`), réserve ses ports par `setIfAbsent`, se
  réconcilie avec le panel avant d'allouer, saute un port pris hors du module, et rend l'allocation
  au nœud même si le serveur n'existe plus. Le module est le consommateur de référence du genre
  `addon` : ce qu'il fait est ce qu'un module réel doit faire.

- **Rupture du contrat d'extension** (`HOST_CONTRACT_VERSION` 0.15.0 → 0.16.0) : `ThemePageContext`
  et ses trois variantes disparaissent au profit d'un registre de vues. Un module déclarant
  `"engines": { "host": "^0.15.0" }` cesse d'être chargé — c'est l'effet recherché en 0.x. Voir
  `packages/extension-sdk/CHANGELOG.md` pour le détail et la marche à suivre.
- **Contrat étendu de façon additive, 0.16.0 → 0.23.0** : pages créées par l'hébergeur (0.17),
  espace client (0.18) et authentification (0.19) thémables, pages propres à un thème (0.20), pages
  de module (0.21), écran de panel à bundle (0.22), marque revendeur (0.23). Aucune suppression ni
  renommage sur ce trajet — un module écrit contre `0.16.0` reste chargé, il n'exploite simplement
  pas les nouvelles vues. Détail version par version : `packages/extension-sdk/CHANGELOG.md`.
- `LocalizedTextDto` accepte désormais `de` — un module qui construit ses propres textes localisés
  doit vérifier qu'il ne code plus en dur une liste `["fr", "en"]`.
- **`HostContext.locale` pour un module `addon`** : c'est maintenant la langue du **client**, quand
  l'appelant la connaît, et non celle de l'instance — même règle que pour un module `payment`. Le
  critère n'est pas le genre du module mais qui lit le texte qu'il produit : le `name` d'une
  `AddonOffering` est figé sur la ligne d'option puis sur la facture du client. `provisioning` et
  `theme` gardent la langue de l'hébergeur. Contrat inchangé (aucune signature ne bouge) ; un
  module qui ignorait `ctx.locale` continue de fonctionner. `EXTENSIONS.md` § `HostContext` a été
  révisé, il décrivait le comportement précédent comme voulu.
- **`onDetach` est appelé à la résiliation de l'abonnement**, plus seulement au retrait d'une
  option. Un module qui allouait une ressource doit donc s'attendre à être appelé sur un abonnement
  qui n'existera bientôt plus, et rester idempotent comme le contrat l'exige déjà. Il est appelé
  même s'il a été désactivé entre-temps : l'éteindre ne doit pas lui faire perdre sa ressource.
- **`createTestHost()` dans le SDK** (0.23.0 → 0.24.0, additif) : un `HostContext` de test prêt à
  l'emploi, sans Prisma ni réseau — `storage` en `Map` mémoire, `logger`/`emit` capturés dans des
  tableaux consultables, `http` substituable (rejette par défaut avec un message clair). Voir
  `EXTENSIONS.md` § « Écrire, vérifier, déposer » et `packages/extension-sdk/CHANGELOG.md`.
