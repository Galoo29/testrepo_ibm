#!/usr/bin/env bash

# Usage : ./liste_contenu.sh chemin/vers/dossier

DIR="${1:-.}"   # si aucun argument : dossier courant

# On se place dans le dossier cible
cd "$DIR" || { echo "Dossier introuvable : $DIR" >&2; exit 1; }

# Liste récursive fichiers + dossiers, un élément par ligne, chemin relatif
find . -type f -print | sed 's|^\./||'