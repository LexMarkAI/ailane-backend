-- Migration: 20260322214355_kltr_001_training_resources_schema
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: kltr_001_training_resources_schema


-- ═══════════════════════════════════════════════════════════════
-- AILANE-SPEC-KLTR-001 v1.0 — Sprint 1 Database Migration
-- Knowledge Library Training Resources Architecture
-- AMD-026 · Ratified 22 March 2026
-- ═══════════════════════════════════════════════════════════════

-- ────────────────────────────────────────────────────────────────
-- TABLE 1: kl_training_resources
-- Master table for all training content across all three phases
-- ────────────────────────────────────────────────────────────────
CREATE TABLE public.kl_training_resources (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    title           text NOT NULL,
    slug            text UNIQUE NOT NULL,
    description     text,
    content_html    text,
    content_type    text NOT NULL CHECK (content_type IN (
                        'written_guide', 'visual_aid', 'video',
                        'interactive_module', 'factsheet', 'code_of_practice',
                        'enforcement_notice', 'template_document', 'checklist'
                    )),
    source_phase    smallint NOT NULL CHECK (source_phase IN (1, 2, 3)),
    acei_categories text[] NOT NULL DEFAULT '{}',
    primary_acei_category text,
    tier_access     text NOT NULL DEFAULT 'operational_readiness' CHECK (tier_access IN (
                        'operational_readiness', 'governance', 'institutional'
                    )),
    source_licence  text NOT NULL CHECK (source_licence IN (
                        'ogl_v3', 'cc_by_4', 'cc_by_sa_4', 'ailane_original', 'crown_copyright'
                    )),
    publisher_body  text,
    provenance_url  text,
    attribution_statement text,
    jurisdiction_code text NOT NULL DEFAULT 'GB',
    is_published    boolean NOT NULL DEFAULT false,
    current_as_of   date,
    superseded_by   uuid REFERENCES public.kl_training_resources(id),
    version         text NOT NULL DEFAULT '1.0',
    tags            text[] DEFAULT '{}',
    word_count      integer,
    estimated_read_minutes smallint,
    sort_order      integer DEFAULT 0,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.kl_training_resources IS
    'KLTR-001: Master training resources table. Three-phase pipeline: OGL curation, direct source acquisition, original production. Constitutional separation: training content never modifies ACEI/RRI/CCI scores.';

COMMENT ON COLUMN public.kl_training_resources.source_phase IS
    'Content source phase: 1=OGL curation, 2=direct source acquisition, 3=Ailane original production';

COMMENT ON COLUMN public.kl_training_resources.source_licence IS
    'Licence under which content is used: ogl_v3, cc_by_4, cc_by_sa_4, ailane_original, crown_copyright';

-- ────────────────────────────────────────────────────────────────
-- TABLE 2: kl_licence_register
-- Licence verification audit trail (internal only)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE public.kl_licence_register (
    id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    resource_id             uuid NOT NULL REFERENCES public.kl_training_resources(id) ON DELETE CASCADE,
    publisher_body          text NOT NULL,
    licence_type            text NOT NULL CHECK (licence_type IN (
                                'ogl_v3', 'cc_by_4', 'cc_by_sa_4', 'cc_by_nc_4',
                                'crown_copyright', 'ailane_original', 'other'
                            )),
    source_url              text,
    -- Three-step verification protocol (KLTR-001 §4.4)
    step1_publisher_verified    boolean NOT NULL DEFAULT false,
    step1_verified_at           timestamptz,
    step1_notes                 text,
    step2_content_licence_verified boolean NOT NULL DEFAULT false,
    step2_verified_at           timestamptz,
    step2_notes                 text,
    step3_exemption_checked     boolean NOT NULL DEFAULT false,
    step3_verified_at           timestamptz,
    step3_notes                 text,
    -- Overall verification status
    verification_status     text NOT NULL DEFAULT 'pending' CHECK (verification_status IN (
                                'pending', 'verified', 'rejected', 'review_required'
                            )),
    verified_by             text NOT NULL DEFAULT 'manual_review' CHECK (verified_by IN (
                                'system', 'manual_review', 'ceo_review'
                            )),
    rejection_reason        text,
    review_notes            text,
    created_at              timestamptz NOT NULL DEFAULT now(),
    updated_at              timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.kl_licence_register IS
    'KLTR-001 §4.4: Three-step licence verification audit trail. Internal only — not exposed to clients. Constitutes Ailane compliance evidence for OGL usage.';

-- ────────────────────────────────────────────────────────────────
-- TABLE 3: kl_training_progress
-- User engagement tracking (informational only — no score impact)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE public.kl_training_progress (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    resource_id     uuid NOT NULL REFERENCES public.kl_training_resources(id) ON DELETE CASCADE,
    org_id          uuid REFERENCES public.organisations(id),
    status          text NOT NULL DEFAULT 'not_started' CHECK (status IN (
                        'not_started', 'in_progress', 'completed'
                    )),
    progress_pct    smallint DEFAULT 0 CHECK (progress_pct >= 0 AND progress_pct <= 100),
    started_at      timestamptz,
    completed_at    timestamptz,
    last_accessed_at timestamptz,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    UNIQUE(user_id, resource_id)
);

COMMENT ON TABLE public.kl_training_progress IS
    'KLTR-001 §6.2.4: Training engagement tracking. Informational only — completion NEVER modifies ACEI, RRI, or CCI scores. Constitutional separation maintained.';

-- ────────────────────────────────────────────────────────────────
-- TABLE 4: kl_training_media
-- Media file references for video and visual content
-- ────────────────────────────────────────────────────────────────
CREATE TABLE public.kl_training_media (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    resource_id     uuid NOT NULL REFERENCES public.kl_training_resources(id) ON DELETE CASCADE,
    media_type      text NOT NULL CHECK (media_type IN (
                        'video', 'image', 'pdf', 'audio', 'infographic', 'flowchart'
                    )),
    storage_path    text NOT NULL,
    file_size_bytes bigint,
    duration_seconds integer,
    mime_type       text NOT NULL,
    thumbnail_path  text,
    alt_text        text,
    caption_path    text,
    sort_order      smallint DEFAULT 0,
    created_at      timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.kl_training_media IS
    'KLTR-001 §5.3: Media files hosted in Supabase Storage. No external platform dependency. Full CDN control.';

-- ────────────────────────────────────────────────────────────────
-- INDEXES
-- ────────────────────────────────────────────────────────────────
CREATE INDEX idx_kl_tr_acei_cats ON public.kl_training_resources USING GIN (acei_categories);
CREATE INDEX idx_kl_tr_content_type ON public.kl_training_resources (content_type);
CREATE INDEX idx_kl_tr_source_phase ON public.kl_training_resources (source_phase);
CREATE INDEX idx_kl_tr_tier_access ON public.kl_training_resources (tier_access);
CREATE INDEX idx_kl_tr_published ON public.kl_training_resources (is_published) WHERE is_published = true;
CREATE INDEX idx_kl_tr_jurisdiction ON public.kl_training_resources (jurisdiction_code);
CREATE INDEX idx_kl_lr_resource ON public.kl_licence_register (resource_id);
CREATE INDEX idx_kl_lr_status ON public.kl_licence_register (verification_status);
CREATE INDEX idx_kl_tp_user ON public.kl_training_progress (user_id);
CREATE INDEX idx_kl_tp_org ON public.kl_training_progress (org_id) WHERE org_id IS NOT NULL;
CREATE INDEX idx_kl_tp_resource ON public.kl_training_progress (resource_id);
CREATE INDEX idx_kl_tm_resource ON public.kl_training_media (resource_id);

-- ────────────────────────────────────────────────────────────────
-- ROW LEVEL SECURITY
-- ────────────────────────────────────────────────────────────────
ALTER TABLE public.kl_training_resources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kl_licence_register ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kl_training_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kl_training_media ENABLE ROW LEVEL SECURITY;

-- kl_training_resources: All authenticated users can read published resources
-- Tier filtering will be handled at application level via tier_access column
CREATE POLICY "kl_tr_read_published" ON public.kl_training_resources
    FOR SELECT TO authenticated
    USING (is_published = true);

-- Service role can manage all resources
CREATE POLICY "kl_tr_service_manage" ON public.kl_training_resources
    FOR ALL TO service_role
    USING (true) WITH CHECK (true);

-- kl_licence_register: Internal only — service role access
CREATE POLICY "kl_lr_service_only" ON public.kl_licence_register
    FOR ALL TO service_role
    USING (true) WITH CHECK (true);

-- kl_training_progress: Users see their own progress
CREATE POLICY "kl_tp_own_progress" ON public.kl_training_progress
    FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Service role can manage all progress records
CREATE POLICY "kl_tp_service_manage" ON public.kl_training_progress
    FOR ALL TO service_role
    USING (true) WITH CHECK (true);

-- kl_training_media: Read access follows parent resource visibility
CREATE POLICY "kl_tm_read_published" ON public.kl_training_media
    FOR SELECT TO authenticated
    USING (EXISTS (
        SELECT 1 FROM public.kl_training_resources tr
        WHERE tr.id = kl_training_media.resource_id
        AND tr.is_published = true
    ));

-- Service role can manage all media
CREATE POLICY "kl_tm_service_manage" ON public.kl_training_media
    FOR ALL TO service_role
    USING (true) WITH CHECK (true);

-- ────────────────────────────────────────────────────────────────
-- UPDATED_AT TRIGGER
-- ────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.kltr_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_kl_tr_updated_at BEFORE UPDATE ON public.kl_training_resources
    FOR EACH ROW EXECUTE FUNCTION public.kltr_set_updated_at();

CREATE TRIGGER trg_kl_lr_updated_at BEFORE UPDATE ON public.kl_licence_register
    FOR EACH ROW EXECUTE FUNCTION public.kltr_set_updated_at();

CREATE TRIGGER trg_kl_tp_updated_at BEFORE UPDATE ON public.kl_training_progress
    FOR EACH ROW EXECUTE FUNCTION public.kltr_set_updated_at();

