
-- AI Provider configs (per user)
CREATE TABLE public.ai_provider_configs (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  provider TEXT NOT NULL CHECK (provider IN ('mistral','openai','anythingllm')),
  enabled BOOLEAN NOT NULL DEFAULT true,
  default_model TEXT,
  anythingllm_base_url TEXT,
  anythingllm_workspace_slug TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, provider)
);
ALTER TABLE public.ai_provider_configs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "owner select ai_provider_configs" ON public.ai_provider_configs
  FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "owner insert ai_provider_configs" ON public.ai_provider_configs
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "owner update ai_provider_configs" ON public.ai_provider_configs
  FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "owner delete ai_provider_configs" ON public.ai_provider_configs
  FOR DELETE TO authenticated USING (auth.uid() = user_id);

CREATE TRIGGER trg_ai_provider_configs_updated_at
  BEFORE UPDATE ON public.ai_provider_configs
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- AI Conversations
CREATE TABLE public.ai_conversations (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  title TEXT NOT NULL DEFAULT 'New chat',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.ai_conversations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "owner select ai_conversations" ON public.ai_conversations
  FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "owner insert ai_conversations" ON public.ai_conversations
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "owner update ai_conversations" ON public.ai_conversations
  FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "owner delete ai_conversations" ON public.ai_conversations
  FOR DELETE TO authenticated USING (auth.uid() = user_id);

CREATE TRIGGER trg_ai_conversations_updated_at
  BEFORE UPDATE ON public.ai_conversations
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE INDEX idx_ai_conversations_user ON public.ai_conversations(user_id, updated_at DESC);

-- AI Messages
CREATE TABLE public.ai_messages (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  conversation_id UUID NOT NULL REFERENCES public.ai_conversations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('user','assistant','system','tool')),
  content TEXT NOT NULL DEFAULT '',
  provider TEXT,
  model TEXT,
  tokens_in INTEGER,
  tokens_out INTEGER,
  latency_ms INTEGER,
  error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.ai_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "owner select ai_messages" ON public.ai_messages
  FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "owner insert ai_messages" ON public.ai_messages
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "owner delete ai_messages" ON public.ai_messages
  FOR DELETE TO authenticated USING (auth.uid() = user_id);

CREATE INDEX idx_ai_messages_conv ON public.ai_messages(conversation_id, created_at);

ALTER PUBLICATION supabase_realtime ADD TABLE public.ai_messages;
ALTER TABLE public.ai_messages REPLICA IDENTITY FULL;
