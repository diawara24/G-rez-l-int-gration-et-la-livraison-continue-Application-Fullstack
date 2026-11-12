#!/usr/bin/env bash

# Ne pas arrêter le script à la première erreur :
# toutes les applications doivent pouvoir exécuter leurs tests.
set -uo pipefail

# Racine du dépôt Git
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Dossier centralisé des rapports JUnit
REPORT_DIR="$ROOT_DIR/test-results/junit"

FAILED=0
FOUND=0

# Préparer un dossier propre pour les nouveaux rapports
rm -rf "$REPORT_DIR"
mkdir -p "$REPORT_DIR"

# Remplacer les caractères spéciaux pour les noms de fichiers
safe_name() {
    printf '%s' "$1" | tr ' /' '__' | tr -cd '[:alnum:]_.-'
}

# Exécuter une commande de test et mémoriser son résultat
run_test() {
    local name="$1"
    local dir="$2"
    shift 2

    echo
    echo "==> Tests $name"

    if (cd "$dir" && "$@"); then
        echo "OK : $name"
    else
        echo "ÉCHEC : $name"
        FAILED=1
    fi
}

# ==================================================
# 1. FRONTEND ANGULAR
# ==================================================

while IFS= read -r -d '' package_file; do
    dir="$(dirname "$package_file")"

    # Vérifier la présence d'un script npm test
    if node -e '
        const p = require(process.argv[1]);
        process.exit(p.scripts?.test ? 0 : 1);
    ' "$package_file"; then
        FOUND=1

        project="$(safe_name "$(basename "$dir")")"
        report="$dir/reports/junit.xml"

        mkdir -p "$dir/reports"
        rm -f "$report"

        # Le reporter JUnit et son chemin sont configurés dans karma.conf.js.
        run_test "Angular - $project" "$dir" npm test

        # Centraliser le rapport généré par Karma
        if [[ -f "$report" ]]; then
            cp "$report" "$REPORT_DIR/angular-$project.xml"
        else
            echo "ERREUR : rapport JUnit Angular introuvable : $report"
            FAILED=1
        fi
    fi
done < <(find "$ROOT_DIR" \
    -path '*/node_modules' -prune -o \
    -path '*/.git' -prune -o \
    -path '*/reports' -prune -o \
    -name package.json -print0)

# ==================================================
# 2. BACKEND SPRING BOOT / GRADLE
# ==================================================

while IFS= read -r -d '' build_file; do
    dir="$(dirname "$build_file")"

    FOUND=1
    project="$(safe_name "$(basename "$dir")")"

    # Utiliser le Wrapper Gradle en priorité
    if [[ -f "$dir/gradlew" ]]; then
        run_test "Spring Boot / Gradle - $project" "$dir" \
            bash ./gradlew test --no-daemon --continue

    # Sinon, utiliser Gradle installé sur la machine
    elif command -v gradle >/dev/null 2>&1; then
        run_test "Spring Boot / Gradle - $project" "$dir" \
            gradle test --no-daemon --continue

    else
        echo "ERREUR : Gradle indisponible dans $dir"
        FAILED=1
    fi

    # Récupérer les rapports JUnit générés par Gradle
    while IFS= read -r -d '' xml_file; do
        relative="${xml_file#"$dir"/}"
        filename="$(safe_name "$relative")"

        cp "$xml_file" "$REPORT_DIR/gradle-$project-$filename"
    done < <(find "$dir" \
        -path '*/build/test-results/test/*.xml' \
        -type f -print0)
done < <(find "$ROOT_DIR" \
    -path '*/.git' -prune -o \
    -path '*/node_modules' -prune -o \
    -path '*/build' -prune -o \
    -path '*/.gradle' -prune -o \
    \( -name build.gradle -o -name build.gradle.kts \) -print0)

# ==================================================
# 3. BILAN FINAL
# ==================================================

echo
echo "========================================"
echo "             BILAN DES TESTS"
echo "========================================"

if [[ "$FOUND" -eq 0 ]]; then
    echo "Aucun projet détecté."
    exit 2
fi

if [[ "$FAILED" -ne 0 ]]; then
    echo "Au moins une suite de tests a échoué."
    echo "Rapports disponibles dans : $REPORT_DIR"
    exit 1
fi

echo "Toutes les suites de tests ont réussi."
echo "Rapports JUnit : $REPORT_DIR"