import fs from 'node:fs';
import path from 'node:path';

export type AppSecrets = {
  supabaseUrl: string;
  supabaseKey: string;
  firebaseApiKey: string;
  baseUrl: string;
};

function readSecretsFile(): Record<string, string> {
  const file = path.join(process.cwd(), 'secrets.json');
  if (!fs.existsSync(file)) return {};
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8')) as Record<string, string>;
  } catch {
    return {};
  }
}

export function loadEnv(): AppSecrets {
  const secrets = readSecretsFile();
  return {
    supabaseUrl:
      process.env.VITE_SUPABASE_URL?.trim() ||
      secrets.VITE_SUPABASE_URL ||
      'https://kpsnwpuydqqojwmrnkdy.supabase.co',
    supabaseKey:
      process.env.VITE_SUPABASE_PUBLISHABLE_KEY?.trim() ||
      secrets.VITE_SUPABASE_PUBLISHABLE_KEY ||
      '',
    firebaseApiKey:
      process.env.VITE_FIREBASE_API_KEY?.trim() ||
      secrets.VITE_FIREBASE_API_KEY ||
      '',
    baseUrl:
      process.env.E2E_BASE_URL?.trim() ||
      'https://machinegunslots.web.app',
  };
}
