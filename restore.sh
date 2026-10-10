#!/usr/bin/env bash
# Restaure une sauvegarde produite par backup.sh. DESTRUCTIF : écrase la base courante.
#
# À lancer depuis le dossier de l'instance — `./infra/restore.sh` depuis la racine de ce dépôt,
# `./restore.sh` depuis le dépôt de déploiement (opbs-deploy) :
#   ./restore.sh chemin/vers/opbs-XXXXXXXX-XXXXXX.sql.gz
#   ./restore.sh s3://mon-bucket-backups/opbs-XXXXXXXX-XXXXXX.sql.gz   (télécharge d'abord)
#
# Sur un nouveau serveur, restaurer aussi la clé de chiffrement exportée par
# `backup.sh --export-key` : le premier démarrage y a généré une clé neuve, étrangère à la base
# restaurée, et l'API refuserait de démarrer (témoin de clé) plutôt que de servir des secrets
# illisibles.
#   ./restore.sh --key-file cle-opbs.txt chemin/vers/opbs-XXXXXXXX-XXXXXX.sql.gz
#   ./restore.sh --key-file cle-opbs.txt      (la clé seule, base déjà restaurée)
set -euo pipefail

USAGE="Usage: ./restore.sh [--key-file <fichier de clé>] [<fichier .sql.gz ou s3://...>]"
KEY_FILE=""
if [ "${1:-}" = "--key-file" ]; then
  KEY_FILE="${2:?$USAGE}"
  shift 2
fi
BACKUP_FILE="${1:-}"
if [ -z "$KEY_FILE" ] && [ -z "$BACKUP_FILE" ]; then
  echo "$USAGE" >&2
  exit 1
fi
if [ -n "$KEY_FILE" ] && [ ! -f "$KEY_FILE" ]; then
  echo "Fichier de clé introuvable : $KEY_FILE" >&2
  exit 1
fi

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

if [ -n "$BACKUP_FILE" ] && [ ! -f "$BACKUP_FILE" ]; then
  echo "Fichier introuvable : $BACKUP_FILE" >&2
  exit 1
fi

if [ -n "$BACKUP_FILE" ]; then
  PROMPT="Ceci va écraser la base 'opbs' de l'instance courante avec le contenu de $SOURCE_LABEL"
  [ -n "$KEY_FILE" ] && PROMPT="$PROMPT, et remplacer sa clé de chiffrement par celle de $KEY_FILE"
else
  PROMPT="Ceci va remplacer la clé de chiffrement de l'instance courante par celle de $KEY_FILE"
fi
read -r -p "$PROMPT. Continuer ? [y/N] " confirm
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
# Même surcharge que backup.sh : restaurer dans la mauvaise pile est irréversible. `.env` est
# facultatif, et Compose refuse un `--env-file` absent.
COMPOSE=(docker compose -p "${OPBS_PROJECT:-opbs}" -f "$COMPOSE_FILE")
if [ -f .env ]; then
  COMPOSE+=(--env-file .env)
fi

# Coupe les writers pour éviter que l'API/le worker n'écrivent pendant la restauration.
"${COMPOSE[@]}" stop api worker

if [ -n "$KEY_FILE" ]; then
  # `run` du service init-secrets : il monte le volume de secrets, sans réseau, et valide la clé
  # avant d'écrire quoi que ce soit.
  "${COMPOSE[@]}" run --rm --no-deps -T init-secrets import-key < "$KEY_FILE"
fi

if [ -n "$BACKUP_FILE" ]; then
  "${COMPOSE[@]}" exec -T postgres psql -U opbs -d opbs -v ON_ERROR_STOP=1 \
    -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
  gunzip -c "$BACKUP_FILE" | "${COMPOSE[@]}" exec -T postgres psql -U opbs -d opbs -v ON_ERROR_STOP=1
fi

"${COMPOSE[@]}" start api worker

# L'API relit au démarrage le témoin de la clé de chiffrement : une clé qui n'est pas celle de la
# base restaurée l'empêche de devenir saine. Attendre ici dit tout de suite si la restauration est
# utilisable, au lieu de le découvrir au premier identifiant illisible.
API_CONTAINER="$("${COMPOSE[@]}" ps -q api)"
for _ in $(seq 1 60); do
  STATUS="$(docker inspect --format '{{.State.Health.Status}}' "$API_CONTAINER" 2>/dev/null || true)"
  if [ "$STATUS" = "healthy" ]; then
    echo "Restauration terminée : l'API a redémarré avec la clé de cette base."
    exit 0
  fi
  sleep 2
done
echo "L'API n'est pas redevenue saine. Si son journal parle de la clé de chiffrement, relancez avec" >&2
echo "--key-file et la clé exportée depuis l'instance d'origine : docker compose logs api" >&2
exit 1
