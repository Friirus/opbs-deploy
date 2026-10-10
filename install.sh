#!/usr/bin/env bash
# Installe (ou met à jour) une instance opbs sur ce serveur, en une commande.
#
#   curl -fsSLO https://raw.githubusercontent.com/Friirus/opbs-deploy/main/install.sh
#   less install.sh      # le relire avant de l'exécuter
#   bash install.sh
#
# Dans l'ordre :
#   1. vérifie Docker et Docker Compose v2 ;
#   2. récupère les fichiers de déploiement, sauf s'il tourne déjà dans leur dossier ;
#   3. demande le domaine et l'adresse Let's Encrypt, vérifie le DNS, et écrit lui-même le .env —
#      personne n'a à ouvrir ce fichier ;
#   4. laisse de côté le Caddy fourni si les ports 80/443 sont déjà pris (nginx, Apache…) ;
#   5. démarre l'instance (ses secrets sont générés au premier démarrage), attend qu'elle réponde,
#      puis affiche le lien de l'assistant d'installation, jeton compris, et la clé de chiffrement
#      à conserver hors du serveur.
#
# Relancé, il ne régénère aucun secret et ne réécrit pas le .env : il récupère la dernière version
# des fichiers et des images, puis redémarre. C'est aussi la commande de mise à jour — lire avant
# les entrées MAJEUR de CHANGELOG.md.
#
# Sans terminal (Ansible, cloud-init), tout passe par l'environnement :
#   OPBS_DOMAIN=exemple.fr OPBS_ACME_EMAIL=contact@exemple.fr \
#     OPBS_KEY_FILE=/root/cle-opbs.txt bash install.sh
# Facultatifs : OPBS_DIR (dossier d'installation), OPBS_VERSION (tag d'images, défaut latest),
# OPBS_BUNDLED_PROXY (1 ou 0, sinon déduit des ports), OPBS_SKIP_DNS_CHECK=1, OPBS_PROJECT,
# OPBS_COMPOSE_FILE (essais depuis le dépôt source).
set -euo pipefail

DEPLOY_REPO="https://github.com/Friirus/opbs-deploy.git"
DEPLOY_RAW="https://raw.githubusercontent.com/Friirus/opbs-deploy/main"
DEPLOY_FILES=(docker-compose.images.yml Caddyfile backup.sh restore.sh install.sh .env.example README.md CHANGELOG.md)
PROJECT="${OPBS_PROJECT:-opbs}"

say() { printf '%s\n' "$*"; }
warn() { printf 'Attention : %s\n' "$*" >&2; }
die() {
  printf 'Erreur : %s\n' "$*" >&2
  exit 1
}

# Questions posées au terminal même quand le script arrive par un tube (`curl … | bash`) : stdin
# est alors le script lui-même, /dev/tty reste le clavier. Sans terminal du tout, aucune question.
if [ -t 0 ]; then
  TTY=/dev/stdin
elif [ -r /dev/tty ] && (exec </dev/tty) 2>/dev/null; then
  TTY=/dev/tty
else
  TTY=""
fi
ask() {
  local prompt="$1" answer
  [ -n "$TTY" ] || return 1
  read -r -p "$prompt" answer <"$TTY"
  printf '%s' "$answer"
}
confirm() {
  local answer
  answer="$(ask "$1 [o/N] ")" || return 1
  [[ "$answer" =~ ^[oOyY] ]]
}

# --- 1. Docker ----------------------------------------------------------------------------------

command -v docker >/dev/null 2>&1 || die "Docker est introuvable. Installez-le d'abord : https://docs.docker.com/engine/install/"
docker compose version >/dev/null 2>&1 || die "Docker Compose v2 est introuvable (commande \`docker compose\`)."
docker info >/dev/null 2>&1 || die "Docker ne répond pas à cet utilisateur : lancez le script en root, ou ajoutez-le au groupe docker."

# --- 2. Fichiers de déploiement -----------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || pwd)"
if [ -n "${OPBS_COMPOSE_FILE:-}" ]; then
  DIR="${OPBS_DIR:-$(dirname "$OPBS_COMPOSE_FILE")}"
elif [ -f "$SCRIPT_DIR/docker-compose.images.yml" ] && [ -z "${OPBS_DIR:-}" ]; then
  DIR="$SCRIPT_DIR"
else
  if [ -n "${OPBS_DIR:-}" ]; then
    DIR="$OPBS_DIR"
  elif [ "$(id -u)" = "0" ]; then
    DIR=/opt/opbs
  else
    DIR="$HOME/opbs"
  fi
fi
mkdir -p "$DIR"
cd "$DIR"

if [ -z "${OPBS_COMPOSE_FILE:-}" ]; then
  if [ -d .git ]; then
    say "Mise à jour des fichiers de déploiement dans $DIR…"
    git pull --ff-only --quiet || warn "mise à jour des fichiers impossible, la version présente est conservée."
  elif [ ! -f docker-compose.images.yml ]; then
    say "Récupération des fichiers de déploiement dans $DIR…"
    if command -v git >/dev/null 2>&1 && [ -z "$(ls -A .)" ]; then
      git clone --quiet --depth 1 "$DEPLOY_REPO" .
    else
      command -v curl >/dev/null 2>&1 || die "ni git ni curl : impossible de récupérer les fichiers."
      for file in "${DEPLOY_FILES[@]}"; do
        curl -fsSL "$DEPLOY_RAW/$file" -o "$file"
      done
      chmod +x backup.sh restore.sh install.sh
    fi
  fi
  # Les modules déposés par l'hébergeur : créé ici plutôt que par Docker, qui le ferait en root
  # alors que les images tournent en utilisateur non privilégié.
  mkdir -p extensions
fi
COMPOSE_FILE="${OPBS_COMPOSE_FILE:-$DIR/docker-compose.images.yml}"
COMPOSE=(docker compose -p "$PROJECT" -f "$COMPOSE_FILE")
if [ -f .env ]; then
  COMPOSE+=(--env-file .env)
fi

# --- 3. Domaine, TLS, DNS -----------------------------------------------------------------------

is_public_domain() {
  [[ "$1" =~ ^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$ ]] && [[ ! "$1" =~ \.(test|local|localhost|internal|example)$ ]]
}

# Vérifie que les trois noms pointent vers ce serveur. Sans moyen fiable de connaître l'adresse
# publique (NAT, cloud), on compare aux adresses locales et on laisse trancher l'hébergeur : un
# DNS faux fait échouer Let's Encrypt, qui réessaie ensuite tout seul.
# L'une des adresses ($2…) est-elle portée par une interface de ce serveur ($1) ?
any_local() {
  local local_ips="$1" ip
  shift
  for ip in "$@"; do
    [[ "$local_ips" == *" $ip "* ]] && return 0
  done
  return 1
}

check_dns() {
  local domain="$1" name ips local_ips mismatch=0
  [ "${OPBS_SKIP_DNS_CHECK:-}" = "1" ] && return 0
  command -v getent >/dev/null 2>&1 || return 0
  local_ips=" $(hostname -I 2>/dev/null || true) "
  for name in "$domain" "admin.$domain" "status.$domain"; do
    ips="$(getent ahosts "$name" 2>/dev/null | awk '{print $1}' | sort -u | tr '\n' ' ' || true)"
    if [ -z "$ips" ]; then
      warn "$name ne résout vers aucune adresse."
      mismatch=1
    # shellcheck disable=SC2086 # découpage voulu : une adresse par argument
    elif ! any_local "$local_ips" $ips; then
      say "  $name → $ips(adresse que ce serveur ne voit pas sur ses interfaces : normal derrière un NAT)"
      mismatch=1
    else
      say "  $name → $ips✓"
    fi
  done
  if [ "$mismatch" = "1" ]; then
    say "Les trois noms doivent pointer vers ce serveur pour que Let's Encrypt délivre les certificats."
    if [ -n "$TTY" ] && ! confirm "Continuer quand même ?"; then
      die "installation interrompue : corrigez le DNS, puis relancez le script."
    fi
  fi
}

if [ -f .env ]; then
  say "Fichier .env existant conservé."
  DOMAIN="$(grep -E '^DOMAIN=' .env | tail -n1 | cut -d= -f2- || true)"
  DOMAIN="${DOMAIN:-localhost}"
else
  DOMAIN="${OPBS_DOMAIN:-}"
  if [ -z "$DOMAIN" ]; then
    DOMAIN="$(ask "Domaine de l'instance (ex. hebergeur.fr, vide = essai en local) : ")" || DOMAIN=""
  fi
  DOMAIN="$(printf '%s' "${DOMAIN:-localhost}" | tr '[:upper:]' '[:lower:]' | sed -E 's#^https?://##; s#/.*$##')"
  if [ "$DOMAIN" != "localhost" ] && ! [[ "$DOMAIN" =~ ^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9-]{2,}$ ]]; then
    die "« $DOMAIN » n'est pas un nom de domaine."
  fi

  TLS_MODE=internal
  if is_public_domain "$DOMAIN"; then
    EMAIL="${OPBS_ACME_EMAIL:-}"
    if [ -z "$EMAIL" ]; then
      EMAIL="$(ask "Adresse pour Let's Encrypt (avis d'expiration des certificats) : ")" || EMAIL=""
    fi
    [[ "$EMAIL" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]] \
      || die "une adresse e-mail valide est nécessaire pour un certificat Let's Encrypt (OPBS_ACME_EMAIL)."
    TLS_MODE="$EMAIL"
    say "Vérification du DNS :"
    check_dns "$DOMAIN"
  else
    say "Domaine « $DOMAIN » : certificat auto-signé (essai, pas de Let's Encrypt)."
  fi

  # --- 4. Reverse proxy ---------------------------------------------------------------------------
  PROXY="${OPBS_BUNDLED_PROXY:-}"
  if [ -z "$PROXY" ]; then
    PROXY=1
    if command -v ss >/dev/null 2>&1 && ss -ltnH '( sport = :80 or sport = :443 )' 2>/dev/null | grep -q .; then
      if [ -z "$(docker ps -q --filter "name=^${PROJECT}-reverse-proxy-")" ]; then
        say "Les ports 80/443 sont déjà pris sur ce serveur (nginx, Apache, Traefik… ?)."
        say "Le Caddy fourni est laissé de côté : à votre reverse proxy de router vers 127.0.0.1:3001-3004"
        say "(exemple de vhost nginx dans README.md, section « Reverse proxy »)."
        PROXY=0
      fi
    fi
  fi

  (
    umask 077
    {
      say "# Écrit par install.sh — réglages d'hébergement de cette instance. Aucun secret ici : ils"
      say "# sont générés au premier démarrage, dans des volumes Docker (voir README.md)."
      say "DOMAIN=$DOMAIN"
      say "TLS_MODE=$TLS_MODE"
      say "OPBS_BUNDLED_PROXY=$PROXY"
    } >.env
  )
  COMPOSE+=(--env-file .env)
  say "Fichier .env écrit."
fi

# --- 5. Démarrage -------------------------------------------------------------------------------

if [ -n "${OPBS_VERSION:-}" ]; then
  export OPBS_VERSION
fi
if [ -z "${OPBS_COMPOSE_FILE:-}" ]; then
  say "Téléchargement des images (${OPBS_VERSION:-latest})…"
  "${COMPOSE[@]}" pull --quiet
fi
say "Démarrage de l'instance…"
"${COMPOSE[@]}" up -d --remove-orphans

API_CONTAINER="$("${COMPOSE[@]}" ps -q api)"
for _ in $(seq 1 90); do
  STATUS="$(docker inspect --format '{{.State.Health.Status}}' "$API_CONTAINER" 2>/dev/null || true)"
  [ "$STATUS" = "healthy" ] && break
  sleep 2
done
if [ "${STATUS:-}" != "healthy" ]; then
  "${COMPOSE[@]}" logs --tail 30 init-secrets api >&2 || true
  die "l'API n'a pas démarré. Journal complet : docker compose -p $PROJECT -f $COMPOSE_FILE logs api"
fi

NEEDS_SETUP="$("${COMPOSE[@]}" exec -T api wget -qO- http://localhost:3001/api/v1/auth/staff/bootstrap/status 2>/dev/null || true)"
if [[ "$NEEDS_SETUP" != *'"needsSetup":true'* ]]; then
  say ""
  say "Instance à jour et démarrée : https://admin.$DOMAIN"
  exit 0
fi

TOKEN="$("${COMPOSE[@]}" run --rm --no-deps -T init-secrets print-setup-token)"
KEY="$("${COMPOSE[@]}" run --rm --no-deps -T init-secrets print-key)"

say ""
say "=============================================================================================="
say " Clé de chiffrement de l'instance"
say "=============================================================================================="
say " Elle déchiffre les identifiants rangés en base (modules, paiement, SSO, double"
say " authentification). Elle n'est PAS dans les sauvegardes de la base : perdue, ces identifiants"
say " le sont aussi. Conservez-la hors de ce serveur (gestionnaire de mots de passe). Elle ne"
say " change jamais ; ./backup.sh --export-key la réaffiche."
say ""
if [ -n "${OPBS_KEY_FILE:-}" ]; then
  (umask 077 && printf '%s\n' "$KEY" >"$OPBS_KEY_FILE")
  say " Écrite dans $OPBS_KEY_FILE : déplacez ce fichier hors du serveur."
elif [ -n "$TTY" ]; then
  say "   $KEY"
  say ""
  while true; do
    answer="$(ask " Tapez « oui » une fois la clé conservée hors de ce serveur : ")" \
      || die "clé non confirmée. Réaffichez-la avec ./backup.sh --export-key, puis relancez ce script."
    [ "$answer" = "oui" ] && break
  done
else
  warn "aucun terminal et OPBS_KEY_FILE vide : exportez la clé maintenant avec ./backup.sh --export-key"
fi

say ""
say "=============================================================================================="
say " Dernière étape, dans votre navigateur :"
say ""
say "   https://admin.$DOMAIN/setup#token=$TOKEN"
say ""
say " Le jeton prouve que vous avez accès au serveur ; il ne sert plus à rien une fois le compte"
say " administrateur créé. Pensez à programmer ./backup.sh (cron), voir README.md."
say "=============================================================================================="
