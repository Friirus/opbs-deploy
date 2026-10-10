# Déployer OPBS

OPBS est une alternative auto-hébergée à WHMCS. Ce dépôt contient uniquement ce qu'il faut pour
faire tourner une instance à partir des images publiées — pas le code source, qui reste privé
(`Friirus/opbs`). Chaque hébergeur exploite sa propre instance (une instance = une base de
données), sur son VPS/serveur dédié.

## Prérequis

- Un serveur (VPS ou dédié) avec Docker et Docker Compose v2.
- **Trois** enregistrements DNS pointant vers ce serveur :
  - `<votredomaine>` — l'espace client ;
  - `admin.<votredomaine>` — le back-office, servi sur un sous-domaine dédié et pas sur un chemin ;
  - `status.<votredomaine>` — la page de statut publique.

  Les trois sont nécessaires : avec un `TLS_MODE` réglé sur une adresse e-mail, Caddy demande un
  certificat pour chacun, et un nom sans DNS le fait échouer en boucle jusqu'à buter sur les
  limites de taux de Let's Encrypt.
- Un compte Stripe si vous voulez le prélèvement automatique à l'échéance (facultatif : sans lui,
  vous facturez et encaissez quand même, par virement/chèque/espèces pointés à la main).

## Installation

```bash
curl -fsSLO https://raw.githubusercontent.com/Friirus/opbs-deploy/main/install.sh
less install.sh   # le relire avant de l'exécuter
bash install.sh
```

Le script vérifie Docker, récupère ces fichiers dans `/opt/opbs` (ou `~/opbs` sans root), puis
pose deux questions : le domaine de l'instance et l'adresse à laquelle Let's Encrypt envoie ses
avis d'expiration. Il vérifie que les trois noms pointent vers le serveur, écrit lui-même le `.env`
(trois lignes, aucun secret), démarre l'instance et affiche, pour finir :

- **la clé de chiffrement de l'instance**, à conserver hors du serveur (gestionnaire de mots de
  passe). Elle déchiffre les identifiants rangés en base et n'est pas dans les sauvegardes de la
  base : voir « Sauvegarde » ci-dessous ;
- **le lien de l'assistant d'installation**, `https://admin.<votredomaine>/setup#token=…`. Le jeton
  qu'il porte prouve que vous avez accès au serveur : sans lui, le premier visiteur de la page
  deviendrait administrateur. Il est aussi écrit dans le journal de l'API tant qu'aucun compte
  n'existe (`docker compose -p opbs -f docker-compose.images.yml logs api`).

L'assistant crée le compte administrateur, puis règle le pays et la fiscalité, la marque, le
serveur d'envoi des e-mails (SMTP), une passerelle de paiement et votre premier fournisseur de
provisioning. Tout est facultatif sauf le compte, et tout se retrouve ensuite dans Paramètres.

**Aucun secret n'est à saisir.** Le mot de passe de la base, la clé de chiffrement, les secrets de
session et le jeton d'installation sont générés au premier démarrage par le service `init-secrets`,
dans deux volumes Docker distincts de la base. Le `.env` ne porte que des réglages d'hébergement
facultatifs (domaine, mode TLS, reverse proxy) ; `.env.example` les liste tous.

Sans terminal (Ansible, cloud-init), le script lit tout dans l'environnement :

```bash
OPBS_DOMAIN=hebergeur.fr OPBS_ACME_EMAIL=contact@hebergeur.fr \
  OPBS_KEY_FILE=/root/cle-opbs.txt bash install.sh
```

`OPBS_VERSION` fixe la version des images (recommandé en production ; sans elle, `latest` suit la
dernière publication). À la main, le même démarrage s'écrit, depuis ce dossier :

```bash
OPBS_VERSION=1.0.0 docker compose -p opbs -f docker-compose.images.yml up -d
```

Compose lit le `.env` posé à côté du fichier compose, s'il existe. Sans lui, l'instance démarre sur
`localhost` avec un certificat auto-signé : utile pour un essai, pas pour un serveur public.

## Paiement : les événements à souscrire chez la passerelle

Stripe et PayPal n'envoient à votre instance que les événements que vous avez cochés en créant
l'endpoint (Stripe) ou le webhook (PayPal). Un événement non coché n'arrive jamais, **sans aucune
erreur** ni de leur côté ni du nôtre : la facture reste simplement dans l'état où elle était. Ceux
qui suivent sont les seuls que l'instance traduit ; les autres sont ignorés, les cocher ne coûte
rien.

Stripe, endpoint `https://<votredomaine>/api/v1/webhooks/payments/stripe` (Développeurs › Webhooks) :

| Événement | Effet dans l'instance |
|---|---|
| `checkout.session.completed` | règle la facture ou la commande payée sur la page Stripe, ou enregistre une carte |
| `payment_intent.succeeded` | règle un renouvellement automatique, en particulier un prélèvement SEPA parti « en cours » |
| `payment_intent.payment_failed` | marque ce prélèvement échoué, le recouvrement le reprend à son prochain passage |
| `charge.dispute.created` | passe la facture en « contestée » |
| `charge.dispute.closed` | litige gagné : la facture redevient réglée ; perdu : elle reste contestée, à traiter |
| `refund.created` | enregistre un remboursement fait depuis le tableau de bord Stripe |
| `refund.updated` | même remboursement, une fois les fonds partis (SEPA, ACH) |

PayPal, webhook vers `https://<votredomaine>/api/v1/webhooks/payments/paypal` (Apps & Credentials) :

| Événement | Effet dans l'instance |
|---|---|
| `CHECKOUT.ORDER.APPROVED` | capture la commande approuvée par le client |
| `PAYMENT.CAPTURE.COMPLETED` | règle la facture ou la commande |
| `PAYMENT.CAPTURE.REFUNDED` | enregistre un remboursement fait depuis le tableau de bord PayPal |
| `CUSTOMER.DISPUTE.CREATED` | passe la facture en « contestée » |
| `CUSTOMER.DISPUTE.RESOLVED` | litige gagné : la facture redevient réglée ; perdu : elle reste contestée, à traiter |

**Un endpoint ou un webhook créé avant la prise en charge des remboursements et des litiges clos**
(contrat 0.36.0) n'a pas `refund.created`, `refund.updated`, `charge.dispute.closed` côté Stripe,
ni `PAYMENT.CAPTURE.REFUNDED` et `CUSTOMER.DISPUTE.RESOLVED` côté PayPal, s'il avait été créé avec
une sélection d'événements plutôt qu'avec « tous ». Ouvrez-le chez la passerelle et ajoutez-les :
l'instance ne peut pas le faire pour vous, et sans eux un remboursement fait depuis la passerelle
laisse la facture locale réglée alors que l'argent est reparti. Un remboursement demandé depuis le
back-office de l'instance n'est pas concerné, il est enregistré directement.

## Reverse proxy

Par défaut, la pile démarre son propre reverse proxy (Caddy), qui prend les ports 80 et 443 et
gère les certificats TLS des trois noms sans configuration.

Si ce serveur héberge déjà nginx, Apache ou Traefik, mettez `OPBS_BUNDLED_PROXY=0` dans `.env`
(le script d'installation le fait de lui-même s'il trouve ces ports occupés) : Caddy n'est plus
créé, un Caddy déjà lancé est retiré au `docker compose up -d` suivant, et les quatre applications
restent jointes sur la boucle locale.

| Nom | À router vers |
|---|---|
| `<votredomaine>` | `127.0.0.1:3003` (espace client), sauf `/api/v1/*` → `127.0.0.1:3001` |
| `admin.<votredomaine>` | `127.0.0.1:3002` |
| `status.<votredomaine>` | `127.0.0.1:3004` |
| domaines de vos revendeurs | même partage que `<votredomaine>` : `/api/v1/*` → `127.0.0.1:3001`, le reste → `127.0.0.1:3003` |

Exemple minimal côté nginx, pour l'espace client (le préfixe `/api/v1/` va à l'API, tout le reste
au portail — c'est le même partage que fait le `Caddyfile` fourni) :

```nginx
server {
    server_name votredomaine.fr;
    location /api/v1/auth/staff/bootstrap { return 404; }
    location /api/v1/ { proxy_pass http://127.0.0.1:3001; }
    location / { proxy_pass http://127.0.0.1:3003; }
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

La première ligne `location` ferme la route directe de création du premier administrateur, comme
le `Caddyfile` fourni : elle ne sert qu'au panel, qui la joint par l'adresse interne. Le jeton
d'installation reste la vraie garde.

Les domaines de revendeurs (marque blanche) suivent le même partage : leurs pages demandent la
feuille, les polices et les images du thème sous `/api/v1/` sur leur propre domaine. Un bloc qui les
enverrait tout entiers au portail servirait des pages sans thème.

Le TLS est alors à votre charge (certbot ou équivalent), et `TLS_MODE` n'a plus d'effet. Deux
points à ne pas manquer : relayez bien `X-Forwarded-For`, dont dépendent la détection de connexion
suspecte et la limitation de débit ; et gardez `DOMAIN` renseigné dans `.env` même sans le Caddy
fourni — il construit les URL publiques utilisées pour les redirections après paiement et les
liens de réinitialisation de mot de passe.

## Mise à jour

```bash
OPBS_VERSION=<nouvelle version> bash install.sh
```

Relancé, le script ne régénère aucun secret et ne touche pas au `.env` : il met à jour ces fichiers
de déploiement, tire les images de la version demandée et redémarre. À la main :
`OPBS_VERSION=<nouvelle version> docker compose -p opbs -f docker-compose.images.yml up -d`.

Les migrations de base de données s'appliquent automatiquement au démarrage — pas d'étape
manuelle à part le redémarrage des conteneurs. Avant de mettre à jour : sauvegarder (voir
ci-dessous), et consulter le `CHANGELOG.md` livré dans ce dépôt pour repérer une éventuelle mention
**MAJEUR**, qui signale une intervention manuelle requise avant ou après le redémarrage. Les
versions publiées sont celles listées sur
[les packages `opbs-*`](https://github.com/Friirus?tab=packages).

## Sauvegarde / restauration

**La clé de chiffrement d'abord.** Elle déchiffre les identifiants rangés en base (modules,
passerelles, SSO, webhooks, double authentification) et n'est volontairement pas dans les
sauvegardes de la base : une clé rangée à côté des dumps annulerait leur chiffrement. Elle ne change
jamais, il suffit donc de l'exporter une fois et de la conserver hors du serveur :

```bash
./backup.sh --export-key                 # l'affiche
./backup.sh --export-key cle-opbs.txt    # l'écrit dans un fichier lisible par vous seul
```

`backup.sh [dossier]` dump la base Postgres de l'instance courante en `.sql.gz` horodaté (défaut :
`./backups`). À planifier en cron, par exemple tous les jours à 3h avec rétention de 14 jours :

```bash
0 3 * * * cd /opt/opbs && ./backup.sh /var/backups/opbs && find /var/backups/opbs -name '*.sql.gz' -mtime +14 -delete
```

`restore.sh <fichier.sql.gz>` restaure une sauvegarde — **destructif** : coupe `api`/`worker`,
écrase le schéma `public`, les redémarre et attend que l'API redevienne saine. Toujours tester une
restauration sur une instance de secours avant d'en avoir besoin en urgence.

**Sur un nouveau serveur**, installez d'abord (`bash install.sh`), puis restaurez la base **et** la
clé d'origine : le premier démarrage a généré une clé neuve, qui ne déchiffre pas la base restaurée.

```bash
./restore.sh --key-file cle-opbs.txt opbs-XXXXXXXX-XXXXXX.sql.gz
```

Sans la bonne clé, l'API refuse de démarrer et le dit dans son journal (témoin de clé), plutôt que
de servir des identifiants illisibles. `./restore.sh --key-file cle-opbs.txt` seul remplace la clé
sans toucher à la base.

**Clé définitivement perdue.** Démarrez une fois avec `OPBS_ACCEPT_NEW_CREDENTIALS_KEY=1` dans
`.env` (puis retirez la ligne) : l'API accepte la clé en place. Ressaisissez ensuite les
identifiants depuis le panel (modules, fournisseurs, SSO, webhooks). La double authentification
ne peut plus être vérifiée, ni donc désactivée depuis l'application : faites-le depuis le serveur,
compte par compte —

```bash
docker compose -p opbs -f docker-compose.images.yml run --rm api node dist/cli/reset-2fa.js admin@hebergeur.fr
docker compose -p opbs -f docker-compose.images.yml run --rm api node dist/cli/reset-2fa.js --client client@exemple.fr
```

**Volume de secrets perdu, base conservée** (volume supprimé à la main, base copiée seule sur un
autre serveur) : `init-secrets` refuse alors de démarrer l'instance, car régénérer le mot de passe
ou la clé rendrait la base inutilisable. Pour réparer, donnez au volume la clé d'origine et un
nouveau mot de passe, par le `.env`, puis appliquez ce mot de passe à la base :

```bash
echo "CREDENTIALS_ENCRYPTION_KEY=<la clé exportée>" >> .env
echo "POSTGRES_PASSWORD=$(openssl rand -hex 32)" >> .env
docker compose -p opbs -f docker-compose.images.yml up -d
# La base a gardé son ancien mot de passe : l'API ne s'y connecte pas encore. On l'aligne par le
# socket local du conteneur Postgres, qui n'en demande pas, puis on relance l'API et le worker.
docker compose -p opbs -f docker-compose.images.yml exec postgres psql -U opbs \
  -c "ALTER USER opbs PASSWORD '$(grep '^POSTGRES_PASSWORD=' .env | cut -d= -f2)'"
docker compose -p opbs -f docker-compose.images.yml restart api worker
```

Une valeur de `.env` n'initialise qu'un volume vide : les deux lignes peuvent ensuite quitter le
fichier.
`docker compose down -v`, lui, supprime les volumes de secrets avec la base — c'est une
réinstallation.

## Modules tiers

Un module (provisioning, paiement, notification, thème, DNS, registrar, add-on) se dépose dans le
dossier pointé par `EXTENSIONS_DIR` (défaut : `./extensions`, à côté du fichier compose), monté en
lecture seule dans les conteneurs `api` et `worker`. Aucune reconstruction d'image n'est nécessaire : un
redémarrage (`docker compose ... restart api worker`) suffit à charger un module ajouté ou modifié.

## Assistance

Ce dépôt est synchronisé automatiquement depuis `Friirus/opbs` (dépôt principal, privé) à chaque
changement de `infra/` — n'ouvrez pas de pull request ici, elle serait écrasée à la prochaine
synchronisation. Pour un bug ou une question sur le produit lui-même, contactez le mainteneur.
