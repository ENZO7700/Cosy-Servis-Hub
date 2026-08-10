#!/bin/bash

# =============================================================================
# SECURITY PREFLIGHT CHECK SCRIPT
# Centralny Dashboard - Security Validation Before Commit
# =============================================================================
# Autor: Security Team
# Verzia: 1.0.0
# Datum: 2026-07-20
# Popis: Skontroluje, ci nie su v git indexe citlive subory
# =============================================================================

set -euo pipefail

# Farby pre vypis
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Citac chyb
ERROR_COUNT=0
WARNING_COUNT=0

# Funkcia pre hlásenie chýb
function error() {
    echo -e "${RED}[ERROR]${NC} $1"
    ERROR_COUNT=$((ERROR_COUNT + 1))
}

# Funkcia pre hlásenie varovani
function warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    WARNING_COUNT=$((WARNING_COUNT + 1))
}

# Funkcia pre hlásenie успеха
function success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

# Funkcia pre hlásenie informácii
function info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# =============================================================================
# HLAVNA KONTROLA
# =============================================================================

echo ""
echo "============================================================================="
echo "  CENTRALNY DASHBOARD - SECURITY PREFLIGHT CHECK"
echo "============================================================================="
echo ""
echo "Spúštam bezpečnostné kontroly..."
echo ""

# =============================================================================
# KONTROLA 1: secrets.json v git indexe
# =============================================================================
echo "--- Kontrola 1: secrets.json ---"
if git ls-files | grep -q "^secrets\.json$"; then
    error "secrets.json je v git indexe! OKAMŽITE odstráňte: git rm --cached secrets.json"
else
    success "secrets.json nie je v git indexe"
fi

# =============================================================================
# KONTROLA 2: .isar súbory v git indexe
# =============================================================================
echo ""
echo "--- Kontrola 2: Isar databázové súbory ---"
ISAR_FILES=$(git ls-files | grep -E '\.(isar|isar\.lock)$' | grep -v "^web/" || true)
if [ -n "$ISAR_FILES" ]; then
    error "Nasledovné Isar súbory sú v git indexe:"
    echo "$ISAR_FILES" | while read -r file; do
        error "  - $file"
    done
    error "Odstráňte ich: git rm --cached $(echo "$ISAR_FILES" | tr '\n' ' ')"
else
    success "Žiadne Isar súbory v git indexe"
fi

# =============================================================================
# KONTROLA 3: .env súbory v git indexe
# =============================================================================
echo ""
echo "--- Kontrola 3: Environment súbory ---"
ENV_FILES=$(git ls-files | grep -E '\.env($|\.)' | grep -v "\.example\|\.template" || true)
if [ -n "$ENV_FILES" ]; then
    error "Nasledovné .env súbory sú v git indexe:"
    echo "$ENV_FILES" | while read -r file; do
        error "  - $file"
    done
    error "Odstráňte ich: git rm --cached $(echo "$ENV_FILES" | tr '\n' ' ')"
else
    success "Žiadne .env súbory v git indexe"
fi

# =============================================================================
# KONTROLA 4: android/local.properties v git indexe
# =============================================================================
echo ""
echo "--- Kontrola 4: Android lokalne súbory ---"
if git ls-files | grep -q "^android/local\.properties$"; then
    error "android/local.properties je v git indexe! Odstráňte: git rm --cached android/local.properties"
else
    success "android/local.properties nie je v git indexe"
fi

# =============================================================================
# KONTROLA 5: supabase/.temp v git indexe
# =============================================================================
echo ""
echo "--- Kontrola 5: Supabase dočasné súbory ---"
SUPABASE_TEMP=$(git ls-files | grep "^supabase/\.temp/" || true)
if [ -n "$SUPABASE_TEMP" ]; then
    error "Nasledovné supabase/.temp súbory sú v git indexe:"
    echo "$SUPABASE_TEMP" | while read -r file; do
        error "  - $file"
    done
    error "Odstráňte ich: git rm --cached $(echo "$SUPABASE_TEMP" | tr '\n' ' ')"
else
    success "Žiadne supabase/.temp súbory v git indexe"
fi

# =============================================================================
# KONTROLA 6: ephemeral adresáre v git indexe
# =============================================================================
echo ""
echo "--- Kontrola 6: Ephemeral adresáre ---"
EPHEMERAL_FILES=$(git ls-files | grep -E "(/|^)ephemeral/" || true)
if [ -n "$EPHEMERAL_FILES" ]; then
    error "Nasledovné ephemeral súbory sú v git indexe:"
    echo "$EPHEMERAL_FILES" | while read -r file; do
        error "  - $file"
    done
    error "Odstráňte ich: git rm --cached $(echo "$EPHEMERAL_FILES" | tr '\n' ' ')"
else
    success "Žiadne ephemeral súbory v git indexe"
fi

# =============================================================================
# KONTROLA 7: Hardcoded API kľúče v Dart súboroch
# =============================================================================
echo ""
echo "--- Kontrola 7: Hardcoded API kľúče v kóde ---"

# Kontrola Supabase URL
SUPABASE_URL_PATTERN="https://[a-zA-Z0-9-]+\.supabase\.co"
SUPABASE_URL_MATCHES=$(git ls-files | xargs grep -l "$SUPABASE_URL_PATTERN" 2>/dev/null | grep "\.dart$" || true)

if [ -n "$SUPABASE_URL_MATCHES" ]; then
    warning "Nasledovné Dart súbory obsahujú Supabase URL (možno hardcoded):"
    echo "$SUPABASE_URL_MATCHES" | while read -r file; do
        warning "  - $file"
    done
    warning "Overte, či sú použité environment variables (String.fromEnvironment)"
else
    success "Žiadne hardcoded Supabase URL v Dart súboroch"
fi

# Kontrola Supabase kľúčov
SUPABASE_KEY_PATTERN="sb_publishable_[a-zA-Z0-9_\-]+"
SUPABASE_KEY_MATCHES=$(git ls-files | xargs grep -l "$SUPABASE_KEY_PATTERN" 2>/dev/null | grep "\.dart$" || true)

if [ -n "$SUPABASE_KEY_MATCHES" ]; then
    error "Nasledovné Dart súbory obsahujú Supabase publishable key (HARDCODED!):"
    echo "$SUPABASE_KEY_MATCHES" | while read -r file; do
        error "  - $file"
    done
    error "Použite String.fromEnvironment('SUPABASE_KEY') namiesto hardcoded kľúča!"
else
    success "Žiadne hardcoded Supabase kľúče v Dart súboroch"
fi

# Kontrola Firebase API key
FIREBASE_KEY_PATTERN="AIza[0-9A-Za-z\-_]+"
FIREBASE_KEY_MATCHES=$(git ls-files | xargs grep -l "$FIREBASE_KEY_PATTERN" 2>/dev/null | grep "\.dart$" || true)

if [ -n "$FIREBASE_KEY_MATCHES" ]; then
    error "Nasledovné Dart súbory obsahujú Firebase API key (HARDCODED!):"
    echo "$FIREBASE_KEY_MATCHES" | while read -r file; do
        error "  - $file"
    done
    error "Použite String.fromEnvironment('FIREBASE_API_KEY') namiesto hardcoded kľúča!"
else
    success "Žiadne hardcoded Firebase API keys v Dart súboroch"
fi

# =============================================================================
# KONTROLA 8: Service role key v súboroch
# =============================================================================
echo ""
echo "--- Kontrola 8: Service role key ---"

SERVICE_KEY_PATTERN="eyJ[0-9a-zA-Z\-_]+\.eyJ[0-9a-zA-Z\-_]*"
SERVICE_KEY_MATCHES=$(git ls-files | xargs grep -l "$SERVICE_KEY_PATTERN" 2>/dev/null || true)

if [ -n "$SERVICE_KEY_MATCHES" ]; then
    error "NAJDENÝ SERVICE ROLE KEY v nasledujúcich súboroch:"
    echo "$SERVICE_KEY_MATCHES" | while read -r file; do
        error "  - $file"
    done
    error "Service role key JE TAJNÝ! OKAMŽITE odstráňte a rotujte!"
else
    success "Žiadne service role keys v súboroch"
fi

# =============================================================================
# KONTROLA 9: Build artifacty v git indexe
# =============================================================================
echo ""
echo "--- Kontrola 9: Build artifacty ---"
BUILD_FILES=$(git ls-files | grep -E "(/|^)build/|(/|^)\.dart_tool/|(/|^)\.pub-cache/" || true)

if [ -n "$BUILD_FILES" ]; then
    warning "Nasledovné build súbory sú v git indexe:"
    echo "$BUILD_FILES" | head -10 | while read -r file; do
        warning "  - $file"
    done
    warning "Zvážte odstránenie: git rm --cached $(echo "$BUILD_FILES" | tr '\n' ' ')"
else
    success "Žiadne build artifacty v git indexe"
fi

# =============================================================================
# KONTROLA 10: .flutter-plugins-dependencies v git indexe
# =============================================================================
echo ""
echo "--- Kontrola 10: Flutter plugin dependencies ---"
if git ls-files | grep -q "^\.flutter-plugins-dependencies$"; then
    warning "\.flutter-plugins-dependencies je v git indexe"
    warning "Toto nie je kritické, ale odporúča sa ignorovať"
else
    success "\.flutter-plugins-dependencies nie je v git indexe"
fi

# =============================================================================
# SÚHRN / SUMMARY
# =============================================================================

echo ""
echo "============================================================================="
echo "  SÚHRN / SUMMARY"
echo "============================================================================="
echo ""
echo "Chyby:   ${RED}${ERROR_COUNT}${NC}"
echo "Varovania: ${YELLOW}${WARNING_COUNT}${NC}"
echo ""

if [ $ERROR_COUNT -gt 0 ]; then
    echo -e "${RED}❌ PREFLIGHT CHECK ZLYHAL!${NC}"
    echo ""
    echo "Opravte všetky chyby pred commitom!"
    echo ""
    echo "Ak ste nahodou commitnuli citlivé dáta:"
    echo "  1. Odstráňte ich z git: git rm --cached <súbor>"
    echo "  2. Vytvorte nový commit"
    echo "  3. OKAMŽITE rotujte všetky kľúče!"
    echo ""
    exit 1
elif [ $WARNING_COUNT -gt 0 ]; then
    echo -e "${YELLOW}⚠️  PREFLIGHT CHECK S VAROVANIAMI${NC}"
    echo ""
    echo "Overte varovania a opravte ich, ak je to potrebné."
    echo ""
    exit 0
else
    echo -e "${GREEN}✅ PREFLIGHT CHECK PREŠIEL!${NC}"
    echo ""
    echo "Všetky bezpečnostné kontroly prešli úspešne."
    echo "Môžete bezpečne vykonať commit."
    echo ""
    exit 0
fi
