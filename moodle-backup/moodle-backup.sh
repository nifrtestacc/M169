#!/bin/bash

print_cmsg() {
  if [[ "$1" == "-n" ]]; then
    shift
    echo -ne "\e[1m$*\e[0m"
  else
    echo -e "\e[1m$*\e[0m"
  fi
}

if [[ -f "./.env" ]]; then
  source "./.env"
  print_cmsg ".env-Datei im lokalen Verzeichnis gefunden und geladen."
else
  print_cmsg ".env-Datei wurde im lokalen Verzeichnis nicht gefunden. Beende Skript."
  exit 1
fi

MODE="interactive"
LOG_FILE="$LOG_DIR/moodle-backup/running-backup.log"

printf '\033[38;5;33mMoodle Docker Sicherungs-Tool\n-------------------------------\n\033[0m'

case "$1" in
  --db-only)
    MODE="db"
    ;;
  --moodle-only)
    MODE="moodle"
    ;;
  --full)
    MODE="full"
    ;;
  --help)
    echo "Verwendung: $0 [--full | --db-only | --moodle-only]"
    exit 0
    ;;
  "")
    MODE="interactive"
    ;;
  *)
    echo "Ungültiges Argument: $1"
    exit 1
    ;;

esac

if [[ "$MODE" != "interactive" ]]; then
  case "$MODE" in
    full)
      print_cmsg "Modus: Vollständiges Backup (DB + Moodle-Dateien)" | tee -a "$LOG_FILE"
      ;;
    db)
      print_cmsg "Modus: Nur Datenbank" | tee -a "$LOG_FILE"
      ;;
    moodle)
      print_cmsg "Modus: Nur Moodle-Dateien" | tee -a "$LOG_FILE"
      ;;
  esac
fi

if [[ "$MODE" == "interactive" ]]; then
  OPTIONS=(
    "Vollständiges Backup (DB + moodledata)"
    "Nur Datenbank"
    "Nur moodledata"
    "Beenden"
  )

  gum style --border normal --padding "1 2" --border-foreground 33 <<EOF
Was möchtest du sichern?

$(printf '%s\n' "${OPTIONS[@]}" | nl -w1 -s'. ')
EOF
  echo
  read -p "Gib die Nummer deiner Auswahl ein: " SELECTION

  case "$SELECTION" in
    1) MODE="full" ;;
    2) MODE="db" ;;
    3) MODE="moodle" ;;
    4) echo "Beende..."; exit 0 ;;
    *) echo "Ungültige Auswahl. Beende."; exit 0 ;;
  esac
fi

case "$MODE" in
  full)
    SUFFIX="FULL"
    ;;
  moodle)
    SUFFIX="MOODLE"
    ;;
  db)
    SUFFIX="DUMP"
    ;;
  *)
    SUFFIX="BACKUP"
    ;;
esac

MOODLE_VERSION=$(docker exec "$CONTAINER_MOODLE" \
  bash -c "sed -n \"s/.*\\\$release *= *'\([0-9.]*\).*/\1/p\" /var/www/html/version.php")

TIMESTAMP=$(date "+%Y%m%d-%H%M")
FILENAME="${MOODLE_VERSION}_${TIMESTAMP}_${SUFFIX}.tar.gz"

print_cmsg "\nStoppe Webserver im Container '$CONTAINER_MOODLE'..." | tee -a "$LOG_FILE"
docker exec "$CONTAINER_MOODLE" service apache2 stop
echo

TMP_DIR=$(mktemp -d)

if [[ "$MODE" == "db" || "$MODE" == "full" ]]; then
  print_cmsg "Erstelle Datenbank-Dump aus Container '$CONTAINER_DB'..." | tee -a "$LOG_FILE"
  docker exec "$CONTAINER_DB" \
    bash -c "mysqldump -u$MYSQL_ROOT_USER -p'$MYSQL_ROOT_PASSWORD' $MYSQL_DATABASE > /tmp/dump.sql"
  docker cp "$CONTAINER_DB":/tmp/dump.sql "$TMP_DIR/db.sql"
fi

if [[ "$MODE" == "moodle" || "$MODE" == "full" ]]; then
  print_cmsg "Kopiere Moodle-Dateien aus Container '$CONTAINER_MOODLE'..." | tee -a "$LOG_FILE"
  docker cp "$CONTAINER_MOODLE":/var/www/html "$TMP_DIR/moodle"
fi

print_cmsg "Starte Webserver im Container '$CONTAINER_MOODLE'..." | tee -a "$LOG_FILE"
docker exec "$CONTAINER_MOODLE" service apache2 start

print_cmsg "Erstelle Archiv..." | tee -a "$LOG_FILE"

FILES_TO_ARCHIVE=()
if [[ "$MODE" == "db" || "$MODE" == "full" ]]; then
  FILES_TO_ARCHIVE+=("db.sql")
fi
if [[ "$MODE" == "moodle" || "$MODE" == "full" ]]; then
  FILES_TO_ARCHIVE+=("moodle")
fi

if tar -czf "$BACKUP_DIR/$FILENAME" -C "$TMP_DIR" "${FILES_TO_ARCHIVE[@]}"; then
  print_cmsg "Backup abgeschlossen: $BACKUP_DIR/$FILENAME" | tee -a "$LOG_FILE"
  rm -rf "$TMP_DIR"
else
  echo "Fehler: Backup konnte nicht erstellt werden. Temporäre Dateien bleiben zur Analyse in $TMP_DIR."
fi

mv "$LOG_FILE" "$LOG_DIR/moodle-backup/$FILENAME.log"