-- Migration: 20260307102921_welsh_translations_batch_3_instruments_25_to_37
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: welsh_translations_batch_3_instruments_25_to_37


UPDATE legislation_library SET
  title_cy = 'Deddf Amddiffyn Gweithwyr (Diwygio Deddf Cydraddoldeb 2010) 2023',
  summary_cy = 'Yn diwygio Deddf Cydraddoldeb 2010 i gyflwyno dyletswydd ragweithiol newydd ar gyflogwyr i gymryd camau rhesymol i atal aflonyddu rhywiol ar weithwyr. Cydsyniad Brenhinol 26 Hydref 2023; mewn grym 26 Hydref 2024. Gall tribiwnlysoedd gynyddu iawndal hyd at 25% lle bo cyflogwr yn torri''r ddyletswydd atal.',
  obligations_cy = 'Rhaid i gyflogwyr: cymryd camau rhesymol i atal aflonyddu rhywiol (dyletswydd ragweithiol). Cynnal asesiadau risg. Datblygu a gweithredu polisïau gwrth-aflonyddu. Darparu hyfforddiant i staff a rheolwyr. Sefydlu gweithdrefnau adrodd clir. Ystyried risgiau gan drydydd partïon.',
  key_provisions_cy = 'Adran 1: Yn mewnosod adran 40A newydd i Ddeddf Cydraddoldeb 2010 — dyletswydd cyflogwr i gymryd camau rhesymol i atal aflonyddu rhywiol. Adran 2: Gall tribiwnlys gynyddu iawndal hyd at 25% am dor-amod. Ymestyn i ddigwyddiadau gwaith ac achlysuron cymdeithasol cysylltiedig â gwaith.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = '8914401e-9da4-48b4-95ea-0d4b2bd8e575';

UPDATE legislation_library SET
  title_cy = 'Cod Ymarfer Statudol Cyflogaeth y Comisiwn Cydraddoldeb a Hawliau Dynol',
  summary_cy = 'Y cod ymarfer statudol a gyhoeddwyd gan y Comisiwn Cydraddoldeb a Hawliau Dynol yn darparu canllawiau manwl ar gymhwyso Deddf Cydraddoldeb 2010 mewn cyflogaeth. Yn weithredol o 6 Ebrill 2011. Er nad yw''n gyfreithiol rwymol, rhaid i dribiwnlysoedd cyflogaeth ystyried darpariaethau perthnasol.',
  obligations_cy = 'Dylai cyflogwyr: ddeall a chymhwyso Deddf Cydraddoldeb 2010 yn gywir ym mhob penderfyniad cyflogaeth. Dilyn canllawiau ar arferion recriwtio cyfreithlon. Deall pryd y caniateir camau cadarnhaol. Gweithredu addasiadau rhesymol yn rhagweithiol. Deall atebolrwydd dirprwyol am wahaniaethu gan weithwyr.',
  key_provisions_cy = 'Penodau yn cwmpasu: nodweddion gwarchodedig yng nghyd-destun cyflogaeth, ymddygiad gwaharddedig, recriwtio, telerau ac amodau, diswyddo, gofynion galwedigaethol, camau cadarnhaol, cyflog cyfartal, addasiadau rhesymol, atebolrwydd cyflogwr. Yn darparu enghreifftiau wedi''u gweithio ar brofion cymesuredd.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = '32911b6a-e94a-4d92-9b96-bd8d01b52933';

UPDATE legislation_library SET
  title_cy = 'Deddf Cyflogaeth 2002',
  summary_cy = 'Cyflwynodd ddiwygiiadau cyflogaeth amrywiol gan gynnwys gwelliannau tâl a gwyliau mamolaeth a thadolaeth, a''r fframwaith ar gyfer ceisiadau gweithio hyblyg. Cydsyniad Brenhinol 8 Gorffennaf 2002. Mae llawer o ddarpariaethau gwreiddiol wedi''u disodli gan ddeddfwriaeth ddilynol.',
  obligations_cy = 'Rhaid i gyflogwyr: darparu datganiad ysgrifenedig o fanylion cyflogaeth (mae cosb a.38 yn berthnasol mewn tribiwnlys). Mae rhwymedigaethau sy''n weddill wedi''u disodli gan ddeddfwriaeth ddilynol.',
  key_provisions_cy = 'Rhan 2: Gwelliannau tâl a gwyliau mamolaeth a thadolaeth. Rhan 3: Diwygio tribiwnlys. Adran 38: Methiant i ddarparu datganiad ysgrifenedig — rhaid i dribiwnlys ddyfarnu 2 neu 4 wythnos o dâl. Adran 31: Addasu dyfarniadau tribiwnlys am fethiant i ddilyn gweithdrefnau.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = 'dcad5056-02e7-40fb-83d6-f1359afeb6d1';

UPDATE legislation_library SET
  title_cy = 'Rheoliadau Gweithwyr Rhan-amser (Atal Triniaeth Llai Ffafriol) 2000',
  summary_cy = 'Yn gweithredu Cyfarwyddeb Gwaith Rhan-amser yr UE. Yn gwahardd triniaeth llai ffafriol i weithwyr rhan-amser o gymharu â gweithwyr llawn-amser cymharadwy oni bai am gyfiawnhad gwrthrychol. Mewn grym 1 Gorffennaf 2000.',
  obligations_cy = 'Rhaid i gyflogwyr: peidio â thrin gweithwyr rhan-amser yn llai ffafriol na gweithwyr llawn-amser cymharadwy oni bai am gyfiawnhad gwrthrychol. Cymhwyso''r egwyddor pro rata ar gyfer cyflog a buddion. Cynnwys gweithwyr rhan-amser mewn hyfforddiant a dyrchafiad ar delerau cyfartal.',
  key_provisions_cy = 'Rheoliad 2: Diffiniadau gweithwyr rhan-amser a llawn-amser. Rheoliad 5: Hawl i beidio â chael eich trin yn llai ffafriol — egwyddor pro rata. Rheoliad 6: Hawl i beidio â dioddef anfantais. Rheoliad 7: Diswyddo annheg am honni hawliau.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = '09d499e0-fc7a-448a-abac-5bca8bf8da37';

UPDATE legislation_library SET
  title_cy = 'Rheoliadau Gweithwyr Asiantaeth 2010',
  summary_cy = 'Yn gweithredu Cyfarwyddeb Gweithwyr Asiantaeth yr UE. Yn rhoi hawl i weithwyr asiantaeth gael yr un amodau gwaith sylfaenol â gweithwyr a recriwtiwyd yn uniongyrchol ar ôl 12 wythnos yn yr un rôl. Yn cwmpasu cyflog, amser gweithio, a mynediad at gyfleusterau a swyddi gwag.',
  obligations_cy = 'Rhaid i logi-gwyr: darparu amodau gwaith sylfaenol cyfartal i weithwyr asiantaeth ar ôl cyfnod cymhwyso 12 wythnos. Darparu mynediad i gyfleusterau cyfunol o ddiwrnod un. Hysbysu gweithwyr asiantaeth am swyddi gwag. Rhaid i asiantaethau gwaith dros dro: darparu gwybodaeth am delerau ymgysylltu.',
  key_provisions_cy = 'Rheoliad 5: Amodau gwaith sylfaenol cyfartal ar ôl cyfnod cymhwyso 12 wythnos. Rheoliad 12: Mynediad i gyfleusterau cyfunol o ddiwrnod un. Rheoliad 13: Hawl i wybodaeth am swyddi gwag. Rheoliad 9: Gwrth-osgoi — gwaharddiad ar drefniadau tâl rhwng aseiniadau.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = '13f22178-3850-4d2f-a709-35f099d401d5';

UPDATE legislation_library SET
  title_cy = 'Deddf Pwerau Ymchwilio Rheoleiddiol 2000',
  summary_cy = 'Yn rheoleiddio pwerau gwyliadwriaeth ac ymchwilio gan gynnwys rhyngdorri cyfathrebiadau a gwyliadwriaeth gudd. Rhan II yn berthnasol i fonitro cyfathrebiadau gweithwyr gan gyflogwyr a gwyliadwriaeth yn y gweithle.',
  obligations_cy = 'Ni chaiff cyflogwyr ryng-dorri cyfathrebiadau gweithwyr heb awdurdod cyfreithiol. Rhaid i fonitro yn y gweithle fod yn gymesur ac yn cydymffurfio â RIPA/DPA. Mae gwyliadwriaeth gudd yn gofyn am awdurdodiad priodol. Polisïau monitro gweithwyr yn ofynnol.',
  key_provisions_cy = 'Rhan I: Rhyngdorri cyfathrebiadau. Rhan II: Gwyliadwriaeth a ffynonellau cudd-ymchwil dynol. Adran 26: Gwyliadwriaeth gyfeiriedig. Adran 28: Meini prawf awdurdodi. Rheoliadau Telathrebu (Arfer Busnes Cyfreithlon) 2000 (eithriad monitro cyflogwr).',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = 'd798384c-235f-46a9-a04c-c2034d90441a';

UPDATE legislation_library SET
  title_cy = 'Rheoliadau Gweithio Hyblyg 2014',
  summary_cy = 'Ymestynodd yr hawl i ofyn am weithio hyblyg i bob gweithiwr sydd â 26 wythnos o wasanaeth. Rhaid i''r cyflogwr ymdrin â''r cais o fewn tri mis a dim ond gwrthod am un o wyth rheswm busnes statudol. Bydd Deddf Hawliau Cyflogaeth 2025 yn cryfhau gweithio hyblyg ymhellach.',
  obligations_cy = 'Rhaid i gyflogwyr: ystyried ceisiadau gweithio hyblyg mewn modd rhesymol. Gwneud penderfyniad o fewn 3 mis oni estynnu. Dim ond gwrthod ar un o wyth sail fusnes statudol. Bydd Deddf HR 2025 yn ychwanegu gofyniad i egluro rhesymeg a nodi''r sail fusnes benodol y dibynir arni.',
  key_provisions_cy = 'Rheoliad 3: Hawl i ymgeisio — unrhyw weithiwr â 26 wythnos o gyflogaeth barhaus. Rheoliad 5: Dyletswydd cyflogwr i ymdrin â chais o fewn cyfnod penderfyniad. Wyth sail statudol dros wrthod: baich costau ychwanegol, effaith niweidiol ar allu i gwrdd â galw cwsmeriaid, anallu i ad-drefnu gwaith, anallu i recriwtio, effaith ar ansawdd/perfformiad, annigonolrwydd gwaith, newidiadau strwythurol cynlluniedig.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = 'd2a9aa63-c95c-4157-b594-1a06502c3c5b';

UPDATE legislation_library SET
  title_cy = 'Rheoliadau Absenoldeb Mamolaeth a Rhieni ayb 1999',
  summary_cy = 'Y rheoliadau manwl sy''n llywodraethu absenoldeb mamolaeth statudol (52 wythnos) ac absenoldeb rhieni di-dâl (18 wythnos fesul plentyn tan oed 18). Mae Deddf HR 2025 yn gwneud absenoldeb rhieni yn hawl dydd-un o Ebrill 2026.',
  obligations_cy = 'Rhaid i gyflogwyr: caniatáu 52 wythnos o absenoldeb mamolaeth. Parhau â''r holl delerau contractol ac eithrio cyflog yn ystod absenoldeb. Caniatáu dychwelyd i''r un rôl neu rôl addas. Caniatáu 18 wythnos o absenoldeb rhieni fesul plentyn. Peidio â diswyddo am arfer hawliau absenoldeb.',
  key_provisions_cy = 'Rhan II: Absenoldeb mamolaeth — 52 wythnos cyfanswm. Gofynion hysbysu. Hawl i ddychwelyd i''r un swydd ar ôl absenoldeb mamolaeth cyffredinol. Rhan III: Absenoldeb rhieni — 18 wythnos fesul plentyn tan oed 18. Gall cyflogwr ohirio am resymau busnes. Rheoliad 10: Dileu swydd yn ystod absenoldeb mamolaeth — hawl i swydd addas arall.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = '7b0a3ca9-10cc-4b57-b651-9ab444a0b7f0';

UPDATE legislation_library SET
  title_cy = 'Deddf Amddiffyn rhag Diswyddo (Beichiogrwydd ac Absenoldeb Teuluol) 2023',
  summary_cy = 'Yn ymestyn amddiffyniad diswyddo ar gyfer gweithwragedd beichiog a''r rhai sy''n dychwelyd o absenoldeb mamolaeth, mabwysiadu neu rieni cyfun. Mewn grym 6 Ebrill 2024. Mae amddiffyniad yn cwmpasu beichiogrwydd, absenoldeb teuluol, ac 18 mis ar ôl dyddiad geni/lleoliad.',
  obligations_cy = 'Rhaid i gyflogwyr: cynnig swyddi gwag addas i weithwragedd beichiog a''r rhai sy''n dychwelyd o absenoldeb teuluol os yw eu rôl yn cael ei dileu. Cynnal blaenoriaeth i''r gweithwyr hyn dros staff eraill sy''n cael eu gwneud yn redundant. Cymhwyso amddiffyniad o adeg hysbysu beichiogrwydd hyd at 18 mis ar ôl geni.',
  key_provisions_cy = 'Yn diwygio Deddf HR 1996. Yn ymestyn y cyfnod gwarchodedig i: beichiogrwydd, absenoldeb mamolaeth/mabwysiadu/rhieni cyfun, ac 18 mis ar ôl geni/lleoliad. Yn ystod y cyfnod gwarchodedig, os yw rôl yn cael ei dileu, rhaid i''r cyflogwr gynnig swydd addas arall lle bo un yn bodoli. Mae gan weithwyr flaenoriaeth dros weithwyr eraill.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = 'b4b33c93-4a4b-4bad-a6fb-44479fd9b77e';

UPDATE legislation_library SET
  title_cy = 'Deddf Cynlluniau Pensiwn 1993',
  summary_cy = 'Deddfwriaeth bensiwn wedi''i chydgrynhoad yn cwmpasu cynlluniau pensiwn galwedigaethol a phersonol. Mae Rhan III yn amddiffyn hawliau pensiwn gweithwyr ar ansolfedd cyflogwr. Perthnasol drwy rwymedigaethau auto-gofrestru ac amodau blaenoriaeth ansolfedd.',
  obligations_cy = 'Cynnal cyfraniadau pensiwn cyflogwr. Cydymffurfio ag auto-gofrestru. Amddiffyn hawliau yn ystod ad-strwythuro. Adrodd am fethiannau talu sylweddol i''r Rheoleiddiwr Pensiynau.',
  key_provisions_cy = 'Rhan I: Cynlluniau pensiwn galwedigaethol. Rhan III: Amddiffyniad ar ansolfedd. Rhan IV: Cynlluniau pensiwn personol. Rhyngweithio â Deddf Pensiynau 2008 (auto-gofrestru) a darpariaethau''r Gronfa Amddiffyn Pensiynau.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = '0077cd48-d2b7-4e72-a137-4a8880b5f1f7';

UPDATE legislation_library SET
  title_cy = 'Deddf Gofal Newyddenedigol (Absenoldeb a Thâl) 2023',
  summary_cy = 'Yn cyflwyno absenoldeb a thâl gofal newyddenedigol statudol ar gyfer rhieni babanod a dderbyniwyd i ofal newyddenedigol o fewn 28 diwrnod o enedigaeth am 7 niwrnod neu fwy di-dor. Cydsyniad Brenhinol 24 Mai 2023; wedi''i gychwyn yn llawn 6 Ebrill 2025. Gall rhieni cymhwysol gymryd hyd at 12 wythnos o absenoldeb yn ychwanegol at absenoldeb teuluol arall.',
  obligations_cy = 'Rhaid i gyflogwyr: caniatáu i weithwyr cymhwysol gymryd absenoldeb gofal newyddenedigol o ddiwrnod un. Derbyn hysbysiad. Parhau â thelerau contractol yn ystod absenoldeb. Caniatáu dychwelyd i''r un rôl neu rôl addas. Peidio â pheri niwed i weithwyr am gymryd absenoldeb. Diweddaru polisïau a hyfforddi tîm AD.',
  key_provisions_cy = 'Rhan 1: Absenoldeb gofal newyddenedigol statudol — hawl dydd-un, hyd at 12 wythnos. Rhan 2: Tâl gofal newyddenedigol statudol — yn gofyn am 26 wythnos o wasanaeth. Amodau cymhwyso: baban wedi''i dderbyn o fewn 28 diwrnod o enedigaeth am 7+ diwrnod di-dor. Absenoldeb Haen 1 a Haen 2. Amddiffyniad rhag anfantais a diswyddo annheg yn awtomatig.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = 'b9444773-6c6d-4097-b5e3-8f686c358b20';

UPDATE legislation_library SET
  title_cy = 'Deddf Ansolfedd 1986',
  summary_cy = 'Y prif ddeddfwriaeth sy''n llywodraethu ansolfedd corfforaethol a phersonol yng Nghymru a Lloegr. Cydsyniad Brenhinol 25 Gorffennaf 1986. Mae darpariaethau cyflogaeth yn amddiffyn hawliadau gweithwyr mewn ansolfedd: mae cyflogau, tâl gwyliau, tâl rhybudd a thaliadau diswyddo yn ddyledion blaenoriaeth.',
  obligations_cy = 'Rhaid i ymarferwyr ansolfedd: hysbysu gweithwyr am brosesau ansolfedd. Cydymffurfio â TUPE lle trosglwyddir busnes. Sicrhau bod dyledion blaenoriaeth gweithwyr wedi''u nodi a''u graddio''n briodol. Cydweithredu â''r Gwasanaeth Taliadau Diswyddo.',
  key_provisions_cy = 'Rhan IV: Dirwyn i Ben. Atodlen 6: Dyledion blaenoriaeth — hawliadau gweithwyr am hyd at 4 mis o ôl-ddyledion cyflog, tâl gwyliau cronedig, cyfraniadau pensiwn. Adran 175: Blaenoriaeth dyledion blaenoriaeth. Rhan XII Deddf HR 1996: Hawliau gweithwyr ar ansolfedd — hawl i hawlio o''r Gronfa Yswiriant Gwladol.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = '22ace9af-45ce-4972-bb40-f4ad3b9330dc';

