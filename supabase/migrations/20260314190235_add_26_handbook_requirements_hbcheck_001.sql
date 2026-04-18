-- Migration: 20260314190235_add_26_handbook_requirements_hbcheck_001
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: add_26_handbook_requirements_hbcheck_001

-- AILANE-CC-BRIEF-HBCHECK-001 — Handbook Requirement Library Expansion
-- Adds 26 new requirements to reach the 38-requirement target per AILANE-SPEC-CCA-001 §6.4
-- Existing 12 requirements are preserved — no duplicates
-- applies_to = 'handbook' for all new rows
-- All descriptions include severity guidance for the AI analysis engine

INSERT INTO regulatory_requirements (category, requirement_name, statutory_basis, applies_to, mandatory, jurisdiction_code, description, pillar_mapping, effective_from, version)
VALUES

-- DISCIPLINARY & GRIEVANCE — granular requirements (3 new, complementing existing disciplinary + grievance procedures)
('handbook_policies', 'Right to be accompanied at disciplinary hearing', 'Employment Relations Act 1999 s.10', 'handbook', true, 'GB',
 'The handbook must explicitly state that employees have the statutory right to be accompanied at any disciplinary hearing that could result in a formal warning or dismissal. The companion must be a trade union representative or a workplace colleague chosen by the employee. This right cannot be contracted out of. Absence of this provision is a Critical finding. A procedure that restricts the choice of companion beyond the statutory definition is deficient.',
 'SPA', CURRENT_DATE, '1.0'),

('handbook_policies', 'Right to be accompanied at grievance hearing', 'Employment Relations Act 1999 s.10', 'handbook', true, 'GB',
 'The handbook must explicitly state that employees have the statutory right to be accompanied at grievance hearings. Same statutory basis as disciplinary accompaniment — ERA 1999 s.10 applies equally to grievance hearings. Absence is a Critical finding.',
 'SPA', CURRENT_DATE, '1.0'),

('handbook_policies', 'Appeal right for disciplinary and grievance outcomes', 'ACAS Code of Practice on Disciplinary and Grievance Procedures 2015', 'handbook', true, 'GB',
 'The handbook must explicitly provide a right of appeal against both disciplinary and grievance outcomes. Appeal is a foundational element of procedural fairness under the ACAS Code. Its absence is a standard indicator of procedural unfairness in tribunal proceedings and exposes the employer to a 25% compensation uplift under TULRCA 1992 s.207A. Absence is a Critical finding.',
 'SPA', CURRENT_DATE, '1.0'),

-- EQUALITY, DIVERSITY & INCLUSION — granular requirements (3 new)
('handbook_policies', 'Harassment and bullying policy with reporting mechanism', 'Equality Act 2010 s.26; Worker Protection (Amendment of Equality Act 2010) Act 2023', 'handbook', true, 'GB',
 'A standalone or clearly identified harassment and bullying policy with a defined reporting mechanism. From October 2024 under the Worker Protection Act 2023, employers have a positive duty to take reasonable steps to prevent sexual harassment. A clear policy with reporting routes is primary evidence of compliance with this duty. Must define harassment, provide examples, and specify confidential reporting channels. Absence is a Critical finding.',
 'PA', CURRENT_DATE, '1.0'),

('handbook_policies', 'Reasonable adjustments procedure for disabled employees', 'Equality Act 2010 s.20-22', 'handbook', true, 'GB',
 'A procedure for requesting and implementing reasonable adjustments for disabled employees. The duty under Equality Act 2010 s.20 is anticipatory — the procedure must exist before a request is made. Must cover how to request adjustments, who assesses them, timescales for response, and examples of adjustments. Absence is a Critical finding.',
 'PA', CURRENT_DATE, '1.0'),

('handbook_policies', 'Pay equality statement or equal pay commitment', 'Equality Act 2010; Equal Pay Act 1970 (as preserved)', 'handbook', false, 'GB',
 'A statement of commitment to pay equality or an equal pay policy. Organisations with 250+ employees have mandatory gender pay gap reporting obligations. Even below this threshold, an equal pay commitment demonstrates good practice and supports the reasonable steps defence. Absence is a Major finding for organisations above the reporting threshold, Minor for smaller organisations.',
 'PA', CURRENT_DATE, '1.0'),

-- HEALTH, SAFETY & WELLBEING — granular requirements (3 new)
('handbook_policies', 'Accident and incident reporting procedure (RIDDOR)', 'RIDDOR 2013 (Reporting of Injuries, Diseases and Dangerous Occurrences Regulations)', 'handbook', true, 'GB',
 'A defined procedure for reporting workplace accidents and incidents, including the mechanism for internal reporting, investigation steps, and the employer obligation to notify the HSE under RIDDOR 2013 for specified injuries, diseases, and dangerous occurrences. Must cover who reports, how, and when. Absence is a Major finding.',
 'PA', CURRENT_DATE, '1.0'),

('handbook_policies', 'Mental health and wellbeing policy', 'Employer duty of care; HSE Management Standards for work-related stress', 'handbook', false, 'GB',
 'A policy addressing mental health and wellbeing in the workplace. While not a specific statutory requirement, the HSE Management Standards for work-related stress provide an authoritative framework. Increasingly expected by tribunals as evidence of the employer duty of care. Absence is a Minor finding.',
 'PA', CURRENT_DATE, '1.0'),

('handbook_policies', 'Drug and alcohol policy', 'Health and Safety at Work etc. Act 1974 s.2 (general duty); Transport and Works Act 1992 (if applicable)', 'handbook', false, 'GB',
 'A policy addressing drug and alcohol use in the workplace. Critical for safety-sensitive roles. Must balance the employer duty of care with employee privacy rights. For roles covered by the Transport and Works Act 1992, specific obligations apply. Absence is a Minor finding for general workplaces, Major for safety-critical environments.',
 'PA', CURRENT_DATE, '1.0'),

-- LEAVE ENTITLEMENTS — granular requirements (5 new, complementing existing family-friendly + flexible working + sickness)
('handbook_policies', 'Annual leave policy including holiday pay calculation', 'Working Time Regulations 1998 Reg.13-16; Brazel v Harpur Trust [2022] UKSC 27', 'handbook', true, 'GB',
 'A comprehensive annual leave policy covering the 5.6-week (28 days for full-time) statutory minimum entitlement and the method for calculating holiday pay. Following Brazel v Harpur Trust [2022] UKSC 27, percentage-based accrual for part-year workers is unlawful. Variable-hours workers must have holiday pay calculated using the 52-week reference period under WTR 1998 Reg.16. A policy that calculates at basic rate only, excluding regular overtime, is deficient. Absence is a Critical finding.',
 'PA', CURRENT_DATE, '1.0'),

('handbook_policies', 'Parental bereavement leave policy', 'Parental Bereavement (Leave and Pay) Act 2018', 'handbook', true, 'GB',
 'A policy covering the statutory right to parental bereavement leave. This is a day-one right for bereaved parents — two weeks statutory leave. Must cover eligibility (including stillbirth from 24 weeks), notice requirements, and pay entitlements (statutory parental bereavement pay). Absence is a Critical finding given the statutory basis.',
 'PA', CURRENT_DATE, '1.0'),

('handbook_policies', 'Carer''s leave policy', 'Carer''s Leave Act 2023', 'handbook', true, 'GB',
 'A policy covering the statutory right to carer''s leave. Day-one right from April 2024. One week unpaid leave per year for employees with caring responsibilities for a dependant with a long-term care need. Relatively new entitlement — many handbooks have not yet incorporated it. Absence is a Major finding.',
 'PA', CURRENT_DATE, '1.0'),

('handbook_policies', 'Time off for dependants policy', 'ERA 1996 s.57A', 'handbook', true, 'GB',
 'A policy covering the statutory right to reasonable unpaid time off to deal with emergencies involving a dependant. Day-one right. Must define what constitutes a dependant (spouse, partner, child, parent, person living in the same household, person who reasonably relies on the employee for care) and what constitutes an emergency. Absence is a Major finding.',
 'PA', CURRENT_DATE, '1.0'),

('handbook_policies', 'Jury service and public duties leave', 'ERA 1996 s.50; Juries Act 1974', 'handbook', false, 'GB',
 'A policy covering the statutory right to time off for jury service and public duties. Must clarify whether the employer pays during jury service (not a statutory requirement but common practice) and the notice procedure. Absence is a Minor finding.',
 'PA', CURRENT_DATE, '1.0'),

-- DATA PROTECTION & PRIVACY — granular requirement (1 new, complementing existing data protection + social media)
('handbook_policies', 'Employee monitoring disclosure policy', 'UK GDPR; Regulation of Investigatory Powers Act 2000; Telecommunications (Lawful Business Practice)(Interception of Communications) Regulations 2000', 'handbook', true, 'GB',
 'If the employer monitors employee communications (email, internet, phone, CCTV), the handbook must disclose this. Must cover the scope of legitimate monitoring, the lawful basis for processing under UK GDPR, employee expectations of privacy, and data retention for monitoring records. Failure to disclose monitoring may render evidence obtained inadmissible and expose the employer to RIPA and UK GDPR claims. Absence is a Major finding where monitoring is practised.',
 'PA', CURRENT_DATE, '1.0'),

-- GOVERNANCE, CONDUCT & COMPLIANCE — granular requirements (3 new)
('handbook_policies', 'Conflicts of interest policy', 'Best practice; Companies Act 2006 (directors); Bribery Act 2010 (wider)', 'handbook', false, 'GB',
 'A policy requiring employees to declare conflicts of interest and defining the process for managing them. Particularly important for organisations with public sector contracts or regulated activities. Directors have specific duties under Companies Act 2006 s.175. Absence is a Major finding.',
 'GO', CURRENT_DATE, '1.0'),

('handbook_policies', 'Confidentiality and intellectual property policy', 'Common law duty of fidelity; Copyright, Designs and Patents Act 1988', 'handbook', false, 'GB',
 'A policy setting organisational expectations for confidentiality and intellectual property. While contract-level confidentiality clauses are more legally enforceable, a handbook-level policy sets the workplace standard and supports enforcement of contractual obligations. Absence is a Minor finding.',
 'GO', CURRENT_DATE, '1.0'),

('handbook_policies', 'Right to work verification procedure', 'Immigration, Asylum and Nationality Act 2006; Immigration Act 2016', 'handbook', true, 'GB',
 'A procedure for verifying the right to work of all employees before employment begins. Employers face civil penalties of up to £45,000 per illegal worker (from February 2024). A documented right to work procedure is the primary evidence of a statutory excuse defence. Must cover when checks are conducted, what documents are acceptable, and how records are retained. Absence is a Critical finding.',
 'GO', CURRENT_DATE, '1.0'),

-- PERFORMANCE, DEVELOPMENT & WORKING ARRANGEMENTS (6 new)
('handbook_policies', 'Performance management procedure', 'ACAS guidance on managing performance; best practice', 'handbook', false, 'GB',
 'A procedure for managing employee performance including support periods, specific improvement targets, review timelines, and the linkage to capability dismissal. Not a statutory requirement, but absence significantly weakens the employer position in capability-related unfair dismissal proceedings. Absence is a Minor finding.',
 'SPA', CURRENT_DATE, '1.0'),

('handbook_policies', 'Training and development policy', 'ERA 1996 s.1(4)(da) (particulars context); best practice', 'handbook', false, 'GB',
 'A policy setting out the organisation approach to training and development. Supports RRI Training Deployment pillar evidence. Absence is a missed opportunity for demonstrating regulatory readiness rather than a legal gap. Absence is a Minor finding.',
 'TD', CURRENT_DATE, '1.0'),

('handbook_policies', 'Appraisal and review procedure', 'Best practice', 'handbook', false, 'GB',
 'A framework for regular appraisal and performance review. Provides the documentation foundation for capability management and supports fair process in performance-related dismissals. Absence is a Minor finding.',
 'SPA', CURRENT_DATE, '1.0'),

('handbook_policies', 'Redundancy procedure', 'ERA 1996 Part XI; TULRCA 1992 s.188 (collective consultation)', 'handbook', true, 'GB',
 'A redundancy procedure covering fair selection criteria, meaningful individual consultation, genuine consideration of suitable alternative employment, notice entitlements, and the right of appeal. For 20+ proposed redundancies, collective consultation obligations under TULRCA 1992 s.188 apply (protective award of up to 90 days gross pay per employee for failure). Absence is a Major finding.',
 'SPA', CURRENT_DATE, '1.0'),

('handbook_policies', 'Expenses policy', 'Best practice; HMRC compliance', 'handbook', false, 'GB',
 'A policy covering what expenses are reimbursable, the process for claiming, approval requirements, and supporting evidence needed. HMRC benchmark rates provide a reference framework for mileage, subsistence, and accommodation. Absence is a Minor finding.',
 'PA', CURRENT_DATE, '1.0'),

('handbook_policies', 'Working time and rest breaks policy', 'Working Time Regulations 1998', 'handbook', true, 'GB',
 'A policy covering working time obligations: the 48-hour weekly limit and opt-out process (WTR Reg.4-5), the 20-minute rest break entitlement per 6-hour shift (Reg.12), the 11-hour daily rest period (Reg.10), and the weekly rest period (Reg.11). Must explain the opt-out process clearly — opt-out must be voluntary, in writing, and withdrawable. Absence is a Major finding.',
 'PA', CURRENT_DATE, '1.0'),

-- ADDITIONAL SPECIALIST POLICIES (2 new)
('handbook_policies', 'Remote and homeworking policy', 'Best practice; UK GDPR (data security for remote access); HSWA 1974 (home workstation assessment)', 'handbook', false, 'GB',
 'A policy covering remote and homeworking arrangements including data security requirements for remote access, home workstation assessment obligations under HSWA 1974, equipment provision, and communication expectations. Post-pandemic expectation. If the organisation has remote workers, absence is a gap. If fully office-based, absence is noted but not flagged as a finding. Absence is a Minor finding.',
 'PA', CURRENT_DATE, '1.0'),

('handbook_policies', 'Lone working policy', 'HSWA 1974 s.2; Management of Health and Safety at Work Regulations 1999', 'handbook', true, 'GB',
 'A policy covering lone working arrangements where employees work alone or in isolation. Must cover risk assessment specific to lone working, communication protocols and check-in procedures, and emergency response arrangements. Required where any employees work alone — including cleaners, security staff, field operatives, and remote workers in isolated locations. If the organisation has no lone workers, absence is noted but not flagged. Absence is a Major finding where lone working occurs.',
 'PA', CURRENT_DATE, '1.0');

