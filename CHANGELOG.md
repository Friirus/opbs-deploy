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
