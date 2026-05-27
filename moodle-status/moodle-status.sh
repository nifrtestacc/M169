#!/bin/bash

if [[ -f "./.env" ]]; then
  source "./.env"
  echo ".env-Datei im lokalen Verzeichnis gefunden und geladen."
else
  echo ".env-Datei wurde im lokalen Verzeichnis nicht gefunden. Beende Skript."
  exit 1
fi

clear

WIDTH=100
BLUE="33"

title_box_content=$(cat <<'EOF'
 __  __              _ _       ___          _             ___ _        _           
|  \/  |___  ___  __| | |___  |   \ ___  __| |_____ _ _  / __| |_ __ _| |_ _  _ ___
| |\/| / _ \/ _ \/ _` | / -_) | |) / _ \/ _| / / -_) '_| \__ \  _/ _` |  _| || (_-<
|_|  |_\___/\___/\__,_|_\___| |___/\___/\__|_\_\___|_|   |___/\__\__,_|\__|\_,_/__/

                      Willkommen auf der Moodle-Statusseite
      alle noetigen Dienste koennen mit dieser TUI gestartet und ueberwacht werden

            Falls Probleme auftreten, pruefe bitte das GitHub-Repository:
                      https://github.com/luccaa79/m169
EOF
)

title_box=$(gum style --border rounded --padding "1 3" --width $WIDTH <<< "$title_box_content")

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  running_projects=$(docker compose ls | tail -n +2 | awk '{print $2}' | grep -c "running")

  if [ "$running_projects" -gt 0 ]; then
    compose_icon="[OK]"
    compose_message="Docker Compose laeuft"
  else
    compose_icon="[X]"
    compose_message="Kein Docker-Compose-Projekt laeuft"
  fi
else
  compose_icon="[X]"
  compose_message="Docker-Compose-Befehl ist nicht verfuegbar"
fi

compose_status_box=$(gum style --border rounded --padding "1 3" --width $WIDTH \
  --border-foreground $BLUE <<< "$compose_icon   $compose_message")

docker_status=$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null)
docker_status="${docker_status:-Docker ist nicht verfuegbar}"

docker_box=$(gum style --border rounded --padding "1 3" --width $WIDTH <<< \
"$(gum style --bold <<< "Docker-Container-Status:")"$'\n'"$docker_status")

dumps_list=$(ls /opt/moodle-docker/dumps 2>/dev/null)
dumps_list="${dumps_list:-Verzeichnis /opt/moodle-docker/dumps wurde nicht gefunden}"

dumps_box=$(gum style --border rounded --padding "1 3" --width $WIDTH <<< \
"$(gum style --bold <<< "Moodle-Sicherungen:")"$'\n'"$dumps_list")

output=$(printf "%s\n\n%s\n\n%s\n\n%s" "$title_box" "$compose_status_box" "$docker_box" "$dumps_box")
gum style --border rounded --padding "1 2" --width $((WIDTH + 6)) <<< "$output"

choice=$(gum choose --header "Was moechtest du tun?" \
  "[1] Moodle starten" \
  "[2] Moodle stoppen" \
  "[4] Backup erstellen" \
  "[5] Backup wiederherstellen" \
  "[3] Beenden")

case "$choice" in
  "[1] Moodle starten")
    if gum confirm "Logs anzeigen?"; then
      cd "$INSTALL_DIR" && docker compose up && docker compose logs -f
    else
      cd "$INSTALL_DIR" && docker compose up -d
    fi
    ;;
  "[2] Moodle stoppen")
    (cd "$INSTALL_DIR" && docker compose down)
    ;;
  "[4] Backup erstellen")
    sudo "$INSTALL_DIR/tools/moodle-backup/moodle-backup.sh"
    ;;
  "[5] Backup wiederherstellen")
    sudo "$INSTALL_DIR/tools/moodle-backup/moodle-restore.sh"
    ;;
  "[3] Beenden")
    echo "Auf Wiedersehen!"
    ;;
esac
