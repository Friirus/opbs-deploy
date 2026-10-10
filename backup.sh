#!/usr/bin/env bash
# Sauvegarde la base Postgres d'une instance en un fichier compressé horodaté, puis la copie
# hors-site sur S3 (ou compatible S3 : MinIO, Backblaze B2, OVH...) si configuré.
#
# À lancer depuis le dossier de l'instance (celui du .env, s'il y en a un) :
#   - depuis les sources (ce dépôt), à la racine :        ./infra/backup.sh [dossier de sortie]
#   - depuis le dépôt de déploiement (opbs-deploy) :      ./backup.sh [dossier de sortie]
# Le fichier compose est résolu à côté du script (voir plus bas), pas depuis le répertoire courant.
#
# La sauvegarde ne contient PAS la clé de chiffrement de l'instance (CREDENTIALS_ENCRYPTION_KEY),
# générée au premier démarrage et rangée hors de la base : sans elle, les identifiants chiffrés du
# dump (modules, fournisseurs, SSO, webhooks, double authentification) sont illisibles. Elle ne
# change jamais : l'exporter une fois, et la conserver ailleurs que les sauvegardes (gestionnaire
# de mots de passe, coffre hors ligne) :
#   ./backup.sh --export-key                 # l'affiche
#   ./backup.sh --export-key cle-opbs.txt    # l'écrit dans un fichier lisible par vous seul
# Une clé rangée à côté des dumps rendrait leur chiffrement inutile.
#
# Copie hors-site : renseigner dans .env
#   BACKUP_S3_BUCKET=mon-bucket-backups
#   BACKUP_S3_ENDPOINT_URL=https://s3.fr-par.scw.cloud   # vide = AWS S3
# et exporter les identifiants standard de l'AWS CLI (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY,
# AWS_DEFAULT_REGION) dans l'environnement qui lance ce script — jamais dans .env, qui fournit les
# réglages des conteneurs : une clé de sauvegarde n'a rien à y faire. La rétention hors-site (ex:
# 30 jours) se configure via une règle de cycle de vie côté bucket, pas ici : réimplémenter une
# purge S3 en bash est une source classique de suppressions non voulues.
#
# Exemple de cron (tous les jours à 3h, local conservé 14 jours) :
#   0 3 * * * cd /path/to/opbs-deploy && ./backup.sh /var/backups/opbs && find /var/backups/opbs -name '*.sql.gz' -mtime +14 -delete
set -euo pipefail

# Le même script sert dans les deux dépôts, qui n'ont ni la même arborescence ni le même fichier
# compose : `infra/docker-compose.yml` ici (build depuis les sources), `docker-compose.images.yml`
# à la racine du dépôt de déploiement. Résoudre depuis l'emplacement du script plutôt que depuis
# le répertoire courant est la seule forme qui marche des deux côtés — un chemin en dur y était
# faux d'un côté et cassait la sauvegarde en silence, dans un cron.
#
# C'est bien la présence de `docker-compose.yml` qui départage, et non celle du fichier `images` :
# les deux cohabitent dans `infra/`, seul le dépôt de déploiement n'a que le second. Tester
# l'inverse renvoyait le monorepo vers le compose par images, qui n'y est pas la pile démarrée.
# Pour déployer par images depuis les sources, forcer `OPBS_COMPOSE_FILE`.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -n "${OPBS_COMPOSE_FILE:-}" ]; then
  COMPOSE_FILE="$OPBS_COMPOSE_FILE"
elif [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
  COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
else
  COMPOSE_FILE="$SCRIPT_DIR/docker-compose.images.yml"
fi

# Le nom de projet suit la même règle que le fichier compose : `opbs` partout dans la
# documentation, surchargeable pour qui fait tourner une seconde pile (instance de test, essai de
# restauration) sur la même machine — sauvegarder la mauvaise est plus coûteux que de le paramétrer.
PROJECT="${OPBS_PROJECT:-opbs}"

# `.env` est facultatif : passé seulement s'il existe, Compose refusant un `--env-file` absent.
COMPOSE=(docker compose -p "$PROJECT" -f "$COMPOSE_FILE")
if [ -f .env ]; then
  COMPOSE+=(--env-file .env)
fi

if [ "${1:-}" = "--export-key" ]; then
  KEY="$("${COMPOSE[@]}" run --rm --no-deps -T init-secrets print-key)"
  if [ -n "${2:-}" ]; then
    (umask 077 && printf '%s\n' "$KEY" > "$2")
    echo "Clé de chiffrement écrite dans $2 (lisible par vous seul). Rangez-la hors de ce serveur." >&2
  else
    echo "Clé de chiffrement de l'instance — à conserver hors de ce serveur et hors des sauvegardes :" >&2
    printf '%s\n' "$KEY"
  fi
  exit 0
fi

OUT_DIR="${1:-./backups}"
mkdir -p "$OUT_DIR"

# BACKUP_S3_* ne sont pas des secrets : on les lit depuis .env pour rester cohérent avec le reste
# du repo (fichier de config unique). Les identifiants AWS, eux, restent hors de .env — voir
# ci-dessus.
if [ -z "${BACKUP_S3_BUCKET:-}" ] && [ -f .env ]; then
  BACKUP_S3_BUCKET="$(grep -E '^BACKUP_S3_BUCKET=' .env | tail -n1 | cut -d= -f2- || true)"
fi
if [ -z "${BACKUP_S3_ENDPOINT_URL:-}" ] && [ -f .env ]; then
  BACKUP_S3_ENDPOINT_URL="$(grep -E '^BACKUP_S3_ENDPOINT_URL=' .env | tail -n1 | cut -d= -f2- || true)"
fi

TIMESTAMP="$(date -u +%Y%m%d-%H%M%S)"
OUT_FILE="$OUT_DIR/opbs-$TIMESTAMP.sql.gz"

"${COMPOSE[@]}" exec -T postgres pg_dump -U opbs --format=plain opbs | gzip > "$OUT_FILE"

echo "Sauvegarde écrite dans $OUT_FILE"
echo "Rappel : la clé de chiffrement n'est pas dans cette sauvegarde (./backup.sh --export-key)."

if [ -n "${BACKUP_S3_BUCKET:-}" ]; then
  if ! command -v aws >/dev/null 2>&1; then
    echo "BACKUP_S3_BUCKET est configuré mais l'AWS CLI est introuvable — copie hors-site impossible." >&2
    exit 1
  fi
  S3_ARGS=()
  if [ -n "${BACKUP_S3_ENDPOINT_URL:-}" ]; then
    S3_ARGS+=(--endpoint-url "$BACKUP_S3_ENDPOINT_URL")
  fi
  aws s3 cp "${S3_ARGS[@]}" "$OUT_FILE" "s3://${BACKUP_S3_BUCKET}/$(basename "$OUT_FILE")"
  echo "Copié hors-site vers s3://${BACKUP_S3_BUCKET}/$(basename "$OUT_FILE")"
fi
