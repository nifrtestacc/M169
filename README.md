<div align="left">
  <img src="https://github.com/JoSi-git/m169/blob/main/img/titele.png" />
</div>

[![](https://img.shields.io/badge/Luca_Vatrella-FF7F50?style=for-the-badge)](https://github.com/luccaa79)
[![](https://img.shields.io/badge/Kubilay_Yildiz-00FA9A?style=for-the-badge)](https://github.com/K-Y-77)
[![](https://img.shields.io/badge/Nico_Frei-4682B4?style=for-the-badge)](https://github.com/nifrtestacc)
[![](https://img.shields.io/badge/Jon_Gisler-E67E22?style=for-the-badge)](https://github.com/jonigebony)
[![](https://img.shields.io/badge/Lizenz-DAA520?style=for-the-badge)](https://github.com/luccaa79/m169/blob/main/LICENSE)


## 🔍 1 Ausgangslage

Eine ältere Moodle-Instanz muss auf die aktuelle Version als Docker-Container migriert werden, inklusive aller Daten. Dies erfolgt im Rahmen des Modulprojekts und wird in mehreren Schritten durchgeführt.

## 📦 2 Installation

### Git installieren

Sicherstellen, dass Git auf dem System installiert ist:

```bash
sudo apt update
sudo apt install git
```

### Git-Repository klonen

Klonen des Repositories:

```bash
git clone https://github.com/luccaa79/m169
cd m169
```

### Skript ausführbar machen (falls nötig)

Falls das Skript nicht ausführbar ist, kann es wie folgt freigegeben werden:

```bash
chmod +x install.sh
```

### Skript ausführen

Anschliessend kann das Installationsskript gestartet werden:

```bash
./install.sh
```
