#!/usr/bin/env bash
# ===========================================================================
# run_tests.sh — Tests automatiques pour le Puzzle de Bix
#
# Usage :
#   bash run_tests.sh              # compile + tous les tests
#   bash run_tests.sh --no-compile # tests seulement (binaire deja present)
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

# Nombre max d'etats errones affiches par test (evite les murs de texte)
MAX_STATES_SHOWN=3

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
# cmd_direction : traduit une lettre de commande en mot lisible
# ---------------------------------------------------------------------------
cmd_direction() {
    case "$1" in
        e) echo "nord ↑" ;;
        d) echo "sud ↓"  ;;
        s) echo "ouest ←";;
        f) echo "est →"  ;;
        r) echo "reset"  ;;
        x) echo "abandon";;
        *) echo "?"      ;;
    esac
}

# ---------------------------------------------------------------------------
# cmd_timeline : affiche la sequence de commandes avec surlignage
#
# Args: all_cmds  active_idx
#
#   active_idx = -1  → etat initial (avant toute commande)
#   active_idx >= 0  → index 0-base de la commande qui a produit cet etat
#
# Affichage :  e d s ❮f❯ e d x
#              passees en DIM, active en BOLD+RED entre crochets, futures normales
# ---------------------------------------------------------------------------
cmd_timeline() {
    local all_cmds="$1"
    local active_idx="$2"
    local len="${#all_cmds}"

    printf "  ${CYAN}Commandes :${RESET} "

    if [ "$active_idx" -lt 0 ]; then
        # Etat initial : pas encore de commande
        printf "${BOLD}[INIT]${RESET}"
    else
        printf "${DIM}[INIT]${RESET}"
    fi

    for (( i=0; i<len; i++ )); do
        local ch="${all_cmds:$i:1}"
        if [ "$i" -lt "$active_idx" ]; then
            # Commande deja jouee
            printf " ${DIM}%s${RESET}" "$ch"
        elif [ "$i" -eq "$active_idx" ]; then
            # Commande active (celle qui a produit l'etat errone)
            printf " ${BOLD}${RED}❮%s❯${RESET}" "$ch"
        else
            # Commande future
            printf " %s" "$ch"
        fi
    done
    printf "\n"

    # Ligne de detail pour la commande active
    if [ "$active_idx" -ge 0 ] && [ "$active_idx" -lt "$len" ]; then
        local ch="${all_cmds:$active_idx:1}"
        printf "  ${CYAN}→ Cmd #%d : ${BOLD}'%s'${RESET}${CYAN} = %s${RESET}\n" \
            "$(( active_idx + 1 ))" "$ch" "$(cmd_direction "$ch")"
    fi
}

# ---------------------------------------------------------------------------
# block_lines : extrait les lignes [start, end] d'un fichier
#               retourne les lignes separees par \n, ou "" si hors-limites
# ---------------------------------------------------------------------------
block_lines() {
    local file="$1"
    local start="$2"
    local end="$3"
    awk "NR>=$start && NR<=$end" "$file"
}

# ---------------------------------------------------------------------------
# _state_header_dim : en-tete discret pour un etat de contexte (correct)
# Args: state_idx  all_cmds
# ---------------------------------------------------------------------------
_state_header_dim() {
    local s="$1"
    local all_cmds="$2"
    local cmd_idx=$(( s - 1 ))

    if [ "$s" -eq 0 ]; then
        printf "  ${DIM}┄ Etat initial${RESET}\n"
    else
        local ch="${all_cmds:$cmd_idx:1}"
        printf "  ${DIM}┄ Etat #%d — '%s' → %s${RESET}\n" \
            "$s" "$ch" "$(cmd_direction "$ch")"
    fi
}

# ---------------------------------------------------------------------------
# _show_ctx_state : affiche un etat CORRECT en mode contexte (grise, compact)
# Args: s  exp_f  map_height  all_cmds
# ---------------------------------------------------------------------------
_show_ctx_state() {
    local s="$1"
    local exp_f="$2"
    local map_height="$3"
    local all_cmds="$4"
    local col=42

    local ls=$(( s * map_height + 1 ))
    local le=$(( ls + map_height - 1 ))
    local block
    block=$(block_lines "$exp_f" "$ls" "$le")

    _state_header_dim "$s" "$all_cmds"

    for (( row=1; row<=map_height; row++ )); do
        local ln=$(( ls + row - 1 ))
        local line
        line=$(printf '%s' "$block" | sed -n "${row}p")
        printf "  ${DIM}%4d  %s${RESET}\n" "$ln" "$line"
    done
    echo -e "  ${DIM}     ✓ OK${RESET}"
}

# ---------------------------------------------------------------------------
# _show_fail_state : affiche un etat ERRONE avec diff cote-a-cote et timeline
# Args: s  exp_f  got_f  map_height  all_cmds
# ---------------------------------------------------------------------------
_show_fail_state() {
    local s="$1"
    local exp_f="$2"
    local got_f="$3"
    local map_height="$4"
    local all_cmds="$5"
    local col=42

    local ls=$(( s * map_height + 1 ))
    local le=$(( ls + map_height - 1 ))
    local exp_block got_block
    exp_block=$(block_lines "$exp_f" "$ls" "$le")
    got_block=$(block_lines "$got_f" "$ls" "$le")

    local cmd_idx=$(( s - 1 ))

    # En-tete de l'etat errone
    if [ "$s" -eq 0 ]; then
        echo -e "  ${BOLD}${YELLOW}╾─ Etat initial ← PREMIER ECHEC${RESET}"
    else
        local ch="${all_cmds:$cmd_idx:1}"
        echo -e "  ${BOLD}${YELLOW}╾─ Etat #${s} — commande '${ch}' → $(cmd_direction "$ch")  ← ECHEC${RESET}"
        [ -n "$all_cmds" ] && cmd_timeline "$all_cmds" "$cmd_idx"
    fi

    # Tableau cote-a-cote
    printf "\n  ${BOLD}%4s  ${GREEN}%-*s${RESET}  ${BOLD}${RED}%-*s${RESET}\n" \
        "LN" "$col" "ATTENDU ✓" "$col" "OBTENU ✗"
    printf "  %s\n" "$(printf '─%.0s' $(seq 1 $((col * 2 + 10))))"

    for (( row=1; row<=map_height; row++ )); do
        local ln=$(( ls + row - 1 ))
        local exp_line got_line
        exp_line=$(printf '%s' "$exp_block" | sed -n "${row}p")
        got_line=$(printf '%s' "$got_block" | sed -n "${row}p")

        if [ "$exp_line" = "$got_line" ]; then
            printf "  ${DIM}%4d  %-*s  %-*s${RESET}\n" \
                "$ln" "$col" "$exp_line" "$col" "$got_line"
        else
            printf "  %4d  ${GREEN}%-*s${RESET}  ${RED}%-*s${RESET}\n" \
                "$ln" "$col" "$exp_line" "$col" "$got_line"
        fi
    done

    # Bloc trop court ou trop long
    local exp_cnt got_cnt
    exp_cnt=$(printf '%s\n' "$exp_block" | wc -l)
    got_cnt=$(printf '%s\n' "$got_block" | wc -l)
    if   [ "$got_cnt" -lt "$exp_cnt" ]; then
        echo -e "  ${RED}  ↳ Seulement $got_cnt ligne(s) affichee(s) sur $exp_cnt attendues${RESET}"
    elif [ "$got_cnt" -gt "$exp_cnt" ]; then
        echo -e "  ${RED}  ↳ $got_cnt lignes affichees, $exp_cnt attendues${RESET}"
    fi
}

# ---------------------------------------------------------------------------
# pretty_diff : affiche les etats errones avec 2 etats de contexte avant
#
# Pour chaque etat errone, on affiche :
#   - les 2 etats corrects qui precedent (grise, compact) si disponibles
#   - l'etat errone en pleine couleur avec diff et timeline
#
# Args: exp_f  got_f  map_height  all_cmds  input_file
# ---------------------------------------------------------------------------
pretty_diff() {
    local exp_f="$1"
    local got_f="$2"
    local map_height="${3:-7}"
    local all_cmds="${4:-}"
    local input_file="${5:-}"

    local total_exp total_got
    total_exp=$(wc -l < "$exp_f")
    total_got=$(wc -l < "$got_f")

    local n_states_exp=$(( (total_exp + map_height - 1) / map_height ))
    local n_states_got=$(( (total_got + map_height - 1) / map_height ))
    local n_states=$(( n_states_exp > n_states_got ? n_states_exp : n_states_got ))

    local n_fail=0
    local n_shown=0
    local last_ctx_shown=-1   # dernier index d'etat de contexte deja affiche

    for (( s=0; s<n_states; s++ )); do
        local ls=$(( s * map_height + 1 ))
        local le=$(( ls + map_height - 1 ))

        local exp_block got_block
        exp_block=$(block_lines "$exp_f" "$ls" "$le")
        got_block=$(block_lines "$got_f" "$ls" "$le")

        [ "$exp_block" = "$got_block" ] && continue

        n_fail=$(( n_fail + 1 ))
        [ $n_shown -ge $MAX_STATES_SHOWN ] && continue
        n_shown=$(( n_shown + 1 ))

        echo ""

        # ── Contexte : les 2 etats corrects qui precedent ───────────────────
        # On cherche les indices s-2 et s-1 (dans l'ordre), en sautant ceux
        # deja affiches comme contexte d'un echec precedent.
        local ctx_start=$(( s - 2 ))
        [ $ctx_start -lt 0 ] && ctx_start=0

        local first_ctx=1   # booleen : premier bloc de contexte de ce groupe ?
        for (( c=ctx_start; c<s; c++ )); do
            [ $c -le $last_ctx_shown ] && continue

            # Separateur visuel uniquement avant le premier bloc de contexte
            # du groupe (pas entre deux blocs de contexte consecutifs)
            if [ $first_ctx -eq 1 ] && [ $last_ctx_shown -ge 0 ]; then
                echo -e "  ${DIM}  ···${RESET}"
            fi
            first_ctx=0

            _show_ctx_state "$c" "$exp_f" "$map_height" "$all_cmds"
            last_ctx_shown=$c
        done

        # ── Etat errone ─────────────────────────────────────────────────────
        _show_fail_state "$s" "$exp_f" "$got_f" "$map_height" "$all_cmds"
        last_ctx_shown=$s
    done

    # ── Message si des echecs ont ete tronques ──────────────────────────────
    if [ $n_fail -gt $MAX_STATES_SHOWN ]; then
        local hidden=$(( n_fail - MAX_STATES_SHOWN ))
        echo -e "\n  ${DIM}··· et $hidden autre(s) etat(s) incorrect(s) non affiches ···${RESET}"
    fi

    # ── Resume chiffre ──────────────────────────────────────────────────────
    echo ""
    echo -e "  ${BOLD}Resume :${RESET}"
    printf "  ${DIM}%-30s %d lignes (%d etats)${RESET}\n" \
        "Attendu :"  "$total_exp" "$n_states_exp"
    printf "  ${DIM}%-30s %d lignes (%d etats)${RESET}\n" \
        "Obtenu :"   "$total_got" "$n_states_got"
    if [ $n_fail -gt 0 ]; then
        printf "  ${RED}%-30s %d / %d${RESET}\n" \
            "Etats incorrects :" "$n_fail" "$n_states"
    fi
    echo ""
}

# ---------------------------------------------------------------------------
# show_sanitizer
# ---------------------------------------------------------------------------
show_sanitizer() {
    local san_file="$1"
    echo -e "  ${BOLD}${RED}SANITIZER — erreur memoire ou comportement indefini detecte :${RESET}"

    grep -E "(ERROR:|WRITE|READ|#[0-9].*puzzle\.c|SUMMARY)" "$san_file" \
    | head -15 \
    | while IFS= read -r line; do
        local ln_num
        ln_num=$(echo "$line" | grep -oP 'puzzle\.c:\K[0-9]+' || true)
        if   [[ "$line" == SUMMARY* ]]; then
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

    # Hauteur de la map (2eme champ de la 1ere ligne du fichier carte)
    local map_height
    map_height=$(head -1 "$map" | awk '{print $2}')

    # Toutes les commandes a plat (concatenation des lignes sans \n)
    local all_cmds
    all_cmds=$(tr -d '\n' < "$input")

    # En-tete du test avec recap de la sequence de commandes
    echo -e "\n${BOLD}┌─ TEST : ${CYAN}${name}${RESET}${BOLD} ── carte : ${map}  (${map_height} lignes/etat)${RESET}"
    echo -e "${BOLD}│  Sequence :${RESET} ${all_cmds}  ${DIM}(${#all_cmds} commande(s))${RESET}"

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

        pretty_diff "$exp_f" "$actual_f" "$map_height" "$all_cmds" "$input"

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