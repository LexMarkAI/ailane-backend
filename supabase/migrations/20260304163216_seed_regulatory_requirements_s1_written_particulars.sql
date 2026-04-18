-- Migration: 20260304163216_seed_regulatory_requirements_s1_written_particulars
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: seed_regulatory_requirements_s1_written_particulars


-- =============================================================
-- COMPLIANCE CHECKER: Seed Data
-- ERA 1996 s.1 Written Statement of Particulars (Post-April 2020)
-- Category: written_particulars
-- All requirements apply to contracts, pillar mapping: CC (Contractual Conformity)
-- Constitutional basis: AILANE-CC-RRI-INT-001 v1.1 Section 3.1
-- =============================================================

INSERT INTO regulatory_requirements 
  (category, requirement_name, statutory_basis, applies_to, mandatory, jurisdiction_code, description, current_minimum, check_logic, pillar_mapping, version)
VALUES
  -- 1. Employer name
  ('written_particulars', 'Employer name', 'ERA 1996 s.1(3)', 'contract', true, 'GB',
   'The statement must include the name of the employer. Must identify the legal entity, not a trading name alone.',
   NULL,
   'Entity name present in header or parties clause. Check for registered company name or legal entity identifier.',
   'CC', '1.0'),

  -- 2. Employee name
  ('written_particulars', 'Employee name', 'ERA 1996 s.1(3)', 'contract', true, 'GB',
   'The statement must include the name of the employee. Must identify the individual or provide a clear placeholder field.',
   NULL,
   'Named individual or placeholder field present in parties clause.',
   'CC', '1.0'),

  -- 3. Date employment began
  ('written_particulars', 'Date employment began', 'ERA 1996 s.1(4)(a)', 'contract', true, 'GB',
   'The date on which the employment began. Must be a specific date, not a reference to a variable.',
   NULL,
   'Date field or commencement clause identifying a specific start date.',
   'CC', '1.0'),

  -- 4. Continuous employment date
  ('written_particulars', 'Continuous employment date', 'ERA 1996 s.1(4)(b)', 'contract', true, 'GB',
   'The date on which the employee''s period of continuous employment began, taking into account any employment with a previous employer that counts towards continuity.',
   NULL,
   'Continuity of service clause present. May be same as start date or reference prior employment.',
   'CC', '1.0'),

  -- 5. Job title or description
  ('written_particulars', 'Job title or description', 'ERA 1996 s.1(4)(f)', 'contract', true, 'GB',
   'The title of the job which the employee is employed to do or a brief description of the work.',
   NULL,
   'Role, title, or job description clause identified in the document.',
   'CC', '1.0');

-- Batch 2
INSERT INTO regulatory_requirements 
  (category, requirement_name, statutory_basis, applies_to, mandatory, jurisdiction_code, description, current_minimum, check_logic, pillar_mapping, version)
VALUES
  -- 6. Place of work
  ('written_particulars', 'Place of work', 'ERA 1996 s.1(4)(h)', 'contract', true, 'GB',
   'The place of work or, where the employee is required or permitted to work at various places, an indication of that and of the address of the employer.',
   NULL,
   'Location, workplace, or mobility clause present. If multiple locations, must indicate principal place or mobility requirement.',
   'CC', '1.0'),

  -- 7. Pay and intervals
  ('written_particulars', 'Pay and intervals', 'ERA 1996 s.1(4)(a)', 'contract', true, 'GB',
   'The scale or rate of remuneration or the method of calculating remuneration, and the intervals at which remuneration is paid (weekly, monthly, etc.).',
   NULL,
   'Remuneration clause present with specified amount or calculation method AND payment frequency (weekly, monthly, etc.).',
   'CC', '1.0'),

  -- 8. Hours of work
  ('written_particulars', 'Hours of work', 'ERA 1996 s.1(4)(c)', 'contract', true, 'GB',
   'Any terms and conditions relating to hours of work including any relating to normal working hours.',
   NULL,
   'Working hours or working pattern clause present. Should specify normal hours per week/day.',
   'CC', '1.0'),

  -- 9. Holiday entitlement
  ('written_particulars', 'Holiday entitlement and calculation', 'ERA 1996 s.1(4)(d)(i)', 'contract', true, 'GB',
   'Any terms and conditions relating to entitlement to holidays, including public holidays, and holiday pay, sufficient to enable the entitlement including any entitlement to accrued holiday pay on termination to be precisely calculated.',
   '5.6 weeks (28 days) pro rata for full-time under WTR 1998 reg.13',
   'Holiday clause present with entitlement specified. Check: entitlement >= 5.6 weeks pro rata for stated working pattern. Flag if "inclusive of bank holidays" results in < 28 days.',
   'CC', '1.0'),

  -- 10. Sick pay and absence
  ('written_particulars', 'Sick pay and absence', 'ERA 1996 s.1(4)(d)(ii)', 'contract', true, 'GB',
   'Any terms and conditions relating to incapacity for work due to sickness or injury, including any provision for sick pay.',
   'SSP at statutory rate as minimum',
   'Sickness absence clause present. Should reference sick pay entitlement (SSP minimum or enhanced) and notification procedures.',
   'CC', '1.0');

-- Batch 3
INSERT INTO regulatory_requirements 
  (category, requirement_name, statutory_basis, applies_to, mandatory, jurisdiction_code, description, current_minimum, check_logic, pillar_mapping, version)
VALUES
  -- 11. Pension arrangements
  ('written_particulars', 'Pension arrangements', 'ERA 1996 s.1(4)(d)(iii)', 'contract', true, 'GB',
   'Any terms and conditions relating to pensions and pension schemes. Must reference auto-enrolment obligations under the Pensions Act 2008.',
   'Auto-enrolment: 8% total (5% employee + 3% employer) minimum',
   'Pension or auto-enrolment clause present. Should reference the pension scheme and auto-enrolment compliance.',
   'CC', '1.0'),

  -- 12. Notice periods
  ('written_particulars', 'Notice periods', 'ERA 1996 s.1(4)(e)', 'contract', true, 'GB',
   'The length of notice which the employee is obliged to give and entitled to receive to terminate the contract of employment.',
   'Statutory minimum: 1 week per year of service (up to 12 weeks) under ERA s.86',
   'Notice clause present with specified periods for both employer and employee. Check: notice >= statutory minimum for stated/assumed length of service.',
   'CC', '1.0'),

  -- 13. Expected duration (if not permanent)
  ('written_particulars', 'Expected duration (if not permanent)', 'ERA 1996 s.1(4)(g)', 'contract', false, 'GB',
   'Where the employment is not intended to be permanent, the period for which it is expected to continue or, if it is for a fixed term, the date when it is to end.',
   NULL,
   'If contract is fixed-term or temporary: term/duration clause must be present with end date or expected duration. Not required for permanent contracts.',
   'CC', '1.0'),

  -- 14. Collective agreements
  ('written_particulars', 'Collective agreements', 'ERA 1996 s.1(4)(j)', 'contract', true, 'GB',
   'Any collective agreements which directly affect the terms and conditions of the employment, including the identity of the parties by whom they were made.',
   NULL,
   'Collective bargaining reference present, OR explicit statement that no collective agreements apply. Absence of any reference is non-compliant.',
   'CC', '1.0'),

  -- 15. Training entitlement (post-April 2020)
  ('written_particulars', 'Training entitlement', 'ERA 1996 s.1(4)(da)', 'contract', true, 'GB',
   'Any training entitlement provided by the employer. Added by the Employment Rights (Employment Particulars and Paid Annual Leave) (Amendment) Regulations 2018, effective from 6 April 2020.',
   NULL,
   'Training or development clause present. Must describe any mandatory training or training entitlements provided by the employer, or state that none are provided.',
   'TD', '1.0');

-- Batch 4
INSERT INTO regulatory_requirements 
  (category, requirement_name, statutory_basis, applies_to, mandatory, jurisdiction_code, description, current_minimum, check_logic, pillar_mapping, version)
VALUES
  -- 16. Disciplinary and grievance procedures
  ('written_particulars', 'Disciplinary and grievance procedures', 'ERA 1996 s.1(4)(k)', 'contract', true, 'GB',
   'A note specifying any disciplinary rules applicable to the employee, and specifying a person to whom the employee can apply for the purposes of seeking redress of any grievance or any disciplinary decision.',
   'Must reference ACAS Code of Practice on Disciplinary and Grievance Procedures',
   'D&G procedure clause present, OR reference to handbook containing procedures. Must identify a person or role for grievance applications. Cross-reference ACAS Code compliance.',
   'SPA', '1.0'),

  -- 17. Probationary period (post-April 2020)
  ('written_particulars', 'Probationary period', 'ERA 1996 s.1(4)(da)', 'contract', true, 'GB',
   'Any probationary period, including conditions and duration. Added by the same 2018 Amendment Regulations, effective from 6 April 2020.',
   NULL,
   'Probation clause present with specified duration and conditions (e.g., notice during probation, extension provisions). If no probationary period applies, should be explicitly stated.',
   'CC', '1.0');

-- =============================================================
-- HANDBOOK-SPECIFIC REQUIREMENTS
-- Category: handbook_policies
-- These map primarily to PA (Policy Alignment) pillar
-- =============================================================

INSERT INTO regulatory_requirements 
  (category, requirement_name, statutory_basis, applies_to, mandatory, jurisdiction_code, description, current_minimum, check_logic, pillar_mapping, version)
VALUES
  ('handbook_policies', 'Equal opportunities and anti-discrimination policy', 'Equality Act 2010', 'handbook', true, 'GB',
   'Policy covering all protected characteristics under the Equality Act 2010. Should address direct and indirect discrimination, harassment, and victimisation.',
   NULL,
   'Equal opportunities or anti-discrimination policy present. Should reference protected characteristics and outline reporting procedures.',
   'PA', '1.0'),

  ('handbook_policies', 'Disciplinary procedure (ACAS Code compliant)', 'Employment Relations Act 1999 s.10; ACAS Code of Practice', 'handbook', true, 'GB',
   'Written disciplinary procedure compliant with the ACAS Code of Practice. Tribunal uplift of up to 25% for unreasonable failure to comply (TULRCA 1992 s.207A).',
   'Must comply with ACAS Code of Practice on Disciplinary and Grievance Procedures',
   'Disciplinary procedure present. Check for: investigation stage, right to be accompanied (ERel A 1999 s.10), written notification, appeal mechanism. ACAS Code compliance.',
   'SPA', '1.0'),

  ('handbook_policies', 'Grievance procedure (ACAS Code compliant)', 'Employment Relations Act 1999 s.10; ACAS Code of Practice', 'handbook', true, 'GB',
   'Written grievance procedure compliant with the ACAS Code of Practice. Same 25% tribunal uplift risk for non-compliance.',
   'Must comply with ACAS Code of Practice on Disciplinary and Grievance Procedures',
   'Grievance procedure present. Check for: submission process, right to be accompanied, investigation, response timescales, appeal mechanism.',
   'SPA', '1.0');

-- Batch 5: More handbook requirements
INSERT INTO regulatory_requirements 
  (category, requirement_name, statutory_basis, applies_to, mandatory, jurisdiction_code, description, current_minimum, check_logic, pillar_mapping, version)
VALUES
  ('handbook_policies', 'Absence management and sick pay', 'ERA 1996 s.1(4)(d)(ii); SSP Regs', 'handbook', true, 'GB',
   'Detailed absence management procedure including notification requirements, return to work processes, and long-term sickness handling.',
   NULL,
   'Absence management policy present with notification procedure, fit note requirements, return to work process.',
   'PA', '1.0'),

  ('handbook_policies', 'Family-friendly policies', 'ERA 1996 Part VIII; Maternity and Parental Leave Regulations 1999', 'handbook', true, 'GB',
   'Policies covering maternity, paternity, shared parental leave, adoption leave, parental bereavement leave, and dependants leave.',
   'Statutory minimums for each leave type',
   'Family-friendly policies present covering maternity, paternity, shared parental leave at minimum. Check entitlements meet statutory minimums.',
   'PA', '1.0'),

  ('handbook_policies', 'Flexible working request procedure', 'ERA 1996 s.80F (as amended by Employment Relations (Flexible Working) Act 2023)', 'handbook', true, 'GB',
   'Procedure for handling flexible working requests. From April 2024, employees have the right to request flexible working from day one (no 26-week qualifying period).',
   'Day-one right; employer must respond within 2 months; may make 2 requests per 12 months',
   'Flexible working policy present. Check: references day-one right, response timescale, statutory grounds for refusal.',
   'PA', '1.0'),

  ('handbook_policies', 'Health and safety obligations', 'Health and Safety at Work Act 1974; Management of H&S at Work Regulations 1999', 'handbook', true, 'GB',
   'Health and safety policy statement. Employers with 5+ employees must have a written H&S policy.',
   'Written policy required for 5+ employees (HSWA 1974 s.2(3))',
   'Health and safety policy present. Should include general statement, organisational responsibilities, and arrangements.',
   'PA', '1.0'),

  ('handbook_policies', 'Data protection and privacy notice', 'UK GDPR; Data Protection Act 2018', 'handbook', true, 'GB',
   'Employee data processing policy and privacy notice. Must explain lawful basis for processing employee personal data, retention periods, and data subject rights.',
   'Must comply with UK GDPR Art. 13/14 information requirements',
   'Data protection policy and employee privacy notice present. Check for: lawful basis, categories of data, retention periods, data subject rights, SAR procedure.',
   'PA', '1.0');

-- Batch 6: Final handbook requirements
INSERT INTO regulatory_requirements 
  (category, requirement_name, statutory_basis, applies_to, mandatory, jurisdiction_code, description, current_minimum, check_logic, pillar_mapping, version)
VALUES
  ('handbook_policies', 'Whistleblowing procedure', 'ERA 1996 Part IVA; Public Interest Disclosure Act 1998', 'handbook', true, 'GB',
   'Protected disclosure (whistleblowing) procedure. While not strictly mandatory, absence significantly increases tribunal exposure (ACEI Category 4: uncapped compensation).',
   NULL,
   'Whistleblowing or protected disclosure policy present. Should identify qualifying disclosures, reporting channels, and protection against detriment.',
   'PA', '1.0'),

  ('handbook_policies', 'Social media and IT acceptable use', 'Common law duty of mutual trust; UK GDPR (monitoring)', 'handbook', false, 'GB',
   'Policy governing use of IT systems, social media, and monitoring. Recommended best practice; absence may weaken employer position in misconduct proceedings.',
   NULL,
   'IT acceptable use or social media policy present. Should address personal use, monitoring disclosure, and consequences of misuse.',
   'PA', '1.0'),

  ('handbook_policies', 'Anti-bribery statement', 'Bribery Act 2010 s.7', 'handbook', false, 'GB',
   'Anti-bribery policy. Commercial organisations have a defence under Bribery Act s.7 if they can show adequate procedures. Policy is a key component of that defence.',
   NULL,
   'Anti-bribery policy or statement present. Should reference Bribery Act 2010 and outline prohibited conduct.',
   'GO', '1.0'),

  ('handbook_policies', 'Modern slavery statement', 'Modern Slavery Act 2015 s.54', 'handbook', false, 'GB',
   'Modern slavery statement. Required for organisations with turnover >= £36m. Recommended best practice for all organisations in supply chains.',
   'Mandatory for turnover >= £36m (MSA 2015 s.54)',
   'Modern slavery statement present if applicable. Check: annual statement, board approval, supply chain due diligence.',
   'GO', '1.0');

