#!/usr/bin/env bash
# ===========================================================================
# run_tests.sh — Tests automatiques pour le Puzzle de Bix
#
# Usage :
#   bash run_tests.sh              # compile + tous les tests
#   bash run_tests.sh --no-compile # tests seulement (binaire deja present)
#
# Dossier des cartes : detecte automatiquement.
#   Priorite : examples/  >  maps/  (cree maps/ si aucun n'existe)
# ===========================================================================

set -euo pipefail

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

PASS=0
FAIL=0
ERRORS=()

# ---------------------------------------------------------------------------
# Detection automatique du dossier des cartes
# ---------------------------------------------------------------------------
if   [ -d "examples" ]; then
    MAPS_DIR="examples"
elif [ -d "maps" ]; then
    MAPS_DIR="maps"
else
    echo -e "${YELLOW}Aucun dossier 'examples/' ni 'maps/' trouve — creation de 'maps/'.${RESET}"
    mkdir -p maps
    MAPS_DIR="maps"
fi
echo -e "Cartes dans : ${BOLD}${MAPS_DIR}/${RESET}"

# ---------------------------------------------------------------------------
# compile : compile puzzle.c avec warnings + sanitizers
# ---------------------------------------------------------------------------
compile() {
    echo -e "${BOLD}=== Compilation ===${RESET}"
    # -Wall -Wextra    : tous les warnings utiles
    # -Werror          : un warning = une erreur (code propre obligatoire)
    # -fsanitize=...   : detecte les undefined behaviour et les fuites memoire
    # -g               : infos de debug dans les messages sanitizer
    if gcc -Wall -Wextra -Werror \
           -fsanitize=address,undefined \
           -g \
           -o puzzle puzzle.c; then
        echo -e "${GREEN}OK Compilation OK${RESET}\n"
    else
        echo -e "${RED}ECHEC Compilation ECHOUEE — corrige les erreurs ci-dessus.${RESET}"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# normalize : filtre stdin pour ne garder que les lignes de carte
#
# Le programme peut afficher des codes ANSI (couleurs, clear-screen),
# un titre decoratif et des lignes vides entre les etats.
# On supprime tout ca afin de comparer uniquement le contenu de la carte.
# Les lignes composees uniquement d'espaces (vraies lignes de la carte)
# sont intentionnellement conservees ; seules les lignes vides absolues
# (longueur 0) sont retirees.
# ---------------------------------------------------------------------------
normalize() {
    sed \
        -e 's/\x1B\[[0-9;]*[A-Za-z]//g' \
        -e 's/\x1B[HF]//g' \
    | grep -v '^$' \
    | grep -v '^=== .*===$'
}

# ---------------------------------------------------------------------------
# run_test <nom> <carte> <input> <expected>
# ---------------------------------------------------------------------------
run_test() {
    local name="$1"
    local map="$2"
    local input="$3"
    local expected="$4"
    local diff_file="/tmp/bix_diff_${name}.txt"
    local san_file="/tmp/bix_sanitizer_${name}.txt"

    printf "  %-30s" "$name"

    # Executer avec un timeout de 10 s pour eviter les boucles infinies
    local actual
    actual=$(timeout 10 ./puzzle "$map" < "$input" 2>"$san_file" | normalize) || true

    local expected_clean
    expected_clean=$(normalize < "$expected")

    if diff \
        <(echo "$actual") \
        <(echo "$expected_clean") > "$diff_file" 2>&1; then
        echo -e "${GREEN}PASS${RESET}"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}FAIL${RESET}"
        FAIL=$((FAIL + 1))
        ERRORS+=("$name")

        echo -e "${YELLOW}    --- attendu (+)  vs  obtenu (-)  [max 60 lignes] ---${RESET}"
        head -60 "$diff_file" | sed 's/^/    /'

        # Signaler les erreurs AddressSanitizer / UBSan s'il y en a
        if [ -s "$san_file" ]; then
            echo -e "${RED}    [SANITIZER] Erreurs d'execution detectees :${RESET}"
            head -20 "$san_file" | sed 's/^/    /'
        fi
    fi
}

# ---------------------------------------------------------------------------
# summary : affiche le bilan et retourne un code d'erreur si necessaire
# ---------------------------------------------------------------------------
summary() {
    local total=$((PASS + FAIL))
    echo ""
    echo -e "${BOLD}=== Resultats : $PASS / $total tests reussis ===${RESET}"

    if [ $FAIL -gt 0 ]; then
        echo -e "${RED}Tests ecoues :${RESET}"
        for e in "${ERRORS[@]}"; do
            echo -e "  ${RED}x $e${RESET}  — diff complet dans /tmp/bix_diff_${e}.txt"
        done
        echo ""
        exit 1
    else
        echo -e "${GREEN}Tous les tests passent. Bien joue !${RESET}"
    fi
}

# ---------------------------------------------------------------------------
# Point d'entree
# ---------------------------------------------------------------------------

if [[ "${1:-}" != "--no-compile" ]]; then
    compile
fi

echo -e "${BOLD}=== Tests ===${RESET}"

run_test "incomplete-map"  "${MAPS_DIR}/incomplete-map.txt"  "tests/incomplete-map/input.txt"  "tests/incomplete-map/expected.txt"
run_test "level1"          "${MAPS_DIR}/level1.txt"          "tests/level1/input.txt"          "tests/level1/expected.txt"
run_test "level2"          "${MAPS_DIR}/level2.txt"          "tests/level2/input.txt"          "tests/level2/expected.txt"

summary
