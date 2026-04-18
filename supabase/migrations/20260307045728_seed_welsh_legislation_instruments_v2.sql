-- Migration: 20260307045728_seed_welsh_legislation_instruments_v2
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: seed_welsh_legislation_instruments_v2


INSERT INTO legislation_library (
  legislation_ref, short_title, title_cy, legislation_type, lifecycle_stage,
  jurisdiction_codes, welsh_available, translation_method,
  royal_assent_date, commencement_date,
  summary, summary_cy,
  obligations_summary, obligations_cy,
  key_provisions, key_provisions_cy,
  acei_categories, primary_acei_category,
  sci_significance, tier_access,
  legislation_gov_url, tags
) VALUES

-- 1. Social Partnership and Public Procurement (Wales) Act 2023
(
  'asc/2023/34/enacted',
  'Social Partnership and Public Procurement (Wales) Act 2023',
  'Deddf Partneriaeth Gymdeithasol a Chaffael Cyhoeddus (Cymru) 2023',
  'primary', 'in_force', ARRAY['Wales'], TRUE, 'official_bilingual',
  '2023-06-26', '2023-06-26',
  'Establishes a statutory Social Partnership Council for Wales and embeds fair work obligations into Welsh public procurement. Welsh public bodies must apply socially responsible employment practices when awarding contracts. Creates enforceable duties with no equivalent in England.',
  'Mae''r Ddeddf hon yn sefydlu Cyngor Partneriaeth Gymdeithasol statudol ar gyfer Cymru ac yn ymgorffori rhwymedigaethau gwaith teg i mewn i gaffael cyhoeddus Cymreig. Rhaid i gyrff cyhoeddus Cymreig gymhwyso arferion cyflogaeth cyfrifol yn gymdeithasol wrth ddyfarnu contractau.',
  'Welsh public bodies must: (1) seek to promote fair work practices in procurement; (2) consult the Social Partnership Council on relevant workforce matters; (3) report on socially responsible procurement outcomes annually. Private contractors bidding for Welsh public contracts must evidence fair work compliance.',
  'Rhaid i gyrff cyhoeddus Cymreig: (1) geisio hyrwyddo arferion gwaith teg mewn caffael; (2) ymgynghori â''r Cyngor Partneriaeth Gymdeithasol ar faterion gweithlu perthnasol; (3) adrodd ar ganlyniadau caffael cyfrifol yn gymdeithasol yn flynyddol.',
  'Section 3: Duty to promote social partnership. Section 8: Public procurement fair work requirements. Section 12: Social Partnership Council composition. Section 19: Reporting obligations for contracting authorities.',
  'Adran 3: Dyletswydd i hyrwyddo partneriaeth gymdeithasol. Adran 8: Gofynion gwaith teg caffael cyhoeddus. Adran 12: Cyfansoddiad y Cyngor Partneriaeth Gymdeithasol. Adran 19: Rhwymedigaethau adrodd.',
  ARRAY[1, 3], 1, 5, 'governance',
  'https://www.legislation.gov.uk/asc/2023/34/enacted',
  ARRAY['wales','social_partnership','procurement','fair_work','welsh_specific','bilingual']
),

-- 2. Welsh Language (Wales) Measure 2011
(
  'mwa/2011/1',
  'Welsh Language (Wales) Measure 2011',
  'Mesur y Gymraeg (Cymru) 2011',
  'primary', 'in_force', ARRAY['Wales'], TRUE, 'official_bilingual',
  '2011-02-09', '2012-04-01',
  'Establishes Welsh as an official language of Wales with equal standing to English. Creates Welsh Language Standards enforceable against public bodies. Employment obligations include Welsh language services to staff and the public, impact assessments, and ensuring Welsh speakers are not treated less favourably in employment.',
  'Mae''r Mesur hwn yn sefydlu''r Gymraeg fel iaith swyddogol Cymru â statws cyfartal â''r Saesneg. Mae''n creu Safonau Iaith Gymraeg sy''n orfodadwy yn erbyn cyrff cyhoeddus. Mae rhwymedigaethau cyflogaeth yn cynnwys darparu gwasanaethau Cymraeg i staff a''r cyhoedd.',
  'Organisations subject to Standards must: (1) provide Welsh language services to employees and the public; (2) conduct Welsh language impact assessments; (3) publish Welsh language schemes or comply with Standards; (4) not treat Welsh less favourably than English in employment decisions. Enforceable by the Welsh Language Commissioner.',
  'Rhaid i sefydliadau sy''n ddarostyngedig i Safonau: (1) ddarparu gwasanaethau Cymraeg i weithwyr a''r cyhoedd; (2) gynnal asesiadau effaith iaith Gymraeg; (3) gyhoeddi cynlluniau iaith Gymraeg; (4) beidio â thrin y Gymraeg yn llai ffafriol na''r Saesneg mewn cyflogaeth.',
  'Section 1: Welsh language official status. Section 26: Welsh Language Standards framework. Section 44: Welsh Language Commissioner enforcement powers. Schedule 6: Sectors subject to Standards obligations.',
  'Adran 1: Statws swyddogol y Gymraeg. Adran 26: Fframwaith Safonau''r Gymraeg. Adran 44: Pwerau gorfodi Comisiynydd y Gymraeg. Atodlen 6: Sectorau sy''n ddarostyngedig i rwymedigaethau Safonau.',
  ARRAY[2, 1], 2, 5, 'governance',
  'https://www.legislation.gov.uk/mwa/2011/1',
  ARRAY['wales','welsh_language','cymraeg','standards','equality','welsh_specific','bilingual']
),

-- 3. Well-being of Future Generations (Wales) Act 2015
(
  'anaw/2015/2/enacted',
  'Well-being of Future Generations (Wales) Act 2015',
  'Deddf Llesiant Cenedlaethau''r Dyfodol (Cymru) 2015',
  'primary', 'in_force', ARRAY['Wales'], TRUE, 'official_bilingual',
  '2015-04-29', '2016-04-01',
  'Requires Welsh public bodies to carry out sustainable development through seven well-being goals. Employment practices must align with well-being objectives including a more equal Wales. A unique Welsh governance obligation with material workforce implications for all Welsh public sector employers.',
  'Mae''r Ddeddf hon yn ei gwneud yn ofynnol i gyrff cyhoeddus Cymreig gynnal datblygiad cynaliadwy drwy saith nod llesiant. Rhaid i arferion cyflogaeth alinio ag amcanion llesiant gan gynnwys Cymru fwy cyfartal.',
  'Welsh public bodies must: (1) set and publish well-being objectives; (2) apply the five ways of working — long-term, prevention, integration, collaboration, involvement; (3) report annually on progress. Employment decisions must be assessed against the seven well-being goals.',
  'Rhaid i gyrff cyhoeddus Cymreig: (1) osod a chyhoeddi amcanion llesiant; (2) cymhwyso''r pum ffordd o weithio — hirdymor, atal, integreiddio, cydweithio, cynnwys; (3) adrodd yn flynyddol ar gynnydd.',
  'Section 3: Seven well-being goals. Section 5: Public bodies well-being objectives duty. Section 6: The five ways of working. Section 20: Future Generations Commissioner enforcement functions.',
  'Adran 3: Saith nod llesiant. Adran 5: Dyletswydd amcanion llesiant cyrff cyhoeddus. Adran 6: Y pum ffordd o weithio. Adran 20: Swyddogaethau gorfodi Comisiynydd Cenedlaethau''r Dyfodol.',
  ARRAY[1, 2], 1, 4, 'governance',
  'https://www.legislation.gov.uk/anaw/2015/2/enacted',
  ARRAY['wales','wellbeing','sustainability','future_generations','public_sector','welsh_specific','bilingual']
),

-- 4. Equality Act 2010 (Statutory Duties) (Wales) Regulations 2011
(
  'wsi/2011/1064',
  'Equality Act 2010 (Statutory Duties) (Wales) Regulations 2011',
  'Rheoliadau Deddf Cydraddoldeb 2010 (Dyletswyddau Statudol) (Cymru) 2011',
  'statutory_instrument', 'in_force', ARRAY['Wales', 'GB'], TRUE, 'official_bilingual',
  '2011-04-06', '2011-04-06',
  'Welsh-specific regulations imposing materially stronger public sector equality duties than the England equivalent. Welsh public bodies must publish equality objectives every four years with specific measurable targets, annual equality reports, and engagement evidence across all nine protected characteristics.',
  'Rheoliadau penodol i Gymru sy''n gosod dyletswyddau cyfle cyfartal sector cyhoeddus cryfach o lawer na''r cyfatebol yn Lloegr. Rhaid i gyrff cyhoeddus Cymreig gyhoeddi amcanion cydraddoldeb bob pedair blynedd gyda thargedau mesuradwy penodol.',
  'Welsh public bodies must: (1) publish equality objectives at least every 4 years with measurable targets; (2) publish annual equality reports; (3) demonstrate meaningful engagement with protected characteristic groups; (4) publish workforce data by protected characteristic including gender pay gap. Covers all 9 protected characteristics.',
  'Rhaid i gyrff cyhoeddus Cymreig: (1) gyhoeddi amcanion cydraddoldeb o leiaf bob 4 blynedd; (2) gyhoeddi adroddiadau cydraddoldeb blynyddol; (3) ddangos ymgysylltiad ystyrlon â grwpiau nodweddion gwarchodedig; (4) gyhoeddi data gweithlu yn ôl nodwedd warchodedig.',
  'Regulation 2: Equality objectives — stronger than England. Regulation 3: Equality information publication. Regulation 4: Engagement requirement. Regulation 5: Annual reporting. Applies to all Welsh public authorities under Schedule 19 Equality Act 2010.',
  'Rheoliad 2: Amcanion cydraddoldeb — cryfach na Lloegr. Rheoliad 3: Cyhoeddi gwybodaeth gydraddoldeb. Rheoliad 4: Gofyniad ymgysylltu. Rheoliad 5: Adrodd blynyddol.',
  ARRAY[2, 1], 2, 5, 'governance',
  'https://www.legislation.gov.uk/wsi/2011/1064',
  ARRAY['wales','equality','psed','discrimination','gender_pay_gap','public_sector','welsh_specific','bilingual']
),

-- 5. Agricultural Sector (Wales) Act 2014
(
  'anaw/2014/6/enacted',
  'Agricultural Sector (Wales) Act 2014',
  'Deddf Sector Amaethyddol (Cymru) 2014',
  'primary', 'in_force', ARRAY['Wales'], TRUE, 'official_bilingual',
  '2014-05-30', '2014-07-01',
  'Re-establishes Welsh agricultural wages board after Westminster abolished it for England. Creates the Agricultural Advisory Panel for Wales to set binding minimum pay and conditions for agricultural workers in Wales — materially above the national minimum wage. Unique devolved agricultural employment protections with no England equivalent.',
  'Ailsefydla fwrdd cyflogau amaethyddol Cymreig ar ôl i San Steffan ei ddiddymu ar gyfer Lloegr. Yn creu Panel Cynghori Amaethyddol Cymru i osod isafswm cyflog rhwymol ac amodau ar gyfer gweithwyr amaethyddol yng Nghymru.',
  'Agricultural employers in Wales must: (1) pay at least Welsh Agricultural Minimum Wage rates set by Panel Orders; (2) provide Panel-specified holiday entitlements; (3) comply with Welsh agricultural working time provisions; (4) observe sick pay set by the Panel. Non-compliance is a criminal offence.',
  'Rhaid i gyflogwyr amaethyddol yng Nghymru: (1) dalu o leiaf cyfraddau Isafswm Cyflog Amaethyddol Cymru; (2) darparu hawliau gwyliau penodedig; (3) cydymffurfio â darpariaethau amser gweithio amaethyddol. Mae peidio â chydymffurfio yn drosedd droseddol.',
  'Section 1: Agricultural Advisory Panel for Wales. Section 3: Panel Order powers — wages, hours, holidays. Section 5: Criminal enforcement for non-compliance. Schedule 1: Panel composition and proceedings.',
  'Adran 1: Panel Cynghori Amaethyddol Cymru. Adran 3: Pwerau Gorchymyn y Panel — cyflogau, oriau, gwyliau. Adran 5: Gorfodaeth droseddol. Atodlen 1: Cyfansoddiad a thrafodion y Panel.',
  ARRAY[3, 1], 3, 4, 'governance',
  'https://www.legislation.gov.uk/anaw/2014/6/enacted',
  ARRAY['wales','agricultural','wages','minimum_wage','welsh_specific','bilingual','rural']
),

-- 6. Welsh Language Standards (No.1) Regulations 2015
(
  'wsi/2015/996',
  'Welsh Language Standards (No.1) Regulations 2015',
  'Rheoliadau Safonau''r Gymraeg (Rhif 1) 2015',
  'statutory_instrument', 'in_force', ARRAY['Wales'], TRUE, 'official_bilingual',
  '2015-03-30', '2016-04-01',
  'Primary Welsh Language Standards instrument applying to Welsh Government, local authorities, national parks and fire and rescue authorities. Sets over 150 specific Standards across service delivery, policy making, operational and record keeping categories. Employment standards cover job advertisements, interviews, internal communications and HR documentation in Welsh.',
  'Y prif offeryn Safonau''r Gymraeg sy''n berthnasol i Lywodraeth Cymru, awdurdodau lleol, parciau cenedlaethol ac awdurdodau tân ac achub. Mae''n gosod dros 150 o Safonau penodol. Mae safonau cyflogaeth yn cwmpasu hysbysebion swyddi, cyfweliadau a dogfennaeth AD yn Gymraeg.',
  'Regulated bodies must comply with four categories of Standards: (1) Service Delivery — Welsh without disadvantage to Welsh speakers; (2) Policy Making — Welsh impact assessments; (3) Operational — internal Welsh use in employment matters; (4) Record Keeping — Welsh records. Welsh Language Commissioner has enforcement powers including compliance notices and financial penalties.',
  'Rhaid i gyrff rheoleiddiedig gydymffurfio â phedwar categori o Safonau: (1) Darparu Gwasanaethau; (2) Llunio Polisi — asesiadau effaith Cymraeg; (3) Gweithredu — defnydd mewnol o''r Gymraeg mewn cyflogaeth; (4) Cadw Cofnodion. Mae gan Gomisiynydd y Gymraeg bwerau gorfodi.',
  'Standards 1-74: Service delivery. Standards 75-100: Policy making including employment policy. Standards 101-145: Operational — employment advertising, interviews, internal communications. Standards 146-158: Record keeping. Enforcement: compliance notices, financial penalties.',
  'Safonau 1-74: Darparu gwasanaethau. Safonau 75-100: Llunio polisi gan gynnwys polisi cyflogaeth. Safonau 101-145: Gweithredu — hysbysebu cyflogaeth, cyfweliadau, cyfathrebiadau mewnol. Safonau 146-158: Cadw cofnodion.',
  ARRAY[1, 2], 1, 5, 'governance',
  'https://www.legislation.gov.uk/wsi/2015/996',
  ARRAY['wales','welsh_language','standards','cymraeg','public_sector','hr','welsh_specific','bilingual']
);

