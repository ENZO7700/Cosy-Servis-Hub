# Prompt · iPhone 17 Air Premium polish (pl-PL)

**Status: IMPLEMENTED**  
Suite: `e2e/mobile/iphone-17-air-premium.polish.spec.ts`  
Run: `npm run test:iphone-air`  
Report: `e2e/artifacts/iphone-17-air-premium-report.md`

Skopíruj a použij v agentovi / QA:

---

Si senior mobile QA + Playwright engineer pre Flutter Web app **Centralny Dashboard**.

## Cieľ
Spusti a rozšír **premium polish** test suite na zariadení **iPhone 17 Air Premium** s locale **pl-PL** (Europe/Warsaw).

## Device profile
- Názov: `iPhone 17 Air Premium`
- Viewport: `420 × 912`, DPR `3`
- `isMobile: true`, `hasTouch: true`
- UA: iPhone iOS 19 Safari
- `locale: pl-PL`, `timezoneId: Europe/Warsaw`
- Color scheme: dark
- Base URL default: `https://machinegunslots.web.app` (override cez `E2E_BASE_URL`)

## Povinné kontroly (polish)
1. **Shell load** – `flutter-view` visible, `flt-glass-pane` attached, `main.dart.js` loaded
2. **No horizontal overflow** – `scrollWidth - clientWidth <= 2`
3. **Full-bleed** – flutter-view width ≈ viewport width (±24px)
4. **Touch profile** – `navigator.maxTouchPoints > 0`
5. **Locale** – `navigator.language` starts with `pl`, TZ `Europe/Warsaw`
6. **Integrity boot** – no HTTP 4xx/5xx on `/rest/v1/bugs` and `/rest/v1/projects` during first 3s
7. **Screenshot attach** – home portrait PNG do reportu
8. **Perf soft** – DOMContentLoaded < 30s na remote CDN

## Out of scope
- Google OAuth popup login (manuálne)
- Pixel-perfect visual regression baseline (zatiaľ attach only)

## Príkazy
```bash
npm install
npx playwright install webkit chromium
npm run test:iphone-air
# headed:
npm run test:iphone-air:headed
# iný deploy:
E2E_BASE_URL=https://flutterdashb-h4ck3d.vercel.app npm run test:iphone-air
```

## Výstup, ktorý chcem
- Pass/fail tabuľka P1–P6
- Cesta k PNG screenshotu
- Zoznam network 4xx (ak nejaké)
- 3 konkrétne UI polish odporúčania pre iPhone 17 Air (safe area, font, touch targets)

---
