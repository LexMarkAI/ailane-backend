-- Migration: 20260228025512_create_jurisdiction_category_framework
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_jurisdiction_category_framework


-- ═══════════════════════════════════════════════════════════════
-- LAYER 2: JURISDICTION-AWARE CATEGORY FRAMEWORK
-- ═══════════════════════════════════════════════════════════════

-- Jurisdiction-specific regulatory categories
CREATE TABLE IF NOT EXISTS jurisdiction_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  jurisdiction_code VARCHAR(10) NOT NULL REFERENCES jurisdictions(code),
  category_number SMALLINT NOT NULL,
  category_key TEXT NOT NULL,
  category_name TEXT NOT NULL,
  description TEXT,
  governing_legislation TEXT[],
  primary_regulator TEXT,
  dmr_contribution NUMERIC(6,2),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (jurisdiction_code, category_number),
  UNIQUE (jurisdiction_code, category_key)
);

CREATE INDEX idx_jur_cat_code ON jurisdiction_categories(jurisdiction_code);

-- Cross-jurisdiction equivalence mapping
CREATE TABLE IF NOT EXISTS category_equivalence_map (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_category_id UUID NOT NULL REFERENCES jurisdiction_categories(id),
  target_category_id UUID NOT NULL REFERENCES jurisdiction_categories(id),
  equivalence_strength TEXT NOT NULL CHECK (equivalence_strength IN ('strong','moderate','weak')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Data source registry per jurisdiction
CREATE TABLE IF NOT EXISTS jurisdiction_data_sources (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  jurisdiction_code VARCHAR(10) NOT NULL REFERENCES jurisdictions(code),
  source_name TEXT NOT NULL,
  source_type TEXT NOT NULL CHECK (source_type IN ('tribunal_decisions','enforcement','legislation','statistics','court_decisions')),
  feeds_component TEXT NOT NULL CHECK (feeds_component IN ('EVI','EII','SCI')),
  base_url TEXT,
  scraper_name TEXT,
  data_status TEXT NOT NULL DEFAULT 'planned' CHECK (data_status IN ('active','planned','beta','deprecated')),
  tier TEXT NOT NULL DEFAULT 'P' CHECK (tier IN ('P','R','A')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_jur_ds_code ON jurisdiction_data_sources(jurisdiction_code);

-- ── SEED GB CATEGORIES (mirrors existing ACEI 12) ─────────────
INSERT INTO jurisdiction_categories (jurisdiction_code, category_number, category_key, category_name, governing_legislation, primary_regulator, dmr_contribution) VALUES
('GB', 1,  'unfair_dismissal',             'Unfair Dismissal',                    '{"Employment Rights Act 1996"}',                    'Employment Tribunal', 25.00),
('GB', 2,  'discrimination_harassment',     'Discrimination & Harassment',         '{"Equality Act 2010"}',                             'Employment Tribunal', 25.00),
('GB', 3,  'wages_working_time',            'Wages & Working Time',                '{"National Minimum Wage Act 1998","Working Time Regulations 1998"}', 'Employment Tribunal', 25.00),
('GB', 4,  'whistleblowing',                'Whistleblowing',                      '{"Employment Rights Act 1996 Part IVA"}',           'Employment Tribunal', 25.00),
('GB', 5,  'employment_status',             'Employment Status & Classification',  '{"Employment Rights Act 1996","IR35"}',             'Employment Tribunal', 25.00),
('GB', 6,  'redundancy_org_change',         'Redundancy & Organisational Change',  '{"Employment Rights Act 1996","TULRCA 1992"}',      'Employment Tribunal', 25.00),
('GB', 7,  'parental_family_rights',        'Parental & Family Rights',            '{"Employment Rights Act 1996","Maternity and Parental Leave Regulations 1999"}', 'Employment Tribunal', 25.00),
('GB', 8,  'trade_union_collective',        'Trade Union & Collective Rights',     '{"TULRCA 1992"}',                                   'Employment Tribunal', 25.00),
('GB', 9,  'breach_of_contract',            'Breach of Contract',                  '{"Employment Tribunals Extension of Jurisdiction Order 1994"}', 'Employment Tribunal', 25.00),
('GB', 10, 'health_safety',                 'Health & Safety',                     '{"Health and Safety at Work Act 1974"}',             'HSE / Employment Tribunal', 25.00),
('GB', 11, 'data_protection_privacy',       'Data Protection & Privacy',           '{"UK GDPR","Data Protection Act 2018"}',            'ICO / Employment Tribunal', 25.00),
('GB', 12, 'business_transfers_insolvency', 'Business Transfers & Insolvency',     '{"TUPE Regulations 2006","Insolvency Act 1986"}',   'Employment Tribunal', 25.00);

-- ── SEED IE CATEGORIES ─────────────────────────────────────────
INSERT INTO jurisdiction_categories (jurisdiction_code, category_number, category_key, category_name, governing_legislation, primary_regulator) VALUES
('IE', 1,  'unfair_dismissal',             'Unfair Dismissal',                    '{"Unfair Dismissals Acts 1977-2015"}',                       'WRC / Labour Court'),
('IE', 2,  'discrimination_harassment',     'Discrimination & Harassment',         '{"Employment Equality Acts 1998-2015","Equal Status Acts"}',  'WRC / Labour Court'),
('IE', 3,  'wages_working_time',            'Payment of Wages & Working Time',     '{"Payment of Wages Act 1991","Organisation of Working Time Act 1997","National Minimum Wage Act 2000"}', 'WRC'),
('IE', 4,  'whistleblowing',                'Protected Disclosures',               '{"Protected Disclosures Act 2014"}',                          'WRC / Labour Court'),
('IE', 5,  'employment_status',             'Employment Status',                   '{"Employment (Miscellaneous Provisions) Act 2018"}',          'WRC'),
('IE', 6,  'redundancy',                    'Redundancy',                          '{"Redundancy Payments Acts 1967-2014"}',                      'WRC'),
('IE', 7,  'parental_family_rights',        'Family Leave & Parental Rights',      '{"Maternity Protection Acts","Parental Leave Acts","Paternity Leave and Benefit Act 2016"}', 'WRC'),
('IE', 8,  'industrial_relations',          'Industrial Relations',                '{"Industrial Relations Acts 1946-2015"}',                     'WRC / Labour Court'),
('IE', 9,  'terms_of_employment',           'Terms of Employment',                 '{"Terms of Employment (Information) Acts 1994-2014"}',        'WRC'),
('IE', 10, 'health_safety',                 'Health & Safety',                     '{"Safety, Health and Welfare at Work Act 2005"}',             'HSA'),
('IE', 11, 'data_protection',               'Data Protection',                     '{"GDPR","Data Protection Act 2018"}',                         'DPC'),
('IE', 12, 'transfer_of_undertakings',      'Transfer of Undertakings',            '{"European Communities (Protection of Employees on Transfer of Undertakings) Regulations 2003"}', 'WRC');

-- ── SEED AU CATEGORIES ─────────────────────────────────────────
INSERT INTO jurisdiction_categories (jurisdiction_code, category_number, category_key, category_name, governing_legislation, primary_regulator) VALUES
('AU', 1,  'unfair_dismissal',             'Unfair Dismissal',                    '{"Fair Work Act 2009 Part 3-2"}',                     'Fair Work Commission'),
('AU', 2,  'general_protections',          'General Protections',                 '{"Fair Work Act 2009 Part 3-1"}',                     'Fair Work Commission'),
('AU', 3,  'discrimination',               'Discrimination',                      '{"Fair Work Act 2009","Age Discrimination Act 2004","Sex Discrimination Act 1984","Racial Discrimination Act 1975","Disability Discrimination Act 1992"}', 'Fair Work Commission / AHRC'),
('AU', 4,  'wages_entitlements',           'Wages & National Employment Standards','{"Fair Work Act 2009 Part 2-2"}',                     'Fair Work Ombudsman'),
('AU', 5,  'enterprise_bargaining',        'Enterprise Bargaining',               '{"Fair Work Act 2009 Part 2-4"}',                     'Fair Work Commission'),
('AU', 6,  'redundancy',                   'Redundancy & Restructuring',          '{"Fair Work Act 2009 Part 3-2 Div 11"}',              'Fair Work Commission'),
('AU', 7,  'parental_leave',               'Parental Leave & Family',             '{"Fair Work Act 2009 Part 2-2 Div 5"}',               'Fair Work Commission'),
('AU', 8,  'industrial_action',            'Industrial Action',                   '{"Fair Work Act 2009 Part 3-3"}',                     'Fair Work Commission'),
('AU', 9,  'sham_contracting',             'Sham Contracting & Employment Status','{"Fair Work Act 2009 Part 3-1 Div 6","Independent Contractors Act 2006"}', 'Fair Work Ombudsman'),
('AU', 10, 'work_health_safety',           'Work Health & Safety',                '{"Work Health and Safety Act 2011"}',                 'Safe Work Australia / State regulators'),
('AU', 11, 'privacy',                      'Privacy & Surveillance',              '{"Privacy Act 1988","Workplace Surveillance Act 2005"}', 'OAIC'),
('AU', 12, 'transfer_of_business',         'Transfer of Business',                '{"Fair Work Act 2009 Part 2-8"}',                     'Fair Work Commission'),
('AU', 13, 'whistleblowing',               'Whistleblower Protection',            '{"Corporations Act 2001 Part 9.4AAA","Public Interest Disclosure Act 2013"}', 'ASIC / Fair Work Commission');

-- ── SEED NZ CATEGORIES ─────────────────────────────────────────
INSERT INTO jurisdiction_categories (jurisdiction_code, category_number, category_key, category_name, governing_legislation, primary_regulator) VALUES
('NZ', 1,  'unjustified_dismissal',        'Unjustified Dismissal',               '{"Employment Relations Act 2000 s103"}',              'ERA / Employment Court'),
('NZ', 2,  'discrimination',               'Discrimination & Harassment',         '{"Human Rights Act 1993","Employment Relations Act 2000"}', 'ERA / HRTRT'),
('NZ', 3,  'wages_holidays',               'Wages, Holidays & Leave',             '{"Minimum Wage Act 1983","Holidays Act 2003"}',       'ERA / Labour Inspector'),
('NZ', 4,  'whistleblowing',               'Protected Disclosures',               '{"Protected Disclosures (Protection of Whistleblowers) Act 2022"}', 'ERA'),
('NZ', 5,  'employment_status',            'Employment Status & Contracting',     '{"Employment Relations Act 2000 s6"}',                'ERA'),
('NZ', 6,  'restructuring_redundancy',     'Restructuring & Redundancy',          '{"Employment Relations Act 2000 Part 6A"}',           'ERA'),
('NZ', 7,  'parental_leave',               'Parental Leave',                      '{"Parental Leave and Employment Protection Act 1987"}', 'ERA'),
('NZ', 8,  'collective_bargaining',        'Collective Bargaining',               '{"Employment Relations Act 2000 Part 5"}',            'ERA'),
('NZ', 9,  'health_safety',                'Health & Safety at Work',             '{"Health and Safety at Work Act 2015"}',              'WorkSafe NZ'),
('NZ', 10, 'privacy',                      'Privacy',                             '{"Privacy Act 2020"}',                                'Privacy Commissioner');

-- ── SEED SG CATEGORIES ─────────────────────────────────────────
INSERT INTO jurisdiction_categories (jurisdiction_code, category_number, category_key, category_name, governing_legislation, primary_regulator) VALUES
('SG', 1,  'wrongful_dismissal',           'Wrongful Dismissal',                  '{"Employment Act (Cap 91)","Employment Claims Act 2016"}', 'ECT / TADM'),
('SG', 2,  'discrimination',               'Workplace Fairness',                  '{"Workplace Fairness Legislation 2024","Tripartite Guidelines on Fair Employment Practices"}', 'TAFEP / MOM'),
('SG', 3,  'wages_salary',                 'Salary & Employment Standards',       '{"Employment Act (Cap 91) Part III"}',                'MOM / ECT'),
('SG', 4,  'workplace_safety',             'Workplace Safety & Health',           '{"Workplace Safety and Health Act (Cap 354A)"}',      'MOM WSH Division'),
('SG', 5,  'foreign_manpower',             'Foreign Manpower',                    '{"Employment of Foreign Manpower Act (Cap 91A)"}',    'MOM'),
('SG', 6,  'industrial_relations',         'Industrial Relations',                '{"Industrial Relations Act (Cap 136)"}',              'IAC / MOM'),
('SG', 7,  'maternity_childcare',          'Maternity & Childcare Leave',         '{"Child Development Co-Savings Act (Cap 38A)","Employment Act Part IX"}', 'MOM'),
('SG', 8,  'personal_data',               'Personal Data Protection',            '{"Personal Data Protection Act 2012"}',               'PDPC'),
('SG', 9,  'retirement_reemployment',      'Retirement & Re-employment',          '{"Retirement and Re-employment Act (Cap 274A)"}',     'MOM');

-- ── SEED US CATEGORIES (Federal) ───────────────────────────────
INSERT INTO jurisdiction_categories (jurisdiction_code, category_number, category_key, category_name, governing_legislation, primary_regulator) VALUES
('US', 1,  'wrongful_termination',         'Wrongful Termination',                '{"State common law","WARN Act"}',                     'State courts / DOL'),
('US', 2,  'title_vii_discrimination',     'Title VII Discrimination',            '{"Civil Rights Act 1964 Title VII"}',                 'EEOC'),
('US', 3,  'ada_disability',               'ADA Disability Discrimination',       '{"Americans with Disabilities Act 1990"}',            'EEOC'),
('US', 4,  'adea_age',                     'Age Discrimination (ADEA)',           '{"Age Discrimination in Employment Act 1967"}',       'EEOC'),
('US', 5,  'flsa_wages',                   'Wages & Hours (FLSA)',               '{"Fair Labor Standards Act 1938"}',                   'DOL WHD'),
('US', 6,  'fmla_leave',                   'Family & Medical Leave (FMLA)',      '{"Family and Medical Leave Act 1993"}',               'DOL WHD'),
('US', 7,  'osha_safety',                  'Occupational Safety (OSHA)',          '{"Occupational Safety and Health Act 1970"}',         'OSHA'),
('US', 8,  'nlra_labour',                  'Labour Relations (NLRA)',             '{"National Labor Relations Act 1935"}',               'NLRB'),
('US', 9,  'erisa_benefits',               'Employee Benefits (ERISA)',           '{"Employee Retirement Income Security Act 1974"}',    'DOL EBSA'),
('US', 10, 'whistleblower',                'Whistleblower Protections',           '{"Sarbanes-Oxley Act 2002","Dodd-Frank Act 2010"}',   'OSHA / SEC'),
('US', 11, 'immigration',                  'Employment Immigration',              '{"Immigration and Nationality Act","Form I-9"}',      'USCIS / DOJ IER'),
('US', 12, 'equal_pay',                    'Equal Pay',                           '{"Equal Pay Act 1963"}',                              'EEOC'),
('US', 13, 'retaliation',                  'Retaliation',                         '{"Title VII","ADA","ADEA","FMLA","SOX"}',             'EEOC / DOL'),
('US', 14, 'worker_classification',        'Worker Classification',               '{"IRS Guidelines","State ABC tests","DOL Rules"}',    'DOL / IRS / State agencies');

-- Enable RLS
ALTER TABLE jurisdiction_categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "jur_categories_public_read" ON jurisdiction_categories FOR SELECT USING (true);

ALTER TABLE category_equivalence_map ENABLE ROW LEVEL SECURITY;
CREATE POLICY "equiv_map_public_read" ON category_equivalence_map FOR SELECT USING (true);

ALTER TABLE jurisdiction_data_sources ENABLE ROW LEVEL SECURITY;
CREATE POLICY "jur_ds_public_read" ON jurisdiction_data_sources FOR SELECT USING (true);
