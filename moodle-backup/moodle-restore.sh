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

printf '\033[38;5;33mMoodle Docker Wiederherstellungs-Tool\n-------------------------------\n\033[0m'

BACKUPS=($(ls -1t "$BACKUP_DIR"/*.tar.gz | head -n 20))

gum style --border normal --padding "1 2" --border-foreground 33 <<EOF
0. Beenden
$(printf '%s\n' "${BACKUPS[@]}" | nl -w1 -s'. ')
EOF

echo

read -p "Gib die Nummer des Backups ein, das du wiederherstellen möchtest (0 zum Beenden): " SELECTION

if [[ "$SELECTION" == "0" ]]; then
  echo "Beende..."
  exit 0
fi

if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || (( SELECTION < 1 || SELECTION > ${#BACKUPS[@]} )); then
  print_cmsg "Ungültige Auswahl. Beende."
  exit 1
fi

BACKUP_FILE="${BACKUPS[$((SELECTION-1))]}"
print_cmsg "Ausgewähltes Backup: $BACKUP_FILE"

print_cmsg "Stoppe Webserver im Container '$CONTAINER_MOODLE'..."
docker exec "$CONTAINER_MOODLE" service apache2 stop
echo

TMP_DIR=$(mktemp -d)

tar -xzf "$BACKUP_FILE" -C "$TMP_DIR"

if [[ -d "$TMP_DIR/moodle" ]]; then
  print_cmsg "Stelle Moodle-Dateien im Container '$CONTAINER_MOODLE' wieder her..."
  docker cp "$TMP_DIR/moodle" "$CONTAINER_MOODLE":/var/www/html
  docker exec "$CONTAINER_MOODLE" chown -R www-data:www-data /var/www/html
else
  print_cmsg "Keine Moodle-Webdateien im Backup gefunden. Datei-Wiederherstellung wird übersprungen."
fi

if [[ -f "$TMP_DIR/db.sql" ]]; then
  print_cmsg "Stelle Datenbank im Container '$CONTAINER_DB' wieder her..."
  cat "$TMP_DIR/db.sql" | docker exec -i "$CONTAINER_DB" \
    bash -c "mysql -u$MYSQL_ROOT_USER -p'$MYSQL_ROOT_PASSWORD' $MYSQL_DATABASE"
else
  print_cmsg "Kein Datenbank-Dump im Backup gefunden. Datenbank-Wiederherstellung wird übersprungen."
fi

rm -rf "$TMP_DIR"

print_cmsg "Starte Webserver im Container '$CONTAINER_MOODLE'..."
docker exec "$CONTAINER_MOODLE" service apache2 start

print_cmsg "Wiederherstellung abgeschlossen."

echo -e "\e[1;91mBitte starte Docker Compose neu\e[0m"