import fs from 'node:fs';
import path from 'node:path';

export type CheckResult = {
  id: string;
  name: string;
  status: 'PASS' | 'FAIL' | 'SKIP';
  detail?: string;
};

export type PolishReport = {
  device: string;
  baseUrl: string;
  startedAt: string;
  finishedAt?: string;
  checks: CheckResult[];
  screenshotPath?: string;
  network4xx: string[];
  recommendations: string[];
};

export function createReport(baseUrl: string): PolishReport {
  return {
    device: 'iPhone 17 Air Premium (pl-PL, Europe/Warsaw, 420×912@3x)',
    baseUrl,
    startedAt: new Date().toISOString(),
    checks: [],
    network4xx: [],
    recommendations: [
      'Safe area: pridaj padding pod Dynamic Island / status bar a nad home indicator (env(safe-area-inset-*) alebo Flutter SafeArea na shell/app bar).',
      'Font scale: over UI pri textScaleFactor 1.2–1.3 (pl-PL texty bývajú dlhšie); zabrániť overflow v AppBar/list tiles.',
      'Touch targets: všetky primárne CTA ≥ 44×44 pt; spacing medzi ikonami v bottom/nav ≥ 8 pt pre tenký Air form-factor.',
    ],
  };
}

export function writePolishReport(report: PolishReport): string {
  report.finishedAt = new Date().toISOString();
  const outDir = path.join(process.cwd(), 'e2e', 'artifacts');
  fs.mkdirSync(outDir, { recursive: true });

  const mdPath = path.join(outDir, 'iphone-17-air-premium-report.md');
  const jsonPath = path.join(outDir, 'iphone-17-air-premium-report.json');

  const pass = report.checks.filter((c) => c.status === 'PASS').length;
  const fail = report.checks.filter((c) => c.status === 'FAIL').length;
  const skip = report.checks.filter((c) => c.status === 'SKIP').length;

  const table = [
    '| ID | Check | Status | Detail |',
    '|----|-------|--------|--------|',
    ...report.checks.map(
      (c) =>
        `| ${c.id} | ${c.name} | **${c.status}** | ${(c.detail ?? '').replace(/\|/g, '\\|')} |`,
    ),
  ].join('\n');

  const md = `# iPhone 17 Air Premium · polish report

- **Device:** ${report.device}
- **Base URL:** ${report.baseUrl}
- **Started:** ${report.startedAt}
- **Finished:** ${report.finishedAt}
- **Summary:** PASS=${pass} FAIL=${fail} SKIP=${skip}

## Pass/fail table

${table}

## Screenshot

${report.screenshotPath ? `\`${report.screenshotPath}\`` : '_none_'}

## Network 4xx/5xx during boot

${
  report.network4xx.length
    ? report.network4xx.map((l) => `- \`${l}\``).join('\n')
    : '_none_'
}

## 3 UI polish recommendations (iPhone 17 Air)

${report.recommendations.map((r, i) => `${i + 1}. ${r}`).join('\n')}
`;

  fs.writeFileSync(mdPath, md, 'utf8');
  fs.writeFileSync(jsonPath, JSON.stringify(report, null, 2), 'utf8');
  return mdPath;
}
