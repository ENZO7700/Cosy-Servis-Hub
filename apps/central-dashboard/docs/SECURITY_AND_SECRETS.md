# SECURITY AND SECRETS MANAGEMENT

## 🚨 CRITICAL SECURITY NOTICE

> **⚠️ POZOR: Ak ste kedykolvek uploadnuli ZIP obsahujúci `secrets.json`, `default.isar`, alebo `android/local.properties` na verejný server, OKAMŽITE rotujte všetky kľúče!**
> 
> **⚠️ WARNING: If you have ever uploaded a ZIP containing `secrets.json`, `default.isar`, or `android/local.properties` to any public server, IMMEDIATELY rotate all keys!**

---

## 📋 Obsah / Table of Contents

1. [Prehľad / Overview](#1-prehlad--overview)
2. [Citlivé Súbory / Sensitive Files](#2-citlivé-súbory--sensitive-files)
3. [Git Ignore Pravidlá / Git Ignore Rules](#3-git-ignore-pravidlá--git-ignore-rules)
4. [Bežné Bezpečnostné Chyby / Common Security Mistakes](#4-bežné-bezpečnostné-chyby--common-security-mistakes)
5. [Ako Správne Nastaviť Secrets / How to Properly Set Up Secrets](#5-ako-správne-nastaviť-secrets--how-to-properly-set-up-secrets)
6. [Rotácia Kľúčov / Key Rotation](#6-rotácia-kľúčov--key-rotation)
7. [Pre-commit Security Check / Pre-commit Security Check](#7-pre-commit-security-check--pre-commit-security-check)
8. [Nováčikova Checklist / Newcomer Checklist](#8-nováčikova-checklist--newcomer-checklist)

---

## 1. Prehľad / Overview

Tento dokument popisuje bezpečnostné praktiky pre projekt **Centralny Dashboard**. Obsahuje informácie o tom, ako spravovať citlivé dáta, kľúče API, a ako sa vyhnúť bežným chybám.

This document describes security practices for the **Central Dashboard** project. It contains information on how to manage sensitive data, API keys, and how to avoid common mistakes.

### Project Security Status

- **Last Security Audit**: 2026-08-09 (docs refresh; README JWT removed)
- **Security Contact**: security@nexify-studio.tech
- **Incident Response**: V prípade podozrenia na narušenie bezpečnosti, okamžite kontaktujte security tím
- **Aktuálny audit projektu**: [`PROJECT_DIAGNOSTICS.md`](PROJECT_DIAGNOSTICS.md)

> **README / docs:** Nikdy nevkladajte reálne JWT, service role keys ani `secrets.json` obsah do README ani do markdown dokumentácie. Šablóna je len [`secrets.json.example`](../secrets.json.example).

---

## 2. Citlivé Súbory / Sensitive Files

### 🔴 NEVER COMMIT (V NIKDY NECOMMITUJTE)

| Súbor / File | Dôvod / Reason | Riziko / Risk |
|--------------|---------------|--------------|
| `secrets.json` | Obsahuje API kľúče | Útok na API, dátové narušenie |
| `android/local.properties` | Obsahuje SDK cesty | Lokálna konfigurácia zverejnená |
| `*.isar` | Lokálna databáza | Klientské dáta zverejnené |
| `*.isar.lock` | Lock súbor databázy | Konzistencný problém |
| `supabase/.temp/*` | Dočasné metadáta | Pooler URL, linked metadata |
| `service-account*.json` | Service account kľúče | Full admin prístup |
| `*.p12`, `*.pem` | Certifikáty | SSL/TLS narušenie |
| `.env` | Environment variables | Konfigurácia zverejnená |

### 🟡 CAUTION (OPATRNE)

| Súbor / File | Dôvod / Reason | Doporučenie / Recommendation |
|--------------|---------------|-------------------------------|
| `firebase.json` | Firebase konfigurácia | Obsahuje project ID, nie je tajný |
| `supabase/config.toml` | Supabase konfigurácia | Môže odkazovať na secrets |
| `pubspec.yaml` | Flutter dependencies | Verejná konfigurácia |

### ✅ SAFE TO COMMIT (BEZPEČNÉ COMMITNUŤ)

| Súbor / File | Dôvod / Reason |
|--------------|---------------|
| `secrets.json.example` | Prikład pre vývojárov |
| `.gitignore` | Git ignorované súbory |
| `*.dart` | Zdrojový kód (ak neobsahuje hardcoded kľúče) |
| `README.md` | Dokumentácia |
| `docs/` | Dokumentácia |

---

## 3. Git Ignore Pravidlá / Git Ignore Rules

### Hlavný .gitignore

Hlavný `.gitignore` súbor v koreni projektu obsahuje:

```gitignore
# SECRETS AND CREDENTIALS
secrets.json
secrets.*.json
.env
.env.*
!.env.example
!.env.template

# SERVICE ACCOUNTS
service-account*.json
*.p12
*.pem
*.key
!*.example.key

# DATABASE
*.isar
*.isar.lock
*.db
*.sqlite

# FLUTTER
.dart_tool/
.pub-cache/
.pub/
/build/
/coverage/
.flutter-plugins-dependencies
.flutter-plugins

# ANDROID
/android/local.properties
/android/*.keystore

# iOS
**/ios/Flutter/ephemeral/
**/ios/*.mobileprovision

# SUPABASE
supabase/.temp/
supabase/.env
supabase/.env.*
!supabase/.env.example

# PLATFORM SPECIFIC
**/macos/Flutter/ephemeral/
**/linux/flutter/ephemeral/
**/windows/flutter/ephemeral/
```

### Supabase .gitignore

Súbor `supabase/.gitignore` obsahuje:

```gitignore
# Temporary files
.temp/

# Environment
.env
.env.*
!.env.example

# Local config
config.toml.local

# Database dumps
*.sql.dump
*.backup

# Storage
storage/

# Logs
*.log
```

---

## 4. Bežné Bezpečnostné Chyby / Common Security Mistakes

### ❌ Chyba #1: Commitnutie secrets.json

**Problém**: Vývojár commitne `secrets.json` s reálnymi kľúčmi.

**Riešenie**:
```bash
# Ak ste to urobili:
git rm --cached secrets.json
git commit -m "Remove secrets.json from git"
# Potom ROTUJTE VŠETKY KĽÚČE!
```

### ❌ Chyba #2: Hardcoded API Kľúče v Kóde

**Problém**: API kľúče alebo project URL sú priamo v kóde / README:
```dart
// ❌ NESPRÁVNE
const supabaseUrl = 'https://your-project-ref.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'; // reálny JWT
```

**Riešenie** (app používa `VITE_*` názvy — pozri `lib/core/config/config.dart`):
```dart
// ✅ SPRÁVNE
const supabaseUrl = String.fromEnvironment('VITE_SUPABASE_URL');
const supabaseKey = String.fromEnvironment('VITE_SUPABASE_PUBLISHABLE_KEY');
```

### ❌ Chyba #3: Použitie Service Role Key v Klientovi

**Problém**: Service role key je v `secrets.json` alebo kóde.

**Riešenie**:
- Service role key sa Používa IBA na serveri (Edge Functions)
- Klient používaj iba `publishable_key` (anon key)
- RLS (Row Level Security) musia byť správne nastavené

### ❌ Chyba #4: ZIP s Citlivými Súbormi

**Problém**: Vytvorenie ZIPu celého projektu vrátane `secrets.json`, `default.isar`, atď.

**Riešenie**:
```bash
# Vytvorte ZIP iba s potrebnými súbormi
zip -r project.zip \
  lib/ \
  pubspec.yaml \
  README.md \
  .gitignore \
  -x "secrets.json" \
  -x "*.isar" \
  -x "android/local.properties" \
  -x "supabase/.temp/*" \
  -x "build/*" \
  -x ".dart_tool/*"
```

### ❌ Chyba #5: Slabé RLS Pravidlá

**Problém**: `USING (true)` v Supabase RLS.

**Riešenie**:
```sql
-- ❌ NESPRÁVNE
CREATE POLICY "public_access"
ON leads FOR SELECT USING (true);

-- ✅ SPRÁVNE
CREATE POLICY "tenant_access"
ON leads 
FOR SELECT USING (auth.uid() = tenant_id);
```

---

## 5. Ako Správne Nastaviť Secrets / How to Properly Set Up Secrets

### Lokálny Vývoj (Local Development)

1. **Skopírujte example súbor**:
   ```bash
   cp secrets.json.example secrets.json
   ```

2. **Vyplňte skutočné hodnoty** z vašej Supabase a Firebase konfigurácie

3. **Nepoužívajte service role key** - iba publishable key

4. **Pridajte do .gitignore** (už tam je, ale overte):
   ```gitignore
   secrets.json
   ```

### Produkčné Prostredie (Production Environment)

1. **Použite environment variables**:
   ```bash
   # Flutter web build
   flutter build web \
     --dart-define=VITE_SUPABASE_URL=$SUPABASE_URL \
     --dart-define=VITE_SUPABASE_PUBLISHABLE_KEY=$SUPABASE_KEY
   ```

2. **Nastavte v hostingovom prostredí** (Vercel, Netlify, atď.):
   ```
   VITE_SUPABASE_URL=https://your-project.supabase.co
   VITE_SUPABASE_PUBLISHABLE_KEY=your-anon-key
   ```

3. **Overte RLS pravidlá** pred deployom

---

## 6. Rotácia Kľúčov / Key Rotation

### Kedy Rotovať / When to Rotate

| Situácia / Situation | Akcia / Action |
|---------------------|---------------|
| secrets.json bol commitnutý | ROTUJTE VŠETKO |
| secrets.json bol uploadnutý | ROTUJTE VŠETKO |
| Zariadenie bolo ukradnuté | ROTUJTE VŠETKO |
| Vývojár opustil tím | ROTUJTE prístupové kľúče |
| Plánovaná rotácia | ROTUJTE každé 3-6 mesiacov |

### Ako Rotovať / How to Rotate

#### Supabase

1. Prejdite do **Supabase Dashboard > Project Settings > API**
2. Kliknite na "Rotate publishable key"
3. Aktualizujte všetky aplikácie s novým kľúčom
4. Overte, že RLS pravidlá sú správne

#### Firebase

1. Prejdite do **Firebase Console > Project Settings > Web API Key**
2. Kliknite na "Manage API keys"
3. Vygenerujte nový kľúč
4. Aktualizujte aplikácie

#### Service Role Key (IBA SERVER!)

1. V Supabase: **Project Settings > API > Service role key**
2. Kliknite na "Rotate"
3. Aktualizujte VŠETKY Edge Functions
4. **NIKDY** nekomitnite do git!

---

## 7. Pre-commit Security Check / Pre-commit Security Check

Použite skript `tool/security_preflight.sh` pred každým commitom:

```bash
# Spustite pred commitom
./tool/security_preflight.sh

# Ak vráti chybu, NEDELAJTE commit!
```

Skript overuje:
- ✅ Žiadne `secrets.json` v git indexe
- ✅ Žiadne `.isar` súbory v git indexe
- ✅ Žiadne `.env` súbory v git indexe
- ✅ Žiadne `android/local.properties` v git indexe
- ✅ Žiadne `supabase/.temp` súbory v git indexe
- ✅ Žiadne hardcoded API kľúče v Dart súboroch
- ✅ Žiadne service role keys v kóde

---

## 8. Nováčikova Checklist / Newcomer Checklist

### Pred Práciou / Before Working

- [ ] Prečítal som tento dokument (I read this document)
- [ ] Rozumiem rizikám commitnutia secrets (I understand the risks of committing secrets)
- [ ] Mám nainštalovaný `tool/security_preflight.sh` (I have the security script installed)
- [ ] Viem, kde nájdem `secrets.json.example` (I know where to find secrets.json.example)

### Po Práci / After Working

- [ ] Spustil som `git status` a overil som, že nič citlivé nie je v zmene (I ran git status and verified no sensitive files are changed)
- [ ] Spustil som `./tool/security_preflight.sh` (I ran the security check script)
- [ ] Necommitol som žiadne secrets (I didn't commit any secrets)
- [ ] Neuploadol som žiadny ZIP s citlivými dátami (I didn't upload any ZIP with sensitive data)

### V Prípade Počasia / In Case of Emergency

- [ ] Viem, komu hlásiť bezpečnostný incident (I know who to report security incidents to)
- [ ] Viem, ako rotovať kľúče (I know how to rotate keys)
- [ ] Viem, že musím okamžite reagovať (I know I must react immediately)

---

## 📞 Kontakty / Contacts

| Rola / Role | Kontakt / Contact |
|-------------|------------------|
| Security Team | security@nexify-studio.tech |
| Project Lead | erik@nexify-studio.tech |
| Supabase Admin | supabase-admin@nexify-studio.tech |
| Firebase Admin | firebase-admin@nexify-studio.tech |

---

## 🔗 Useful Links / Užitočné Odkazy

- [Supabase Security Docs](https://supabase.com/docs/guides/auth/server-side)
- [Firebase Security Rules](https://firebase.google.com/docs/rules)
- [GitHub Secret Scanning](https://docs.github.com/en/code-security/secret-scanning/about-secret-scanning)
- [OWASP API Security](https://owasp.org/www-project-api-security/)

---

*Document created: 2026-07-20*  
*Last updated: 2026-07-20*  
*Version: 1.0.0*
