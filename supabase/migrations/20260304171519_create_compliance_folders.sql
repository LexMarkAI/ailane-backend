-- Migration: 20260304171519_create_compliance_folders
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_compliance_folders


-- =============================================================
-- COMPLIANCE FOLDERS: Document organisation for client accounts
-- Enables hierarchical folder structure per organisation
-- =============================================================

CREATE TABLE IF NOT EXISTS compliance_folders (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organisation_id   uuid NOT NULL REFERENCES organisations(id),
  parent_id         uuid REFERENCES compliance_folders(id),
  name              text NOT NULL,
  description       text,
  color             text DEFAULT '#22d3ee',
  icon              text DEFAULT '📁',
  sort_order        integer DEFAULT 0,
  created_by        uuid REFERENCES auth.users(id),
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  
  CONSTRAINT unique_folder_name_per_parent UNIQUE (organisation_id, parent_id, name)
);

CREATE INDEX idx_cf_org ON compliance_folders(organisation_id);
CREATE INDEX idx_cf_parent ON compliance_folders(parent_id);

-- Add folder_id to compliance_uploads
ALTER TABLE compliance_uploads ADD COLUMN folder_id uuid REFERENCES compliance_folders(id);
CREATE INDEX idx_cu_folder ON compliance_uploads(folder_id);

-- Add display_name for user-friendly labelling (file_name is raw filename)
ALTER TABLE compliance_uploads ADD COLUMN display_name text;

-- Add notes field for user annotations
ALTER TABLE compliance_uploads ADD COLUMN notes text;

-- RLS for compliance_folders
ALTER TABLE compliance_folders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated read own org folders"
  ON compliance_folders FOR SELECT
  TO authenticated
  USING (organisation_id = get_my_org_id());

CREATE POLICY "Authenticated insert own org folders"
  ON compliance_folders FOR INSERT
  TO authenticated
  WITH CHECK (organisation_id = get_my_org_id());

CREATE POLICY "Authenticated update own org folders"
  ON compliance_folders FOR UPDATE
  TO authenticated
  USING (organisation_id = get_my_org_id())
  WITH CHECK (organisation_id = get_my_org_id());

CREATE POLICY "Authenticated delete own org folders"
  ON compliance_folders FOR DELETE
  TO authenticated
  USING (organisation_id = get_my_org_id());

CREATE POLICY "Service role manage folders"
  ON compliance_folders FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Allow authenticated users to update their own uploads (move to folder, rename, add notes)
CREATE POLICY "Authenticated update own org uploads"
  ON compliance_uploads FOR UPDATE
  TO authenticated
  USING (organisation_id = get_my_org_id())
  WITH CHECK (organisation_id = get_my_org_id());

-- Updated_at trigger for folders
CREATE TRIGGER trg_cf_updated_at BEFORE UPDATE ON compliance_folders
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

