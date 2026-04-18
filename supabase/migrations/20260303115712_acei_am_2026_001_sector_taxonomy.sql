-- Migration: 20260303115712_acei_am_2026_001_sector_taxonomy
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: acei_am_2026_001_sector_taxonomy


-- ============================================================================
-- ACEI-AM-2026-001: Revised Sector Multiplier Taxonomy
-- Minor Amendment under Article XII — Replaces Annex B Section B1
-- 32 sectors across 10 groups. SM range 0.80-1.30 (unchanged)
-- F2 Local Government capped at SM ceiling 1.30; additional regional
-- risk captured by JM elevation under ACEI-AM-2026-002
-- ============================================================================

CREATE TABLE acei_sector_sic_map (
    id SERIAL PRIMARY KEY,
    sector_code TEXT NOT NULL UNIQUE,
    sector_name TEXT NOT NULL,
    sector_group TEXT NOT NULL,
    sector_group_name TEXT NOT NULL,
    sector_multiplier NUMERIC(4,2) NOT NULL CHECK (sector_multiplier BETWEEN 0.80 AND 1.30),
    sic_prefixes TEXT[] NOT NULL DEFAULT '{}',
    requires_override BOOLEAN DEFAULT FALSE,
    rationale TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_sector_sic_map_code ON acei_sector_sic_map(sector_code);
CREATE INDEX idx_sector_sic_map_group ON acei_sector_sic_map(sector_group);

ALTER TABLE employer_master 
  ADD COLUMN acei_sector_code TEXT,
  ADD COLUMN acei_sector_group TEXT,
  ADD COLUMN acei_sector_override TEXT,
  ADD COLUMN acei_sector_multiplier NUMERIC(4,2);

CREATE INDEX idx_employer_sector_code ON employer_master(acei_sector_code);
CREATE INDEX idx_employer_sector_group ON employer_master(acei_sector_group);

INSERT INTO acei_sector_sic_map (sector_code, sector_name, sector_group, sector_group_name, sector_multiplier, sic_prefixes, requires_override, rationale) VALUES
('A1','Retail — Supermarket & Grocery','A','Consumer Services',1.10,ARRAY['4711'],FALSE,'Unionised workforce, high volume, discrimination & dismissal dominant'),
('A2','Retail — General & Specialty','A','Consumer Services',1.05,ARRAY['47'],FALSE,'Lower per-employer volume, narrower claim profile'),
('A3','Hospitality — Accommodation','A','Consumer Services',1.20,ARRAY['55'],FALSE,'Seasonal workforce, zero-hours prevalence, wages/working time concentration'),
('A4','Hospitality — Food & Beverage','A','Consumer Services',1.20,ARRAY['56'],FALSE,'Highest tribunal density per employer. Wages/working time at 2x retail proportion'),
('A5','Leisure, Sport & Recreation','A','Consumer Services',1.10,ARRAY['93'],FALSE,'Mixed employment models, casual/zero-hours/volunteer boundary'),
('A6','Personal Services','A','Consumer Services',1.10,ARRAY['96'],FALSE,'Employment status boundary (chair rental vs employment)'),
('B1','Platform & Gig Economy','B','Transport & Distribution',1.30,ARRAY[]::TEXT[],TRUE,'Existential Category 5 risk. Override classification required'),
('B2','Last-Mile & Parcel Delivery','B','Transport & Distribution',1.15,ARRAY['5320'],FALSE,'Hybrid DSP model, blend of Category 5 and Category 3'),
('B3','Postal & Traditional Logistics','B','Transport & Distribution',1.10,ARRAY['5310','52'],FALSE,'Fully employed, unionised. Category 1, 8, 6 dominant'),
('B4','Road Haulage & Freight','B','Transport & Distribution',1.05,ARRAY['4941','4942'],FALSE,'Narrow profile: working time, tachograph, driving hours, H&S'),
('B5','Warehousing & Storage','B','Transport & Distribution',1.10,ARRAY['521'],FALSE,'H&S over-represented, night shift exposure, agency worker boundary'),
('B6','Passenger Transport','B','Transport & Distribution',1.10,ARRAY['491','492','493','494'],FALSE,'Bus, rail, taxi. Discrimination elevated, shift patterns'),
('C1','Banking & Investment','C','Financial Services',1.25,ARRAY['64','66'],FALSE,'FCA-regulated. Highest whistleblowing exposure. SM&CR dynamics'),
('C2','Insurance & Reinsurance','C','Financial Services',1.20,ARRAY['65'],FALSE,'Regulated, lower enforcement than banking'),
('D1','Legal Services','D','Professional & Business Services',1.25,ARRAY['6910'],FALSE,'Partnership structures, gender discrimination, SRA oversight'),
('D2','Accounting, Consulting & Advisory','D','Professional & Business Services',1.15,ARRAY['692','70'],FALSE,'Big Four volume, graduate/associate dismissal patterns'),
('D3','Recruitment & Staffing','D','Professional & Business Services',1.20,ARRAY['78'],FALSE,'AWR compliance burden, employment status boundary'),
('D4','Outsourcing & Facilities Management','D','Professional & Business Services',1.20,ARRAY['81','82'],FALSE,'Largest SIC group (1,769 employers). TUPE exposure'),
('D5','Security Services','D','Professional & Business Services',1.15,ARRAY['80'],FALSE,'Night work/lone worker H&S. TUPE on contract changes'),
('E1','NHS & Public Healthcare','E','Healthcare & Social Care',1.20,ARRAY['86'],FALSE,'Unionised, whistleblowing concentration. Public sector override'),
('E2','Private Healthcare','E','Healthcare & Social Care',1.15,ARRAY['86'],FALSE,'Smaller scale, CQC-regulated. Private sector default'),
('E3','Social Care & Residential','E','Healthcare & Social Care',1.25,ARRAY['87','88'],FALSE,'Highest wages/WT risk. Sleep-in pay litigation. Zero-hours'),
('F1','Central Government & Civil Service','F','Public Sector',1.25,ARRAY['84'],FALSE,'Secretary of State respondent. Override classification'),
('F2','Local Government','F','Public Sector',1.30,ARRAY['84'],FALSE,'SM ceiling. Scottish council anomaly captured by JM elevation'),
('G1','Higher Education','G','Education',1.15,ARRAY['8542'],FALSE,'Casualised academic workforce, UCU disputes, gender pay gap'),
('G2','Schools, Academies & Further Education','G','Education',1.10,ARRAY['85'],FALSE,'Academy trusts, safeguarding dismissals, term-time wages'),
('H1','Technology — Enterprise & IT Services','H','Technology & Digital',1.10,ARRAY['62','63'],FALSE,'Moderate baseline. Data protection over-represented'),
('H2','Digital Platforms & Marketplace','H','Technology & Digital',1.25,ARRAY[]::TEXT[],TRUE,'Non-transport platforms. Employment status risk. Override'),
('I1','Manufacturing','I','Traditional Industries',1.00,ARRAY['10','11','12','13','14','15','16','17','18','19','20','21','22','23','24','25','26','27','28','29','30','31','32','33'],FALSE,'Constitutional baseline sector'),
('I2','Construction — Principal Contractors','I','Traditional Industries',0.95,ARRAY['41'],FALSE,'CDM regulation reduces exposure'),
('I3','Construction — Specialist Trades','I','Traditional Industries',1.00,ARRAY['42','43'],FALSE,'CIS self-employment creates Category 5 boundary risk'),
('I4','Energy & Utilities','I','Traditional Industries',1.05,ARRAY['35','36','37','38','39'],FALSE,'Net-zero transition redundancy. Ofgem/Ofwat overlay'),
('I5','Agriculture & Primary Industries','I','Traditional Industries',0.90,ARRAY['01','02','03'],FALSE,'Lowest tribunal volume. GLAA enforcement'),
('J1','Media, Broadcasting & Creative Arts','J','Media, Creative & Third Sector',1.15,ARRAY['59','60','90'],FALSE,'Freelance/contractor models. IR35'),
('J2','Charities & Third Sector','J','Media, Creative & Third Sector',0.90,ARRAY['94'],FALSE,'Below baseline. Lower litigation propensity');

ALTER TABLE acei_sector_sic_map ENABLE ROW LEVEL SECURITY;
CREATE POLICY anon_read_sector_map ON acei_sector_sic_map FOR SELECT TO anon USING (true);
CREATE POLICY auth_all_sector_map ON acei_sector_sic_map FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY service_all_sector_map ON acei_sector_sic_map FOR ALL TO service_role USING (true) WITH CHECK (true);

