import { expect, test } from '@playwright/test';
import { loadEnv } from '../helpers/env';

const env = loadEnv();

test.describe('Integrity · Supabase REST', () => {
  test.beforeAll(() => {
    expect(env.supabaseKey, 'VITE_SUPABASE_PUBLISHABLE_KEY missing').not.toEqual(
      '',
    );
  });

  async function restGet(path: string) {
    const url = `${env.supabaseUrl.replace(/\/$/, '')}/rest/v1/${path}`;
    const response = await fetch(url, {
      headers: {
        apikey: env.supabaseKey,
        Authorization: `Bearer ${env.supabaseKey}`,
        Accept: 'application/json',
      },
    });
    const text = await response.text();
    let json: unknown = null;
    try {
      json = text ? JSON.parse(text) : null;
    } catch {
      json = text;
    }
    return { status: response.status, json, text };
  }

  test('projects table exists and is readable', async () => {
    const { status, json } = await restGet(
      'projects?select=id,name&limit=5&order=created_at.desc',
    );
    expect(status, JSON.stringify(json)).toBe(200);
    expect(Array.isArray(json)).toBeTruthy();
  });

  test('bugs table exists and is readable', async () => {
    const { status, json } = await restGet(
      'bugs?select=id,title&limit=5&order=created_at.desc',
    );
    expect(status, JSON.stringify(json)).toBe(200);
    expect(Array.isArray(json)).toBeTruthy();
  });

  test('profiles table exists and is readable', async () => {
    const { status, json } = await restGet(
      'profiles?select=id,user_id&limit=5',
    );
    expect(status, JSON.stringify(json)).toBe(200);
    expect(Array.isArray(json)).toBeTruthy();
  });
});

test.describe('Integrity · lead-assistant edge', () => {
  const fnUrl = `${env.supabaseUrl.replace(/\/$/, '')}/functions/v1/lead-assistant`;

  test('CORS preflight allows production origin', async () => {
    const response = await fetch(fnUrl, {
      method: 'OPTIONS',
      headers: {
        Origin: env.baseUrl,
        'Access-Control-Request-Method': 'POST',
        'Access-Control-Request-Headers': 'authorization,content-type,apikey',
      },
    });
    expect(response.status).toBeLessThan(400);
    const allow = response.headers.get('access-control-allow-origin');
    expect(allow === env.baseUrl || allow === '*').toBeTruthy();
  });

  test('unauthenticated parse_leads returns unauthorized', async () => {
    const response = await fetch(fnUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Origin: env.baseUrl,
        ...(env.supabaseKey
          ? { apikey: env.supabaseKey, Authorization: `Bearer ${env.supabaseKey}` }
          : {}),
      },
      body: JSON.stringify({
        action: 'parse_leads',
        raw_text: 'x'.repeat(50),
      }),
    });
    // Edge verifies Firebase JWT; publishable key alone is not enough.
    expect([401, 403]).toContain(response.status);
    const body = (await response.json()) as { error?: string };
    expect(body.error).toBeTruthy();
  });

  test('optional live parse_leads with FIREBASE_ID_TOKEN', async () => {
    const token = process.env.FIREBASE_ID_TOKEN?.trim();
    test.skip(!token, 'Set FIREBASE_ID_TOKEN for authenticated parse smoke');

    const sample = `🔥 LEAD 1 — Playwright Smoke Co
Firma: Playwright Smoke Co s.r.o.
Web: https://playwright-smoke.example
Lokácia: Bratislava
Kontakt: Test User, CEO
Email: smoke@playwright-smoke.example
Problém: manuálne follow-upy a chýbajúci CRM pipeline
Trigger: test integrity suite
Zdroje: LinkedIn, web`;

    const response = await fetch(fnUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Origin: env.baseUrl,
        Authorization: `Bearer ${token}`,
        ...(env.supabaseKey ? { apikey: env.supabaseKey } : {}),
      },
      body: JSON.stringify({ action: 'parse_leads', raw_text: sample }),
    });

    const body = await response.json();
    expect(response.status, JSON.stringify(body)).toBe(200);
    expect(Array.isArray((body as { leads?: unknown[] }).leads)).toBeTruthy();
  });
});

test.describe('Integrity · Firebase Identity Toolkit', () => {
  test('API key allows production referer', async () => {
    test.skip(!env.firebaseApiKey, 'Firebase API key missing');

    const response = await fetch(
      `https://identitytoolkit.googleapis.com/v1/projects?key=${env.firebaseApiKey}`,
      {
        headers: {
          Origin: env.baseUrl,
          Referer: `${env.baseUrl}/`,
          'x-client-version': 'Chrome/JsCore/12.13.0/FirebaseCore-web',
        },
      },
    );
    const body = await response.json();
    expect(response.status, JSON.stringify(body)).toBe(200);
    expect((body as { projectId?: string }).projectId).toBeTruthy();
  });
});
