// AILANE-CC-BRIEF-HBCHECK-001 — Contract Requirement Library
// Source: AILANE-SPEC-CCA-001 v1.0, §6.3
// Existing library — verified, not rewritten
// DO NOT modify without AIC approval

export interface ContractRequirement {
  id: string;
  domain: string;
  requirement: string;
  standard: string;
  severity_if_absent: 'Critical' | 'Major' | 'Minor';
  severity_if_deficient: 'Critical' | 'Major' | 'Minor';
  notes: string;
}

export const CONTRACT_REQUIREMENTS: ContractRequirement[] = [
  {
    id: 'CT-01',
    domain: 'Written Statement of Particulars',
    requirement: 'Names of employer and employee, date employment began, and date continuous employment began',
    standard: 'ERA 1996 s.1(3)–(4)',
    severity_if_absent: 'Critical',
    severity_if_deficient: 'Major',
    notes: 'Must be provided from day one of employment (from April 2020). Omission exposes employer to 2–4 weeks pay award under s.38 Employment Act 2002'
  },
  {
    id: 'CT-02',
    domain: 'Written Statement of Particulars',
    requirement: 'Job title or description of work, place of work, and any requirement to work outside the UK',
    standard: 'ERA 1996 s.1(4)(f)–(h)',
    severity_if_absent: 'Critical',
    severity_if_deficient: 'Major',
    notes: 'Place of work clause must indicate whether the employee is required or permitted to work at various locations'
  },
  {
    id: 'CT-03',
    domain: 'Pay & Wages',
    requirement: 'Scale or rate of remuneration, method of calculation, and pay intervals',
    standard: 'ERA 1996 s.1(4)(a)–(b); National Minimum Wage Act 1998',
    severity_if_absent: 'Critical',
    severity_if_deficient: 'Major',
    notes: 'Must be at or above NMW/NLW for the relevant age band. If salary is stated, verify it meets the minimum for contracted hours'
  },
  {
    id: 'CT-04',
    domain: 'Hours & Working Time',
    requirement: 'Normal working hours, days of the week, and whether hours may vary',
    standard: 'ERA 1996 s.1(4)(c); Working Time Regulations 1998',
    severity_if_absent: 'Major',
    severity_if_deficient: 'Minor',
    notes: 'If the contract permits more than 48 hours per week, a valid opt-out under WTR Reg.5 must be referenced'
  },
  {
    id: 'CT-05',
    domain: 'Hours & Working Time',
    requirement: 'Working Time Regulations opt-out (if applicable)',
    standard: 'Working Time Regulations 1998 Reg.4–5',
    severity_if_absent: 'Critical',
    severity_if_deficient: 'Major',
    notes: 'Opt-out must be voluntary, in writing, and the worker must be able to withdraw with 7 days notice (or up to 3 months if agreed). A blanket opt-out buried in contract terms may not be valid'
  },
  {
    id: 'CT-06',
    domain: 'Holiday',
    requirement: 'Holiday entitlement including public holidays, and holiday pay calculation basis',
    standard: 'Working Time Regulations 1998 Reg.13–16; Brazel v Harpur Trust [2022] UKSC 27',
    severity_if_absent: 'Critical',
    severity_if_deficient: 'Critical',
    notes: 'Minimum 5.6 weeks (28 days for full-time). Holiday pay for variable-hours workers must use 52-week reference period averaging. Post-Brazel, percentage-based accrual is unlawful for part-year workers'
  },
  {
    id: 'CT-07',
    domain: 'Notice & Termination',
    requirement: 'Notice period required from employer and employee, or reference to statutory minimums',
    standard: 'ERA 1996 s.86',
    severity_if_absent: 'Critical',
    severity_if_deficient: 'Major',
    notes: 'Statutory minimum: 1 week after 1 month service, rising to 1 week per year of service up to 12 weeks maximum. Contract may exceed but not undercut statutory minimum'
  },
  {
    id: 'CT-08',
    domain: 'Sick Pay',
    requirement: 'Sickness absence notification requirements and sick pay provisions (SSP or enhanced)',
    standard: 'Social Security Contributions and Benefits Act 1992; SSP General Regulations',
    severity_if_absent: 'Major',
    severity_if_deficient: 'Minor',
    notes: 'ERA 1996 s.1(4)(d)(ii) requires written statement to include terms relating to incapacity for work including sick pay'
  },
  {
    id: 'CT-09',
    domain: 'Pension',
    requirement: 'Pension arrangements or reference to auto-enrolment obligations',
    standard: 'Pensions Act 2008 (auto-enrolment); ERA 1996 s.1(4)(d)(iii)',
    severity_if_absent: 'Major',
    severity_if_deficient: 'Minor',
    notes: 'All employers must auto-enrol eligible workers. Contract should reference pension scheme or state that auto-enrolment applies'
  },
  {
    id: 'CT-10',
    domain: 'Disciplinary & Grievance',
    requirement: 'Reference to disciplinary and grievance procedures (or statement that ACAS Code applies)',
    standard: 'ERA 1996 s.1(4)(j); ACAS Code of Practice 2015',
    severity_if_absent: 'Critical',
    severity_if_deficient: 'Major',
    notes: 'Required in the written statement from day one. Must either incorporate or reference where the full procedure can be found'
  },
  {
    id: 'CT-11',
    domain: 'Flexible Working',
    requirement: 'Flexible working provisions reflecting current statutory position',
    standard: 'Employment Relations (Flexible Working) Act 2023; ERA 1996 s.80F',
    severity_if_absent: 'Major',
    severity_if_deficient: 'Major',
    notes: 'Day-one right from April 2024. If the contract references a 26-week qualifying period, it is outdated and should be flagged'
  },
  {
    id: 'CT-12',
    domain: 'Data Protection',
    requirement: 'Data protection clause or reference to employee privacy notice',
    standard: 'UK GDPR 2021; Data Protection Act 2018',
    severity_if_absent: 'Major',
    severity_if_deficient: 'Minor',
    notes: 'Must reference UK GDPR specifically (not EU GDPR, as UK has diverged post-Brexit). Should cover lawful basis for processing employee data'
  },
  {
    id: 'CT-13',
    domain: 'Unlawful Deductions',
    requirement: 'Any deduction clause must meet the prior written consent requirement',
    standard: 'ERA 1996 s.13',
    severity_if_absent: 'Minor',
    severity_if_deficient: 'Critical',
    notes: 'If a deduction clause exists, it must comply with s.13(1)(b) — prior written agreement before the deduction event. A clause authorising deductions without this is void. If no deduction clause exists, this is not a gap — it is the absence of risk'
  },
];
