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

# ---------------------------------------------------------------------------
# Couleurs
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

PASS=0
FAIL=0
ERRORS=()

# ---------------------------------------------------------------------------
# Detection automatique du dossier des cartes
# ---------------------------------------------------------------------------
if   [ -d "examples" ]; then MAPS_DIR="examples"
elif [ -d "maps"     ]; then MAPS_DIR="maps"
else
    echo -e "${YELLOW}Aucun dossier 'examples/' ni 'maps/' trouve — creation de 'maps/'.${RESET}"
    mkdir -p maps
    MAPS_DIR="maps"
fi

# ---------------------------------------------------------------------------
# compile
# ---------------------------------------------------------------------------
compile() {
    echo -e "\n${BOLD}╔══════════════════════════════════╗"
    echo -e "║         COMPILATION              ║"
    echo -e "╚══════════════════════════════════╝${RESET}"

    local compiler_output
    if compiler_output=$(gcc -Wall -Wextra -Werror \
                             -fsanitize=address,undefined \
                             -g -o puzzle puzzle.c 2>&1); then
        echo -e "${GREEN}  OK — aucun warning, aucune erreur${RESET}\n"
    else
        echo -e "${RED}  ECHEC — le programme ne compile pas !\n${RESET}"
        echo -e "${BOLD}Erreurs :${RESET}"
        while IFS= read -r line; do
            if   [[ "$line" == *"error:"*   ]]; then echo -e "  ${RED}ERR  ${RESET}$line"
            elif [[ "$line" == *"warning:"* ]]; then echo -e "  ${YELLOW}WARN ${RESET}$line"
            elif [[ "$line" == *"note:"*    ]]; then echo -e "  ${DIM}NOTE ${RESET}$line"
            else                                     echo -e "       $line"
            fi
        done <<< "$compiler_output"
        echo ""
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# normalize : supprime ANSI, lignes vides absolues, titres decoratifs
# ---------------------------------------------------------------------------
normalize() {
    sed \
        -e 's/\x1B\[[0-9;]*[A-Za-z]//g' \
        -e 's/\x1B[HF]//g' \
    | grep -v '^$' \
    | grep -v '^=== .*===$'
}

# ---------------------------------------------------------------------------
# pretty_diff : affiche un diff cote-a-cote colore avec numeros de ligne
# Arguments : fichier_attendu  fichier_obtenu
# ---------------------------------------------------------------------------
pretty_diff() {
    local exp_f="$1"
    local got_f="$2"
    local col=40

    local total_exp total_got n_missing n_extra
    total_exp=$(wc -l < "$exp_f")
    total_got=$(wc -l < "$got_f")
    n_missing=$(diff "$got_f" "$exp_f" | grep -c '^>' || true)
    n_extra=$(  diff "$got_f" "$exp_f" | grep -c '^<' || true)

    # En-tete
    printf "\n  ${BOLD}%-4s  %-*s  %-*s${RESET}\n" \
        "LN" $col "ATTENDU (correct)" $col "OBTENU (ton programme)"
    printf "  %s\n" "$(printf '─%.0s' $(seq 1 $((col * 2 + 8))))"

    # Diff cote-a-cote, on recolore selon le marqueur central
    diff -y --width=$(( col * 2 + 6 )) --expand-tabs \
        "$exp_f" "$got_f" \
    | head -80 \
    | nl -ba -nrz -w3 \
    | while IFS= read -r line; do
        local ln="${line:0:3}"
        local body="${line:4}"
        if   [[ "$body" == *$'\t<'* ]]; then
            printf "  ${DIM}%s${RESET}  ${GREEN}%s${RESET}\n" "$ln" "$body"
        elif [[ "$body" == *$'\t>'* ]]; then
            printf "  ${DIM}%s${RESET}  ${RED}%s${RESET}\n"   "$ln" "$body"
        elif [[ "$body" == *$'\t|'* ]]; then
            printf "  ${DIM}%s${RESET}  ${YELLOW}%s${RESET}\n" "$ln" "$body"
        else
            printf "  ${DIM}%s  %s${RESET}\n" "$ln" "$body"
        fi
    done

    # Avertissement si tronque
    local total_rows
    total_rows=$(diff -y --width=1 "$exp_f" "$got_f" 2>/dev/null | wc -l || true)
    if [ "$total_rows" -gt 80 ]; then
        echo -e "  ${DIM}... ${total_rows} lignes au total, seules les 80 premieres sont affichees${RESET}"
    fi

    # Resume chiffre
    echo ""
    echo -e "  ${BOLD}Resume :${RESET}"
    printf "  ${DIM}%-25s %s${RESET}\n" "Lignes attendues :"  "$total_exp"
    printf "  ${DIM}%-25s %s${RESET}\n" "Lignes obtenues :"   "$total_got"
    [ "$n_missing" -gt 0 ] && \
        echo -e "  ${GREEN}  Manquantes (vertes) : ${n_missing} — ton programme n'affiche pas ces lignes${RESET}"
    [ "$n_extra" -gt 0 ] && \
        echo -e "  ${RED}  En trop (rouges)    : ${n_extra} — ton programme affiche des lignes de trop${RESET}"
    echo ""
}

# ---------------------------------------------------------------------------
# show_sanitizer : affiche de facon lisible le rapport ASAN/UBSan
# ---------------------------------------------------------------------------
show_sanitizer() {
    local san_file="$1"
    echo -e "  ${BOLD}${RED}SANITIZER — erreur memoire ou comportement indefini detecte :${RESET}"

    grep -E "(ERROR:|WRITE|READ|#[0-9].*puzzle\.c|SUMMARY)" "$san_file" \
    | head -15 \
    | while IFS= read -r line; do
        local ln_num
        ln_num=$(echo "$line" | grep -oP 'puzzle\.c:\K[0-9]+' || true)
        if [[ "$line" == SUMMARY* ]]; then
            echo -e "  ${RED}${BOLD}$line${RESET}"
        elif [[ -n "$ln_num" ]]; then
            echo -e "  ${RED}$line${RESET}  ${YELLOW}<-- puzzle.c ligne $ln_num${RESET}"
        else
            echo -e "  ${DIM}$line${RESET}"
        fi
    done
    echo ""
}

# ---------------------------------------------------------------------------
# run_test <nom> <carte> <input> <expected>
# ---------------------------------------------------------------------------
run_test() {
    local name="$1"
    local map="$2"
    local input="$3"
    local expected="$4"
    local actual_f="/tmp/bix_actual_${name}.txt"
    local exp_f="/tmp/bix_expected_${name}.txt"
    local san_f="/tmp/bix_sanitizer_${name}.txt"

    echo -e "\n${BOLD}┌─ TEST : ${CYAN}${name}${RESET}${BOLD} ── carte : ${map}${RESET}"

    timeout 10 ./puzzle "$map" < "$input" 2>"$san_f" \
        | normalize > "$actual_f" || true
    normalize < "$expected" > "$exp_f"

    if diff -q "$actual_f" "$exp_f" > /dev/null 2>&1; then
        echo -e "${BOLD}└─ ${GREEN}PASS${RESET} — sortie identique a l'attendu"
        PASS=$((PASS + 1))
    else
        echo -e "${BOLD}└─ ${RED}FAIL${RESET}"
        FAIL=$((FAIL + 1))
        ERRORS+=("$name")

        pretty_diff "$exp_f" "$actual_f"

        [ -s "$san_f" ] && show_sanitizer "$san_f"
    fi
}

# ---------------------------------------------------------------------------
# summary
# ---------------------------------------------------------------------------
summary() {
    local total=$((PASS + FAIL))
    echo -e "\n${BOLD}╔══════════════════════════════════╗"
    echo -e "║           RESULTATS              ║"
    echo -e "╚══════════════════════════════════╝${RESET}\n"

    if [ $FAIL -gt 0 ]; then
        for e in "${ERRORS[@]}"; do echo -e "  ${RED}FAIL  $e${RESET}"; done
        echo ""
        echo -e "  ${RED}${BOLD}$PASS / $total — des bugs a corriger !${RESET}\n"
        exit 1
    else
        echo -e "  ${GREEN}${BOLD}$PASS / $total — tout est bon, bien joue !${RESET}\n"
    fi
}

# ---------------------------------------------------------------------------
# Point d'entree
# ---------------------------------------------------------------------------
echo -e "${BOLD}${CYAN}"
echo " ██████╗ ██╗██╗  ██╗"
echo " ██╔══██╗██║╚██╗██╔╝"
echo " ██████╔╝██║ ╚███╔╝ "
echo " ██╔══██╗██║ ██╔██╗ "
echo " ██████╔╝██║██╔╝ ██╗"
echo -e " ╚═════╝ ╚═╝╚═╝  ╚═╝  Tests automatiques${RESET}"
echo -e " ${DIM}Maps dans : ${MAPS_DIR}/${RESET}"

if [[ "${1:-}" != "--no-compile" ]]; then
    compile
fi

echo -e "${BOLD}╔══════════════════════════════════╗"
echo -e "║            TESTS                 ║"
echo -e "╚══════════════════════════════════╝${RESET}"

run_test "incomplete-map"  "${MAPS_DIR}/incomplete-map.txt"  "tests/incomplete-map/input.txt"  "tests/incomplete-map/expected.txt"
run_test "level1"          "${MAPS_DIR}/level1.txt"          "tests/level1/input.txt"          "tests/level1/expected.txt"
run_test "level2"          "${MAPS_DIR}/level2.txt"          "tests/level2/input.txt"          "tests/level2/expected.txt"

summary