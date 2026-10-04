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
git clone https://github.com/Friirus/opbs-deploy.git
cd opbs-deploy
cp .env.example .env
OPBS_VERSION=1.0.0 docker compose -p opbs -f docker-compose.images.yml --env-file .env up -d
```

À renseigner dans `.env` avant le premier démarrage : `POSTGRES_PASSWORD`, `DOMAIN`, `TLS_MODE`,
`CREDENTIALS_ENCRYPTION_KEY` (`openssl rand -base64 32`) et les quatre secrets `JWT_*`
(`openssl rand -base64 48` chacun, tous différents). `STRIPE_*` et `SMTP_*` peuvent attendre : sans
Stripe vous encaissez par virement pointé à la main, sans SMTP les e-mails sont écrits dans les
journaux au lieu d'être envoyés.

Toujours lancer `docker compose` depuis la racine de ce dépôt, avec `-f docker-compose.images.yml
--env-file .env`. `OPBS_VERSION` fixe la version exacte déployée (recommandé en production) ; sans
elle, `latest` suit la dernière publication.

Première configuration : ouvrez `https://admin.<votredomaine>/setup` pour créer le compte
administrateur, renseigner le branding et connecter votre infrastructure de provisioning
(Proxmox par défaut ; d'autres hyperviseurs/panels via un module tiers, voir la documentation des
extensions du dépôt principal).

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
gère les certificats TLS des trois noms sans configuration. C'est le profil `bundled-proxy`, activé
par la ligne `COMPOSE_PROFILES=bundled-proxy` de votre `.env`.

Si ce serveur héberge déjà nginx, Apache ou Traefik, videz cette ligne : le service Caddy ne
démarre plus, et les quatre applications restent jointes sur la boucle locale.

**Sur une instance déjà démarrée avec Caddy, vider la variable ne suffit pas** : Docker Compose
ignore les conteneurs d'un profil désactivé au lieu de les arrêter, y compris pour un `down`. Le
Caddy déjà lancé continuerait donc de tenir les ports 80 et 443, et votre propre serveur web
refuserait de démarrer. Il faut le retirer en nommant son profil, une fois :

```bash
docker compose -p opbs -f docker-compose.images.yml --env-file .env --profile bundled-proxy down
# puis vider COMPOSE_PROFILES dans .env, et redémarrer normalement
docker compose -p opbs -f docker-compose.images.yml --env-file .env up -d
```

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
    location /api/v1/ { proxy_pass http://127.0.0.1:3001; }
    location / { proxy_pass http://127.0.0.1:3003; }
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

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
OPBS_VERSION=<nouvelle version> docker compose -p opbs -f docker-compose.images.yml --env-file .env up -d
```

Seule `OPBS_VERSION` détermine la version déployée : un `git pull` dans ce dépôt ne rapporte que
les fichiers de déploiement, mis à jour beaucoup plus rarement que le produit lui-même.

Les migrations de base de données s'appliquent automatiquement au démarrage — pas d'étape
manuelle à part le redémarrage des conteneurs. Avant de mettre à jour : sauvegarder (voir
ci-dessous), et consulter le `CHANGELOG.md` livré dans ce dépôt pour repérer une éventuelle mention
**MAJEUR**, qui signale une intervention manuelle requise avant ou après le redémarrage. Les
versions publiées sont celles listées sur
[les packages `opbs-*`](https://github.com/Friirus?tab=packages).

## Sauvegarde / restauration

`backup.sh [dossier]` dump la base Postgres de l'instance courante en `.sql.gz` horodaté (défaut :
`./backups`). À planifier en cron, par exemple tous les jours à 3h avec rétention de 14 jours :

```bash
0 3 * * * cd /chemin/vers/opbs-deploy && ./backup.sh /var/backups/opbs && find /var/backups/opbs -name '*.sql.gz' -mtime +14 -delete
```

`restore.sh <fichier.sql.gz>` restaure une sauvegarde — **destructif** : coupe `api`/`worker`,
écrase le schéma `public`, les redémarre. Toujours tester une restauration sur une instance de
secours avant d'en avoir besoin en urgence.

## Modules tiers

Un module (provisioning, paiement, notification, thème, DNS, registrar, add-on) se dépose dans le
dossier pointé par `EXTENSIONS_DIR` dans votre `.env` (défaut : `./extensions`), monté en lecture
seule dans les conteneurs `api` et `worker`. Aucune reconstruction d'image n'est nécessaire : un
redémarrage (`docker compose ... restart api worker`) suffit à charger un module ajouté ou modifié.

## Assistance

Ce dépôt est synchronisé automatiquement depuis `Friirus/opbs` (dépôt principal, privé) à chaque
changement de `infra/` — n'ouvrez pas de pull request ici, elle serait écrasée à la prochaine
synchronisation. Pour un bug ou une question sur le produit lui-même, contactez le mainteneur.
