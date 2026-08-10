import { corsHeaders } from 'npm:@supabase/supabase-js@2/cors';
import { createClient } from 'npm:@supabase/supabase-js@2';

const GATEWAY_URL = 'https://connector-gateway.lovable.dev/wordpress_com/rest/v1.1';
const SELF_HOSTED_ACTIONS = new Set(['self-hosted-status', 'self-hosted-projects', 'self-hosted-posts']);

type WPProject = {
  id: string;
  title: string;
  description: string;
  url: string;
  modified: string;
  type: string;
  rawText: string;
};

const stripHtml = (value = '') =>
  value
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&#8211;/g, '-')
    .replace(/&#8217;/g, "'")
    .replace(/\s+/g, ' ')
    .trim();

const normalizeSiteUrl = (value: string) => value.replace(/\/+$/, '');

const buildBasicAuth = (username: string, password: string) =>
  `Basic ${btoa(`${username}:${password.replace(/\s+/g, '')}`)}`;

const wpRestFetch = async (path: string, init: RequestInit = {}) => {
  const siteUrl = Deno.env.get('WORDPRESS_SITE_URL');
  const username = Deno.env.get('WORDPRESS_USERNAME');
  const appPassword = Deno.env.get('WORDPRESS_APP_PASSWORD');

  if (!siteUrl) throw new Error('WORDPRESS_SITE_URL is not configured');

  const headers = new Headers(init.headers);
  headers.set('Accept', 'application/json');
  if (username && appPassword) {
    headers.set('Authorization', buildBasicAuth(username, appPassword));
  }

  const response = await fetch(`${normalizeSiteUrl(siteUrl)}${path}`, {
    ...init,
    headers,
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    return {
      wp_error: true,
      status: response.status,
      code: data?.code ?? 'wordpress_rest_error',
      message: data?.message ?? `WordPress REST API failed [${response.status}]`,
    };
  }
  return data;
};

const normalizeProject = (item: Record<string, unknown>): WPProject => {
  const title = stripHtml((item.title as { rendered?: string })?.rendered ?? String(item.slug ?? 'WordPress projekt'));
  const excerpt = stripHtml((item.excerpt as { rendered?: string })?.rendered ?? '');
  const content = stripHtml((item.content as { rendered?: string })?.rendered ?? '');
  const description = excerpt || content.slice(0, 220) || 'Projekt načítaný z WordPressu.';
  const modified = String(item.modified_gmt || item.modified || item.date_gmt || item.date || new Date().toISOString());
  const url = String(item.link || '');
  const type = String(item.type || 'post');

  return {
    id: `wp-${type}-${item.id}`,
    title,
    description,
    url,
    modified,
    type,
    rawText: `${title} ${description} ${content} ${url}`,
  };
};

const fetchSelfHostedProjects = async (number: number) => {
  const fields = 'id,date,date_gmt,modified,modified_gmt,slug,link,type,title,excerpt,content';
  const query = `_fields=${encodeURIComponent(fields)}&per_page=${number}&orderby=modified&order=desc&status=publish`;
  const [posts, pages] = await Promise.all([
    wpRestFetch(`/wp-json/wp/v2/posts?${query}`),
    wpRestFetch(`/wp-json/wp/v2/pages?${query}`),
  ]);

  const firstError = posts?.wp_error ? posts : pages?.wp_error ? pages : null;
  if (firstError) return firstError;

  const items = [...(Array.isArray(posts) ? posts : []), ...(Array.isArray(pages) ? pages : [])]
    .map(normalizeProject)
    .sort((a, b) => new Date(b.modified).getTime() - new Date(a.modified).getTime())
    .slice(0, number);

  return {
    site_url: Deno.env.get('WORDPRESS_SITE_URL'),
    projects: items,
  };
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
    const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_PUBLISHABLE_KEY') ?? Deno.env.get('SUPABASE_ANON_KEY')!;

    // Auth check — require logged-in Triage user
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing authorization' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userErr } = await supabase.auth.getUser();
    if (userErr || !userData.user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const body = await req.json().catch(() => ({}));
    const action: string = body.action ?? 'list';
    const siteId: string | undefined = body.site_id;
    const postId: string | undefined = body.post_id;
    const number: number = Math.min(Math.max(Number(body.number ?? 20), 1), 50);

    if (SELF_HOSTED_ACTIONS.has(action)) {
      let data;
      if (action === 'self-hosted-status') {
        data = await wpRestFetch('/wp-json');
      } else if (action === 'self-hosted-projects') {
        data = await fetchSelfHostedProjects(number);
      } else {
        data = await wpRestFetch(`/wp-json/wp/v2/posts?per_page=${number}&orderby=modified&order=desc&status=publish`);
      }

      return new Response(JSON.stringify(data), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const LOVABLE_API_KEY = Deno.env.get('LOVABLE_API_KEY');
    const WORDPRESS_COM_API_KEY = Deno.env.get('WORDPRESS_COM_API_KEY');

    if (!LOVABLE_API_KEY) throw new Error('LOVABLE_API_KEY is not configured');
    if (!WORDPRESS_COM_API_KEY) throw new Error('WORDPRESS_COM_API_KEY is not configured');

    const wpHeaders = {
      Authorization: `Bearer ${LOVABLE_API_KEY}`,
      'X-Connection-Api-Key': WORDPRESS_COM_API_KEY,
    };

    let path = '';
    if (action === 'sites') {
      path = '/me/sites?fields=ID,name,URL,description,icon';
    } else if (action === 'list') {
      if (!siteId) throw new Error('site_id is required for list');
      path = `/sites/${encodeURIComponent(siteId)}/posts?number=${number}&fields=ID,title,excerpt,date,URL,featured_image,author,slug`;
    } else if (action === 'detail') {
      if (!siteId || !postId) throw new Error('site_id and post_id are required for detail');
      path = `/sites/${encodeURIComponent(siteId)}/posts/${encodeURIComponent(postId)}`;
    } else {
      throw new Error(`Unknown action: ${action}`);
    }

    const res = await fetch(`${GATEWAY_URL}${path}`, { headers: wpHeaders });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      // Return upstream errors with HTTP 200 so they don't surface as runtime errors.
      // Client inspects `wp_error` to decide UX (e.g. fall back to manual site entry).
      console.warn(`WordPress.com API ${res.status} on ${path}:`, JSON.stringify(data));
      return new Response(
        JSON.stringify({
          wp_error: true,
          status: res.status,
          code: data?.error ?? 'unknown',
          message: data?.message ?? `WordPress.com API failed [${res.status}]`,
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    return new Response(JSON.stringify(data), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    console.error('wp-proxy error:', message);
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
