#!/usr/bin/env bash
# Restaure une sauvegarde produite par backup.sh. DESTRUCTIF : écrase la base courante.
#
# À lancer depuis le dossier qui contient le .env de l'instance — `./infra/restore.sh` depuis la
# racine de ce dépôt, `./restore.sh` depuis le dépôt de déploiement (opbs-deploy) :
#   ./restore.sh chemin/vers/opbs-XXXXXXXX-XXXXXX.sql.gz
#   ./restore.sh s3://mon-bucket-backups/opbs-XXXXXXXX-XXXXXX.sql.gz   (télécharge d'abord)
set -euo pipefail

BACKUP_FILE="${1:?Usage: ./restore.sh <fichier .sql.gz ou s3://...>}"
SOURCE_LABEL="$BACKUP_FILE"
CLEANUP_FILE=""
trap '[ -n "$CLEANUP_FILE" ] && rm -f "$CLEANUP_FILE"' EXIT

if [[ "$BACKUP_FILE" == s3://* ]]; then
  if ! command -v aws >/dev/null 2>&1; then
    echo "AWS CLI introuvable — impossible de télécharger $BACKUP_FILE" >&2
    exit 1
  fi
  S3_ARGS=()
  BACKUP_S3_ENDPOINT_URL="${BACKUP_S3_ENDPOINT_URL:-}"
  if [ -z "$BACKUP_S3_ENDPOINT_URL" ] && [ -f .env ]; then
    BACKUP_S3_ENDPOINT_URL="$(grep -E '^BACKUP_S3_ENDPOINT_URL=' .env | tail -n1 | cut -d= -f2- || true)"
  fi
  if [ -n "$BACKUP_S3_ENDPOINT_URL" ]; then
    S3_ARGS+=(--endpoint-url "$BACKUP_S3_ENDPOINT_URL")
  fi
  LOCAL_COPY="$(mktemp -t opbs-restore-XXXXXX.sql.gz)"
  CLEANUP_FILE="$LOCAL_COPY"
  echo "Téléchargement de $BACKUP_FILE..."
  aws s3 cp "${S3_ARGS[@]}" "$BACKUP_FILE" "$LOCAL_COPY"
  BACKUP_FILE="$LOCAL_COPY"
fi

if [ ! -f "$BACKUP_FILE" ]; then
  echo "Fichier introuvable : $BACKUP_FILE" >&2
  exit 1
fi

read -r -p "Ceci va écraser la base 'opbs' de l'instance courante avec le contenu de $SOURCE_LABEL. Continuer ? [y/N] " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
  echo "Annulé."
  exit 1
fi

# Même résolution que backup.sh (voir son commentaire pour le pourquoi de l'ordre) : le fichier
# compose vit à côté du script, et n'a ni le même nom ni le même chemin dans ce dépôt et dans celui
# de déploiement.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -n "${OPBS_COMPOSE_FILE:-}" ]; then
  COMPOSE_FILE="$OPBS_COMPOSE_FILE"
elif [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
  COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
else
  COMPOSE_FILE="$SCRIPT_DIR/docker-compose.images.yml"
fi

# Tableau plutôt qu'une chaîne : le chemin résolu ci-dessus est absolu et peut contenir un espace,
# qu'une expansion non quotée découperait en deux arguments.
# Même surcharge que backup.sh : restaurer dans la mauvaise pile est irréversible.
COMPOSE=(docker compose -p "${OPBS_PROJECT:-opbs}" -f "$COMPOSE_FILE" --env-file .env)

# Coupe les writers pour éviter que l'API/le worker n'écrivent pendant la restauration.
"${COMPOSE[@]}" stop api worker

"${COMPOSE[@]}" exec -T postgres psql -U opbs -d opbs -v ON_ERROR_STOP=1 \
  -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
gunzip -c "$BACKUP_FILE" | "${COMPOSE[@]}" exec -T postgres psql -U opbs -d opbs -v ON_ERROR_STOP=1

"${COMPOSE[@]}" start api worker

echo "Restauration terminée."
