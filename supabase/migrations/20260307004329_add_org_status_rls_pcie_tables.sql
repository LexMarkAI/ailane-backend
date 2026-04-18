-- Migration: 20260307004329_add_org_status_rls_pcie_tables
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: add_org_status_rls_pcie_tables


-- Add status column to organisations
ALTER TABLE organisations 
ADD COLUMN IF NOT EXISTS status text DEFAULT 'active' 
CHECK (status IN ('active','past_due','cancelled','suspended'));

-- Stripe indexes
CREATE INDEX IF NOT EXISTS idx_orgs_stripe_customer ON organisations(stripe_customer_id) WHERE stripe_customer_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_orgs_stripe_sub ON organisations(stripe_subscription_id) WHERE stripe_subscription_id IS NOT NULL;

-- org_members table
CREATE TABLE IF NOT EXISTS org_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  org_id uuid NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
  role text NOT NULL DEFAULT 'member' CHECK (role IN ('admin','member','viewer','legal')),
  created_at timestamptz DEFAULT now(),
  UNIQUE (user_id, org_id)
);

ALTER TABLE org_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members see own orgs" ON org_members
  FOR SELECT TO authenticated USING (user_id = auth.uid());

-- Enable RLS on PCIE tables
ALTER TABLE pcie_demonstration_entities ENABLE ROW LEVEL SECURITY;
ALTER TABLE rri_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE cci_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE vault_contract_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE pcie_session_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE cree_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE pcie_rri_pillars ENABLE ROW LEVEL SECURITY;
ALTER TABLE pcie_cci_conduct_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE pcie_cci_scores ENABLE ROW LEVEL SECURITY;

-- PCIE public read policies
CREATE POLICY "Public read pcie entities" ON pcie_demonstration_entities
  FOR SELECT TO anon, authenticated USING (is_active = true);

CREATE POLICY "Public read rri demo" ON rri_scores
  FOR SELECT TO anon, authenticated USING (is_demonstration = true);

CREATE POLICY "Public read cci demo" ON cci_scores
  FOR SELECT TO anon, authenticated USING (is_demonstration = true);

CREATE POLICY "Public read vault demo" ON vault_contract_records
  FOR SELECT TO anon, authenticated USING (is_demonstration = true);

-- Org-scoped live data
CREATE POLICY "Org read own rri" ON rri_scores
  FOR SELECT TO authenticated 
  USING (is_demonstration = false AND org_id IN (
    SELECT org_id FROM org_members WHERE user_id = auth.uid()
  ));

CREATE POLICY "Org read own cci" ON cci_scores
  FOR SELECT TO authenticated 
  USING (is_demonstration = false AND org_id IN (
    SELECT org_id FROM org_members WHERE user_id = auth.uid()
  ));

-- CREE submissions
CREATE POLICY "All tiers submit cree" ON cree_submissions
  FOR INSERT TO anon, authenticated WITH CHECK (true);

CREATE POLICY "Org read own cree" ON cree_submissions
  FOR SELECT TO authenticated USING (
    org_id IN (SELECT org_id FROM org_members WHERE user_id = auth.uid())
  );

-- Session log
CREATE POLICY "Insert session log" ON pcie_session_log
  FOR INSERT TO anon, authenticated WITH CHECK (true);

