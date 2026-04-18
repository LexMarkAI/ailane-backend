-- Migration: 20260415220259_create_prospect_management_schema
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_prospect_management_schema


-- ═══════════════════════════════════════════════════════════
-- PROSPECT MANAGEMENT SCHEMA
-- Supports Institutional prospect tracking, preview dashboards,
-- Eileen sales interactions, and document vault pre-mapping
-- ═══════════════════════════════════════════════════════════

-- Prospect organisations — institutional targets
CREATE TABLE IF NOT EXISTS prospect_organisations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    companies_house_number TEXT,
    sic_codes TEXT[],
    registered_address TEXT,
    employee_count INTEGER,
    sector TEXT,
    
    -- Preview access
    preview_token TEXT UNIQUE NOT NULL,
    preview_created_at TIMESTAMPTZ DEFAULT NOW(),
    preview_expires_at TIMESTAMPTZ NOT NULL,
    preview_first_accessed_at TIMESTAMPTZ,
    preview_last_accessed_at TIMESTAMPTZ,
    preview_access_count INTEGER DEFAULT 0,
    
    -- Commercial status
    status TEXT NOT NULL DEFAULT 'prepared' 
        CHECK (status IN ('prepared', 'brief_sent', 'preview_active', 
                          'engaged', 'converting', 'converted', 
                          'declined', 'expired')),
    
    -- Intelligence brief tracking
    intelligence_brief_version TEXT,
    brief_sent_at TIMESTAMPTZ,
    brief_sent_method TEXT CHECK (brief_sent_method IN ('postal', 'email', 'both')),
    brief_recipient_name TEXT,
    brief_recipient_role TEXT,
    
    -- Entity consolidation data
    entity_consolidation JSONB,
    acei_profile JSONB,
    total_decisions INTEGER,
    total_estimated_ecosystem_cost NUMERIC,
    
    -- Pricing
    pricing_tier TEXT DEFAULT 'institutional',
    pricing_offered JSONB,
    pricing_accepted_at TIMESTAMPTZ,
    
    -- Vault structure
    vault_structure JSONB,
    
    -- Metadata
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Prospect interactions — Eileen conversations and engagement tracking
CREATE TABLE IF NOT EXISTS prospect_interactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    prospect_org_id UUID NOT NULL REFERENCES prospect_organisations(id) ON DELETE CASCADE,
    
    interaction_type TEXT NOT NULL 
        CHECK (interaction_type IN (
            'eileen_chat', 'page_view', 'section_view',
            'document_upload', 'compliance_check', 
            'vault_interaction', 'account_activation',
            'feature_request', 'pricing_enquiry',
            'eileen_sales_offer', 'conversion_action'
        )),
    
    -- Content
    user_message TEXT,
    eileen_response TEXT,
    section_viewed TEXT,
    
    -- Feature tracking
    feature_requests TEXT[],
    bespoke_requirements JSONB,
    
    -- Sentiment analysis
    sentiment TEXT CHECK (sentiment IN (
        'positive', 'neutral', 'negative', 
        'interested', 'committed', 'hesitant'
    )),
    
    -- Conversion signals
    conversion_signal_strength INTEGER CHECK (conversion_signal_strength BETWEEN 0 AND 10),
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Prospect vault templates — pre-mapped document vault structure
CREATE TABLE IF NOT EXISTS prospect_vault_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    prospect_org_id UUID NOT NULL REFERENCES prospect_organisations(id) ON DELETE CASCADE,
    
    -- Structure
    division TEXT NOT NULL,
    sub_division TEXT,
    vault_path TEXT NOT NULL,
    document_name TEXT NOT NULL,
    document_description TEXT,
    
    -- Compliance mapping
    acei_categories INTEGER[],
    compliance_priority TEXT CHECK (compliance_priority IN ('critical', 'high', 'medium', 'standard')),
    regulatory_hooks TEXT[],
    
    -- Document status
    placeholder_status TEXT DEFAULT 'empty' 
        CHECK (placeholder_status IN ('empty', 'uploaded', 'checking', 'checked', 'scored')),
    compliance_score NUMERIC,
    finding_count INTEGER,
    critical_finding_count INTEGER,
    
    -- Timestamps
    uploaded_at TIMESTAMPTZ,
    checked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Sort order within division
    sort_order INTEGER DEFAULT 0
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_prospect_org_token ON prospect_organisations(preview_token);
CREATE INDEX IF NOT EXISTS idx_prospect_org_status ON prospect_organisations(status);
CREATE INDEX IF NOT EXISTS idx_prospect_interactions_org ON prospect_interactions(prospect_org_id);
CREATE INDEX IF NOT EXISTS idx_prospect_interactions_type ON prospect_interactions(interaction_type);
CREATE INDEX IF NOT EXISTS idx_prospect_vault_org ON prospect_vault_templates(prospect_org_id);
CREATE INDEX IF NOT EXISTS idx_prospect_vault_division ON prospect_vault_templates(prospect_org_id, division);

-- Enable RLS
ALTER TABLE prospect_organisations ENABLE ROW LEVEL SECURITY;
ALTER TABLE prospect_interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE prospect_vault_templates ENABLE ROW LEVEL SECURITY;

-- RLS policies — CEO only (service_role for Edge Functions, authenticated for CEO dashboard)
CREATE POLICY "Service role full access on prospect_organisations"
    ON prospect_organisations FOR ALL
    USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access on prospect_interactions"
    ON prospect_interactions FOR ALL
    USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access on prospect_vault_templates"
    ON prospect_vault_templates FOR ALL
    USING (auth.role() = 'service_role');

