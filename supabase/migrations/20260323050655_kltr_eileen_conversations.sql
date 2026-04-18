-- Migration: 20260323050655_kltr_eileen_conversations
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: kltr_eileen_conversations


-- ================================================================
-- AILANE — Eileen Training Intelligence: Conversation & Learning Table
-- Governing: AILANE-SPEC-EILEEN-002-AM-001 (pending ratification)
-- Governing: AILANE-SPEC-KLTR-001 v1.0 (AMD-026)
-- ================================================================

-- Eileen conversation log — stores every interaction for quality review,
-- learning evolution, knowledge gap detection, and response improvement.
CREATE TABLE public.kl_eileen_conversations (
    id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Session identification
    session_id              text NOT NULL,                          -- Browser session identifier (generated client-side)
    user_id                 uuid REFERENCES auth.users(id),        -- NULL for anonymous visitors
    is_authenticated        boolean NOT NULL DEFAULT false,
    
    -- Conversation content
    user_message            text NOT NULL,                          -- The question as typed by the user
    eileen_response         text NOT NULL,                          -- Full response returned to the user
    
    -- Context used for generation
    guide_ids_used          uuid[] DEFAULT '{}',                    -- Which kl_training_resources rows were sent as context
    guide_slugs_used        text[] DEFAULT '{}',                    -- Slugs for human readability in review
    categories_matched      text[] DEFAULT '{}',                    -- ACEI categories detected in the question
    total_context_tokens    integer,                                -- Approximate token count of context sent to Claude
    
    -- Response quality tracking
    response_time_ms        integer,                                -- Time from request to response in milliseconds
    claude_model_used       text DEFAULT 'claude-sonnet-4-20250514',
    feedback_rating         smallint CHECK (feedback_rating IS NULL OR feedback_rating IN (-1, 1)),  -- -1 = thumbs down, 1 = thumbs up
    feedback_comment        text,                                   -- Optional free-text feedback (future)
    
    -- Adaptive learning — knowledge level detection
    detected_knowledge_level text NOT NULL DEFAULT 'beginner' 
        CHECK (detected_knowledge_level IN ('beginner', 'intermediate', 'advanced')),
    knowledge_level_signals  jsonb DEFAULT '{}',                    -- Evidence for the classification
    
    -- Knowledge gap detection
    is_knowledge_gap        boolean NOT NULL DEFAULT false,         -- True if Eileen couldn't find relevant guide content
    knowledge_gap_topic     text,                                   -- What the user was asking about that we don't cover
    
    -- Freshness awareness
    stale_guides_referenced boolean NOT NULL DEFAULT false,         -- True if any referenced guide was review_due or stale
    freshness_disclosure    boolean NOT NULL DEFAULT false,         -- True if Eileen disclosed the freshness status
    
    -- Metadata
    page_context            text DEFAULT 'training',                -- Which page Eileen was accessed from
    user_agent              text,                                   -- Browser user agent for analytics
    created_at              timestamptz NOT NULL DEFAULT now()
);

-- Indexes for analytical queries and CEO Command Centre
CREATE INDEX idx_eileen_conv_session     ON public.kl_eileen_conversations(session_id);
CREATE INDEX idx_eileen_conv_created     ON public.kl_eileen_conversations(created_at DESC);
CREATE INDEX idx_eileen_conv_gap         ON public.kl_eileen_conversations(is_knowledge_gap) WHERE is_knowledge_gap = true;
CREATE INDEX idx_eileen_conv_feedback    ON public.kl_eileen_conversations(feedback_rating) WHERE feedback_rating IS NOT NULL;
CREATE INDEX idx_eileen_conv_user        ON public.kl_eileen_conversations(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_eileen_conv_categories  ON public.kl_eileen_conversations USING gin(categories_matched);

-- Comments for institutional documentation
COMMENT ON TABLE public.kl_eileen_conversations IS 'Eileen Training Intelligence conversation log. Stores all user interactions for quality review, learning evolution, knowledge gap detection, and response improvement. Governed by AILANE-SPEC-EILEEN-002-AM-001.';
COMMENT ON COLUMN public.kl_eileen_conversations.detected_knowledge_level IS 'Adaptive learning classification: beginner (plain language, no statutory refs), intermediate (some legal awareness), advanced (uses statutory section numbers, case names)';
COMMENT ON COLUMN public.kl_eileen_conversations.is_knowledge_gap IS 'Flagged when the question could not be matched to any guide content. Feeds into KLTR-001 Sprint 3+ content planning.';
COMMENT ON COLUMN public.kl_eileen_conversations.feedback_rating IS 'User quality signal: -1 = thumbs down (flagged for review), 1 = thumbs up';

-- RLS Policies
ALTER TABLE public.kl_eileen_conversations ENABLE ROW LEVEL SECURITY;

-- Service role: full access (Edge Function writes, CEO reads)
CREATE POLICY kl_ec_service_manage
    ON public.kl_eileen_conversations
    FOR ALL
    USING (auth.role() = 'service_role');

-- Authenticated users can read their own conversations
CREATE POLICY kl_ec_user_read_own
    ON public.kl_eileen_conversations
    FOR SELECT
    USING (auth.role() = 'authenticated' AND user_id = auth.uid());

-- Authenticated users can update feedback on their own conversations
CREATE POLICY kl_ec_user_feedback
    ON public.kl_eileen_conversations
    FOR UPDATE
    USING (auth.role() = 'authenticated' AND user_id = auth.uid())
    WITH CHECK (auth.role() = 'authenticated' AND user_id = auth.uid());

-- Anon role: insert only (anonymous visitors can create conversations via Edge Function)
-- Edge Function uses service_role key, so this is a safety net
CREATE POLICY kl_ec_anon_insert
    ON public.kl_eileen_conversations
    FOR INSERT
    WITH CHECK (auth.role() = 'anon');

