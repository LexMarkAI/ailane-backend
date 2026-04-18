-- Migration: 20260302183450_create_campaign_prospects
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_campaign_prospects


-- AIE Migration 4: Campaign Prospect Tracking
CREATE TABLE IF NOT EXISTS campaign_prospects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employer_id uuid REFERENCES employer_master(id) ON DELETE CASCADE,
  
  segment text NOT NULL,
  segment_assigned_at timestamptz DEFAULT now(),
  segment_previous text,
  segment_changed_at timestamptz,
  
  campaign_status text DEFAULT 'new' CHECK (
    campaign_status IN (
      'new','contacted','engaged','trial',
      'converted','declined','dormant'
    )
  ),
  
  first_contact_date date,
  first_contact_channel text,
  last_contact_date date,
  total_touches integer DEFAULT 0,
  
  trial_start_date date,
  trial_tier text,
  conversion_date date,
  conversion_tier text,
  monthly_revenue numeric(10,2),
  
  campaign_source text,
  campaign_medium text,
  campaign_execution text,
  
  cost_per_lead numeric(10,2),
  days_to_trial integer,
  days_to_conversion integer,
  
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  
  UNIQUE(employer_id)
);

CREATE INDEX idx_cp_segment ON campaign_prospects(segment);
CREATE INDEX idx_cp_status ON campaign_prospects(campaign_status);
CREATE INDEX idx_cp_employer ON campaign_prospects(employer_id);

COMMENT ON TABLE campaign_prospects IS 'AIE: Campaign funnel tracking from segmentation through conversion.';

