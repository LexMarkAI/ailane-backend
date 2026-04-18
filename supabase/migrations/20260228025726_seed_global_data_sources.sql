-- Migration: 20260228025726_seed_global_data_sources
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: seed_global_data_sources


-- ═══════════════════════════════════════════════════════════════
-- GLOBAL DATA SOURCE REGISTRY
-- ═══════════════════════════════════════════════════════════════

INSERT INTO jurisdiction_data_sources (jurisdiction_code, source_name, source_type, feeds_component, base_url, scraper_name, data_status, notes) VALUES
-- GB (existing, mark active)
('GB', 'GOV.UK Employment Tribunal Decisions',  'tribunal_decisions', 'EVI', 'https://www.gov.uk/employment-tribunal-decisions',         'scrape_govuk_tribunals.py',    'active', 'Operational. 2001+ decisions.'),
('GB', 'legislation.gov.uk',                    'legislation',        'SCI', 'https://www.legislation.gov.uk/',                          'scrape_legislation.py',        'active', 'Atom API. 274+ records.'),
('GB', 'EHRC Enforcement Actions',              'enforcement',        'EII', 'https://www.equalityhumanrights.com/our-work/our-legal-action', 'scrape_ehrc.py',          'active', 'HTML scraper.'),
('GB', 'HSE Enforcement Notices',               'enforcement',        'EII', 'https://resources.hse.gov.uk/notices/',                    'scrape_hse.py',               'planned', 'Retry Monday.'),
('GB', 'ICO Enforcement Actions',               'enforcement',        'EII', 'https://ico.org.uk/action-weve-taken/enforcement/',         'scrape_ico.py',               'planned', 'Retry Monday.'),
('GB', 'HMCTS Tribunal Statistics',             'statistics',         'EVI', 'https://www.gov.uk/government/collections/tribunals-statistics', 'scrape_hmcts_stats.py',  'planned', 'Quarterly CSV/ODS downloads.'),

-- IRELAND
('IE', 'WRC Adjudication Decisions',            'tribunal_decisions', 'EVI', 'https://www.workplacerelations.ie/en/cases/',              'scrape_ie_wrc.py',            'planned', 'WRC publishes decisions as PDFs/HTML. Searchable.'),
('IE', 'Labour Court Determinations',           'tribunal_decisions', 'EVI', 'https://www.labourcourt.ie/en/cases/',                     'scrape_ie_labour_court.py',   'planned', 'Determinations and recommendations.'),
('IE', 'Irish Statute Book',                    'legislation',        'SCI', 'https://www.irishstatutebook.ie/',                         'scrape_ie_legislation.py',    'planned', 'Acts and SIs. XML/HTML available.'),
('IE', 'HSA Enforcement',                       'enforcement',        'EII', 'https://www.hsa.ie/',                                     'scrape_ie_hsa.py',            'planned', 'Health & Safety Authority enforcement register.'),

-- AUSTRALIA
('AU', 'Fair Work Commission Decisions',        'tribunal_decisions', 'EVI', 'https://www.fwc.gov.au/cases-decisions-orders',            'scrape_au_fwc.py',            'planned', 'Decision search with RSS/Atom feeds available.'),
('AU', 'Fair Work Ombudsman Enforcement',       'enforcement',        'EII', 'https://www.fairwork.gov.au/about-us/our-role/enforcing-the-legislation', 'scrape_au_fwo.py', 'planned', 'Litigation register + compliance results.'),
('AU', 'Federal Register of Legislation',       'legislation',        'SCI', 'https://www.legislation.gov.au/',                          'scrape_au_legislation.py',    'planned', 'API available. Acts and subordinate legislation.'),
('AU', 'Safe Work Australia Notices',            'enforcement',        'EII', 'https://www.safeworkaustralia.gov.au/',                    'scrape_au_swa.py',            'planned', 'WHS enforcement data.'),

-- NEW ZEALAND
('NZ', 'ERA Determinations',                    'tribunal_decisions', 'EVI', 'https://www.era.govt.nz/determinations/',                  'scrape_nz_era.py',            'planned', 'Employment Relations Authority decisions.'),
('NZ', 'Employment Court Judgments',             'court_decisions',    'EVI', 'https://www.employmentcourt.govt.nz/judgments/',           'scrape_nz_empcourt.py',       'planned', 'Full text judgments.'),
('NZ', 'NZ Legislation',                        'legislation',        'SCI', 'https://www.legislation.govt.nz/',                         'scrape_nz_legislation.py',    'planned', 'API available. Acts and regulations.'),
('NZ', 'WorkSafe NZ Enforcement',               'enforcement',        'EII', 'https://www.worksafe.govt.nz/',                           'scrape_nz_worksafe.py',       'planned', 'Prosecutions and enforcement actions.'),

-- SINGAPORE
('SG', 'MOM Statistics & Publications',          'statistics',         'EVI', 'https://www.mom.gov.sg/newsroom',                         'scrape_sg_mom.py',            'planned', 'Employment standards, workplace safety stats.'),
('SG', 'Singapore Statutes Online',              'legislation',        'SCI', 'https://sso.agc.gov.sg/',                                 'scrape_sg_legislation.py',    'planned', 'All Singapore statutes. Structured HTML.'),
('SG', 'PDPC Enforcement Decisions',             'enforcement',        'EII', 'https://www.pdpc.gov.sg/all-commissions-decisions',       'scrape_sg_pdpc.py',           'planned', 'Data protection enforcement. Structured page.'),
('SG', 'WSH Enforcement',                        'enforcement',        'EII', 'https://www.mom.gov.sg/workplace-safety-and-health',      'scrape_sg_wsh.py',            'planned', 'MOM WSH prosecutions and penalties.'),

-- US FEDERAL (Tier 1)
('US', 'EEOC Litigation',                        'enforcement',        'EII', 'https://www.eeoc.gov/litigation',                         'scrape_us_eeoc.py',           'planned', 'Searchable press releases and case data.'),
('US', 'OSHA Enforcement',                       'enforcement',        'EII', 'https://www.osha.gov/enforcement',                        'scrape_us_osha.py',           'planned', 'Inspections and citations database. API available.'),
('US', 'DOL WHD Enforcement',                    'enforcement',        'EII', 'https://enforcedata.dol.gov/',                            'scrape_us_dol.py',            'planned', 'Enforcement data API. FLSA/FMLA violations.'),
('US', 'NLRB Decisions',                         'tribunal_decisions', 'EVI', 'https://www.nlrb.gov/cases-decisions/decisions',           'scrape_us_nlrb.py',           'planned', 'Board decisions searchable.'),
('US', 'Federal Register',                       'legislation',        'SCI', 'https://www.federalregister.gov/api/v1/',                 'scrape_us_fedregister.py',    'planned', 'Full REST API. Employment-related rules.'),
('US', 'EEOC Charge Statistics',                  'statistics',         'EVI', 'https://www.eeoc.gov/data/charge-statistics',             'scrape_us_eeoc_stats.py',     'planned', 'Annual charge data by basis and issue.'),

-- CANADA
('CA', 'CanLII Employment Cases',                'tribunal_decisions', 'EVI', 'https://www.canlii.org/en/',                              'scrape_ca_canlii.py',         'planned', 'Comprehensive case law database.'),
('CA', 'Canada Labour Code Legislation',         'legislation',        'SCI', 'https://laws-lois.justice.gc.ca/',                        'scrape_ca_legislation.py',    'planned', 'Justice Laws Website. XML API.'),
('CA', 'CIRB Decisions',                          'tribunal_decisions', 'EVI', 'https://www.cirb-ccri.gc.ca/',                           'scrape_ca_cirb.py',           'planned', 'Canada Industrial Relations Board.'),

-- EU / EUROPE
('DE', 'BAG Federal Labour Court',               'court_decisions',    'EVI', 'https://www.bundesarbeitsgericht.de/',                    'scrape_de_bag.py',            'planned', 'German Federal Labour Court decisions.'),
('FR', 'Legifrance Labour Code',                 'legislation',        'SCI', 'https://www.legifrance.gouv.fr/',                         'scrape_fr_legifrance.py',     'planned', 'French legislation database. API available.'),
('NL', 'Rechtspraak Employment Cases',           'court_decisions',    'EVI', 'https://www.rechtspraak.nl/',                             'scrape_nl_rechtspraak.py',    'planned', 'Dutch court decisions. Open data API.'),

-- HONG KONG
('HK', 'Labour Tribunal Judgments',              'tribunal_decisions', 'EVI', 'https://legalref.judiciary.hk/',                          'scrape_hk_judiciary.py',      'planned', 'HKLII / Judiciary decisions.'),
('HK', 'HK e-Legislation',                       'legislation',        'SCI', 'https://www.elegislation.gov.hk/',                        'scrape_hk_legislation.py',    'planned', 'Hong Kong e-Legislation. Cap. 57 Employment Ordinance.'),

-- INDIA
('IN', 'Indian Kanoon Labour Cases',             'court_decisions',    'EVI', 'https://indiankanoon.org/',                               'scrape_in_kanoon.py',         'planned', 'Comprehensive case law search.'),
('IN', 'Labour Ministry Notifications',          'legislation',        'SCI', 'https://labour.gov.in/',                                  'scrape_in_labour.py',         'planned', 'Central labour legislation and notifications.'),

-- UAE
('AE', 'MOHRE Decisions',                        'enforcement',        'EII', 'https://www.mohre.gov.ae/',                               'scrape_ae_mohre.py',          'planned', 'Ministry of Human Resources. Limited public data.'),
('AE', 'DIFC Courts Judgments',                  'court_decisions',    'EVI', 'https://www.difccourts.ae/rules-decisions/judgments',      'scrape_ae_difc.py',           'planned', 'DIFC employment disputes. Public judgments.'),

-- SOUTH AFRICA
('ZA', 'CCMA Awards',                            'tribunal_decisions', 'EVI', 'https://www.ccma.org.za/',                                'scrape_za_ccma.py',           'planned', 'Arbitration awards database.'),
('ZA', 'Labour Court Judgments',                  'court_decisions',    'EVI', 'https://www.saflii.org/',                                 'scrape_za_saflii.py',         'planned', 'SAFLII Labour Court decisions.'),
('ZA', 'SA Government Gazette',                   'legislation',        'SCI', 'https://www.gov.za/documents/acts',                      'scrape_za_legislation.py',    'planned', 'Labour legislation amendments.'),

-- KENYA
('KE', 'Kenya Law Reports',                      'court_decisions',    'EVI', 'http://kenyalaw.org/',                                    'scrape_ke_kenyalaw.py',       'planned', 'ELRC and court decisions.'),

-- NIGERIA
('NG', 'Nigerian Industrial Court',              'court_decisions',    'EVI', 'https://nicn.gov.ng/',                                    'scrape_ng_nicn.py',           'planned', 'National Industrial Court judgments.'),

-- JAPAN
('JP', 'Courts Japan Labour Cases',              'court_decisions',    'EVI', 'https://www.courts.go.jp/',                               'scrape_jp_courts.py',         'planned', 'Supreme Court and lower court decisions. Japanese language.');

