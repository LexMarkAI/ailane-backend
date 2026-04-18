-- Migration: 20260303115801_acei_am_2026_002_jurisdiction_subregional
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: acei_am_2026_002_jurisdiction_subregional


-- ============================================================================
-- ACEI-AM-2026-002: Revised Jurisdiction Multiplier & Sub-Regional Framework
-- Minor Amendment under Article XII
-- Replaces Annex B Section B2 (JM), adds B3 (Sub-Regional), B4 (RFVM)
-- ============================================================================

-- Reference table: Jurisdiction Multipliers (revised)
CREATE TABLE acei_jurisdiction_map (
    id SERIAL PRIMARY KEY,
    jurisdiction_region TEXT NOT NULL UNIQUE,
    jurisdiction_multiplier NUMERIC(4,2) NOT NULL CHECK (jurisdiction_multiplier BETWEEN 0.90 AND 1.40),
    population_millions NUMERIC(4,1),
    rfvm_band TEXT CHECK (rfvm_band IN ('HIGH','ELEVATED','MODERATE','LOW')),
    rfvm_value NUMERIC(4,2) CHECK (rfvm_value BETWEEN 0.95 AND 1.10),
    employer_failure_rate NUMERIC(4,1),
    rationale TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed revised JM values
INSERT INTO acei_jurisdiction_map (jurisdiction_region, jurisdiction_multiplier, population_millions, rfvm_band, rfvm_value, employer_failure_rate, rationale) VALUES
('London', 1.40, 9.0, 'MODERATE', 1.00, 28.2, 'Validated. City of London concentration. FCA overlay. Highest absolute volume.'),
('Scotland', 1.30, 5.4, 'ELEVATED', 1.05, 32.1, 'Elevated from 1.20. Most distributed category profile (HHI 3008). Public sector anomaly. Separate tribunal system.'),
('South East', 1.20, 9.3, 'LOW', 0.95, 27.4, 'Reduced from 1.25. Registration artefact inflates employer count. CPE below London/Scotland.'),
('North West', 1.10, 7.4, 'HIGH', 1.10, 36.3, 'Validated. Second-highest employer failure rate. Manchester tribunal activity.'),
('West Midlands', 1.05, 5.9, 'MODERATE', 1.00, 31.5, 'Validated. Birmingham public sector drives volume.'),
('Yorkshire and Humber', 1.05, 5.5, 'HIGH', 1.10, 36.7, 'Elevated from 1.00. Highest employer failure rate nationally. Distributed category profile.'),
('East Midlands', 1.05, 4.9, 'MODERATE', 1.00, 31.5, 'Elevated from 0.95. CPE exceeds NW, WM, Y&H. Logistics hub.'),
('Wales', 1.05, 3.1, 'ELEVATED', 1.05, 32.5, 'Elevated from 1.00. Forward provision: Senedd devolution, SPPP Act.'),
('East of England', 1.00, 6.3, 'LOW', 0.95, 27.5, 'Reduced from 1.05. Low density, moderate concentration.'),
('North East', 1.00, 2.7, 'ELEVATED', 1.05, 32.5, 'Elevated from 0.95. Most distributed category profile in England (HHI 3032).'),
('South West', 0.95, 5.7, 'MODERATE', 1.00, 28.1, 'Reduced from 1.00. Lowest CPE nationally. High category concentration.'),
('Northern Ireland', 1.15, 1.9, 'LOW', 0.95, 19.4, 'Validated. Distinct legal framework. Separate tribunal system.');

-- Sub-Regional Intelligence Framework (Section B3)
CREATE TABLE acei_subregion_postcode_map (
    id SERIAL PRIMARY KEY,
    postcode_area TEXT NOT NULL,
    sub_region_name TEXT NOT NULL,
    constitutional_region TEXT NOT NULL REFERENCES acei_jurisdiction_map(jurisdiction_region),
    sub_regional_cpe NUMERIC(6,3),
    employer_count INTEGER,
    case_count INTEGER,
    meets_activation_threshold BOOLEAN DEFAULT FALSE,
    srm_value NUMERIC(4,2) CHECK (srm_value IS NULL OR srm_value BETWEEN 0.90 AND 1.10),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_subregion_postcode ON acei_subregion_postcode_map(postcode_area);
CREATE INDEX idx_subregion_region ON acei_subregion_postcode_map(constitutional_region);

-- Seed sub-regional data from empirical analysis
INSERT INTO acei_subregion_postcode_map (postcode_area, sub_region_name, constitutional_region, sub_regional_cpe, employer_count, case_count, notes) VALUES
-- London
('EC', 'City of London', 'London', 0.171, 1148, 196, 'Financial services epicentre. Highest sub-regional CPE nationally'),
('WC', 'West Central London', 'London', 0.106, 376, 40, 'Legal sector concentration. Professional services'),
('W', 'West End & Mayfair', 'London', 0.103, 609, 63, 'Retail, hospitality, media. Employment status disputes'),
('SW', 'South West London', 'London', 0.095, 358, 34, 'Mixed commercial/residential'),
('SE', 'South East London', 'London', 0.128, 390, 50, 'Logistics and warehousing presence'),
('E', 'East London', 'London', 0.089, 1006, 90, 'Canary Wharf financial + Stratford SME base'),
('NW', 'North West London', 'London', 0.070, 201, 14, 'Residential-dominant'),
('N', 'North London', 'London', 0.022, 226, 5, 'Residential suburbs. Significantly below London average'),
-- Scotland
('G-city', 'Glasgow City Centre', 'Scotland', 0.073, 384, 28, 'Commercial centre. Broad sector mix'),
('G-outer', 'Greater Glasgow', 'Scotland', 0.026, 192, 5, 'Suburban/satellite'),
('EH', 'Edinburgh & Lothians', 'Scotland', 0.117, 291, 34, 'Financial services hub. Close to London-level intensity'),
('AB', 'Aberdeen & North East', 'Scotland', 0.014, 145, 2, 'Oil & gas dependency. Lowest Scottish sub-regional CPE'),
('DD-KY-FK', 'Central Belt East', 'Scotland', 0.534, 163, 87, 'HIGHEST sub-regional CPE in UK. Equal pay/public sector claims'),
('ML-KA', 'Central Belt South', 'Scotland', 0.032, 157, 5, 'Lanarkshire, Ayrshire. Post-industrial'),
('PA', 'Renfrewshire & Argyll', 'Scotland', 0.022, 92, 2, 'Remote and semi-rural'),
('IV-PH-DG', 'Highlands & Rural Scotland', 'Scotland', 0.079, 101, 8, 'Tourism/hospitality. Seasonal workforce'),
-- Wales
('CF', 'Cardiff & Valleys', 'Wales', 0.039, 564, 22, '55% of Welsh employers. Government, professional services'),
('SA', 'Swansea & West Wales', 'Wales', 0.047, 193, 9, 'University, NHS presence. Marginally higher CPE than Cardiff'),
('NP', 'Newport & Gwent', 'Wales', 0.019, 106, 2, 'Industrial corridor'),
('LL', 'North Wales', 'Wales', 0.019, 104, 2, 'Tourism, agriculture, small business'),
('SY', 'Mid Wales', 'Wales', 0.020, 50, 1, 'Sparse. Agricultural economy'),
('LD', 'Powys', 'Wales', 0.000, 2, 0, 'Insufficient data. Rural agricultural');

-- Add sub-region and RFVM columns to employer_master
ALTER TABLE employer_master 
  ADD COLUMN IF NOT EXISTS sub_region TEXT,
  ADD COLUMN IF NOT EXISTS rfvm_band TEXT,
  ADD COLUMN IF NOT EXISTS rfvm_value NUMERIC(4,2),
  ADD COLUMN IF NOT EXISTS jurisdiction_multiplier NUMERIC(4,2);

CREATE INDEX IF NOT EXISTS idx_employer_sub_region ON employer_master(sub_region);
CREATE INDEX IF NOT EXISTS idx_employer_rfvm ON employer_master(rfvm_band);

-- RLS
ALTER TABLE acei_jurisdiction_map ENABLE ROW LEVEL SECURITY;
ALTER TABLE acei_subregion_postcode_map ENABLE ROW LEVEL SECURITY;

CREATE POLICY anon_read_jm ON acei_jurisdiction_map FOR SELECT TO anon USING (true);
CREATE POLICY auth_all_jm ON acei_jurisdiction_map FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY service_all_jm ON acei_jurisdiction_map FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY anon_read_subregion ON acei_subregion_postcode_map FOR SELECT TO anon USING (true);
CREATE POLICY auth_all_subregion ON acei_subregion_postcode_map FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY service_all_subregion ON acei_subregion_postcode_map FOR ALL TO service_role USING (true) WITH CHECK (true);

