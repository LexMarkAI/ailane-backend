-- Migration: 20260307103135_welsh_translations_batch_4_instruments_38_to_47
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: welsh_translations_batch_4_instruments_38_to_47


UPDATE legislation_library SET
  title_cy = 'Gorchymyn (Diwygiadau Canlyniadol) (Cyflogaeth) Deddf Diwygio Mentergarwch a Rheoleiddio 2013 2014',
  summary_cy = 'Deddf ddiwygio eang gyda darpariaethau cyflogaeth sylweddol. Cydsyniad Brenhinol 25 Mehefin 2013. Mae darpariaethau cyflogaeth yn cynnwys: cyflwyno Cymodi Cynnar ACAS gorfodol cyn hawliadau tribiwnlys cyflogaeth, cosbau ariannol ar gyflogwyr am doriad gwaethygedig, a''r prawf budd y cyhoedd ar gyfer datgeliadau chwibanodd.',
  obligations_cy = 'Rhaid i gyflogwyr: ymgysylltu â phroses Cymodi Cynnar ACAS pan fo gweithiwr yn ei chychwyn. Bod yn ymwybodol y gall tribiwnlys osod cosb ariannol am doriadau cyflogaeth gwaethygedig. Sicrhau bod datgeliadau chwibanodd yn bodloni''r prawf budd y cyhoedd.',
  key_provisions_cy = 'Adran 7: Cymodi Cynnar ACAS gorfodol cyn cyflwyno hawliad tribiwnlys cyflogaeth. Adrannau 15-16: Cosb ariannol hyd at £20,000 lle mae gan doriad y cyflogwr nodweddion gwaethygu. Adran 65: Dileu darpariaethau aflonyddu trydydd parti o Ddeddf Cydraddoldeb 2010. Adran 69: Diwygiiadau chwibanodd — gofyniad budd y cyhoedd wedi''i ychwanegu.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = 'd48c26b1-e219-4843-81c6-a38202c8cb08';

UPDATE legislation_library SET
  title_cy = 'Rheoliadau''r Gweithle (Iechyd, Diogelwch a Lles) 1992',
  summary_cy = 'Yn gosod safonau gofynnol ar gyfer yr amgylchedd gweithle ffisegol gan gynnwys awyru, tymheredd, goleuo, glendid, dimensiynau ystafell, gweithleoedd, a chyfleusterau glanweithiol.',
  obligations_cy = 'Cynnal gweithle mewn cyflwr effeithlon. Sicrhau awyru, tymheredd a goleuo digonol. Darparu cyfleusterau glanweithiol glân, dŵr yfed, ardaloedd gorffwys. Sicrhau arwynebau lloriau a llwybrau teithio diogel.',
  key_provisions_cy = 'Rh.5: Cynnal a chadw. Rh.6: Awyru. Rh.7: Tymheredd (lleiaf 16°C, 13°C am waith corfforol). Rh.8: Goleuo. Rh.9: Glendid. Rh.11: Gweithleoedd. Rh.20-25: Cyfleusterau glanweithiol, dŵr yfed, cyfleusterau gorffwys.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = '33608299-6006-44c2-be43-df152cdad7eb';

UPDATE legislation_library SET
  title_cy = 'Rheoliadau Gweithwyr Cyfnod Penodol (Atal Triniaeth Llai Ffafriol) 2002',
  summary_cy = 'Yn gwahardd triniaeth llai ffafriol i weithwyr cyfnod penodol o gymharu â gweithwyr parhaol cymharadwy oni bai am gyfiawnhad gwrthrychol. Yn cyfyngu ar gontractau cyfnod penodol olynol — ar ôl 4 blynedd o gyflogaeth barhaus ar gontractau cyfnod penodol olynol, ystyrir y gweithiwr yn barhaol.',
  obligations_cy = 'Rhaid i gyflogwyr: peidio â thrin gweithwyr cyfnod penodol yn llai ffafriol na gweithwyr parhaol cymharadwy oni bai am gyfiawnhad gwrthrychol. Hysbysu gweithwyr cyfnod penodol am swyddi parhaol gwag. Bod yn ymwybodol bod 4+ blynedd o gontractau cyfnod penodol olynol yn creu statws parhaol tybiannol.',
  key_provisions_cy = 'Rheoliad 3: Hawl i beidio â chael triniaeth llai ffafriol (egwyddor pro rata). Rheoliad 4: Amddiffyniad cyfiawnhad gwrthrychol. Rheoliad 7: Hawl i gael gwybod am swyddi parhaol sydd ar gael. Rheoliad 8: Contractau cyfnod penodol olynol — statws parhaol tybiannol ar ôl 4 blynedd. Rheoliad 9: Diddymu dileu hawliau diswyddo mewn contractau cyfnod penodol.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = '928c363e-34dd-45cb-9ee6-ae32e14c775a';

UPDATE legislation_library SET
  title_cy = 'Deddf Cyflogaeth (Dyrannu Cildyrnau) 2023',
  summary_cy = 'Yn ei gwneud yn ofynnol i gyflogwyr drosglwyddo''r holl gildyrnau cymhwysol, taliadau diolch a thaliadau gwasanaeth i weithwyr heb ddidyniad. Mewn grym Hydref 2024. Rhaid i gyflogwyr gael polisi tipping ysgrifenedig a chadw cofnodion am 3 blynedd.',
  obligations_cy = 'Trosglwyddo 100% o gildyrnau cymhwysol. Creu polisi tipping ysgrifenedig. Ymgynghori â gweithwyr ar ddyraniad. Cadw cofnodion tipping am 3 blynedd. Ymateb i geisiadau gweithwyr o fewn 4 wythnos.',
  key_provisions_cy = 'Adran 1: Rhaid i''r cyflogwr sicrhau bod pob cildwrn cymhwysol wedi''i ddyrannu i weithwyr. Adran 3: Polisi tipping ysgrifenedig yn ofynnol. Adran 4: Ymgynghoriad gweithwyr ar ddyraniad. Adran 5: Cadw cofnodion am 3 blynedd. Adran 6: Hawl gweithiwr i ofyn am gofnod tipping.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = 'eea46cb9-3eb9-41cf-84dd-b72f78302dfe';

UPDATE legislation_library SET
  title_cy = 'Gorchymyn Deddf Hawliau Cyflogaeth 1996 (Datganiad Adran 1) 2019',
  summary_cy = 'Ymestynodd ofynion y datganiad ysgrifenedig o fanylion cyflogaeth. O Ebrill 2020 daeth y datganiad yn hawl dydd-un a rhaid iddo gynnwys gwybodaeth ychwanegol am hawliau hyfforddiant, cyfnodau prawf, a''r holl fuddion.',
  obligations_cy = 'Darparu datganiad ysgrifenedig o fanylion cyflogaeth ar ddiwrnod un. Cynnwys yr holl wybodaeth ragnodedig gan gynnwys hawliau hyfforddiant a manylion cyfnod prawf. Darparu datganiad o newidiadau o fewn un mis i unrhyw newid.',
  key_provisions_cy = 'Adran 1 Deddf HR 1996 wedi''i hymestyn i gynnwys: diwrnodau''r wythnos ar gyfer gweithwyr amrywiol, yr holl hawliau gwyliau â thâl, yr holl fanylion tâl, hawliau hyfforddiant, manylion cyfnod prawf. Rhaid darparu''r datganiad ar neu cyn diwrnod cyntaf cyflogaeth.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = '75ef4d45-8059-4404-8d75-2ca8b12c84bf';

UPDATE legislation_library SET
  title_cy = 'Rheoliadau Gwybodaeth ac Ymgynghori â Gweithwyr 2004',
  summary_cy = 'Yn rhoi hawl i weithwyr mewn ymgymeriadau â 50 neu fwy o weithwyr i gael gwybodaeth a chael eu hymgynghori am sefyllfa economaidd y busnes, rhagolygon cyflogaeth, a phenderfyniadau tebygol o arwain at newidiadau sylweddol. Mewn grym o Ebrill 2005.',
  obligations_cy = 'Rhaid i gyflogwyr â 50+ o weithwyr: sefydlu trefniadau gwybodaeth ac ymgynghori os gofynnir yn ddilys. Hysbysu ac ymgynghori ar sefyllfa economaidd y busnes, cyflogaeth, a newidiadau trefniadaethol sylweddol. Caniatáu amser i ffwrdd i gynrychiolwyr. Amddiffyn cynrychiolwyr rhag anfantais.',
  key_provisions_cy = 'Rheoliad 7: Cais gweithiwr yn gofyn am 2% o weithwyr (lleiaf 15, wedi''i ostwng o 10% gan Ddeddf HR 2025). Rheoliad 14: Darpariaethau gwybodaeth ac ymgynghori safonol. Rheoliad 20: Pynciau — sefyllfa economaidd, cyflogaeth, penderfyniadau tebygol o arwain at newidiadau sylweddol. Rheoliad 25-26: Gorfodaeth PCC.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = 'aedf3c36-9301-4062-b289-ff58b6594ccb';

UPDATE legislation_library SET
  title_cy = 'Deddf Plant a Theuluoedd 2014',
  summary_cy = 'Cyflwynodd absenoldeb a thâl rhieni cyfun, diwygio absenoldeb mabwysiadu, ac ymestyn yr hawl i ofyn am weithio hyblyg i bob gweithiwr. Cydsyniad Brenhinol 13 Mawrth 2014. Yn caniatáu i rieni rannu hyd at 50 wythnos o absenoldeb a 37 wythnos o dâl rhyngddynt.',
  obligations_cy = 'Rhaid i gyflogwyr: caniatáu i weithwyr cymhwysol gymryd absenoldeb rhieni cyfun (hyd at 50 wythnos rhwng y ddau riant). Prosesu hysbysiadau absenoldeb rhieni cyfun yn gywir. Caniatáu i bartneriaid fynychu hyd at 2 apwyntiad cyn-enedigol. Ystyried ceisiadau gweithio hyblyg gan bob gweithiwr.',
  key_provisions_cy = 'Rhan 7: Absenoldeb a thâl rhieni cyfun. Rhan 8: Amser i ffwrdd — apwyntiadau cyn-enedigol ar gyfer partneriaid. Adran 131: Ymestyn yr hawl i ofyn am weithio hyblyg i bob gweithiwr. Adrannau 127-128: Diwygio absenoldeb a thâl mabwysiadu. Adran 130: Newidiadau tâl tadolaeth statudol.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = 'aedffca9-94c4-4ba8-a161-f45d391497ca';

UPDATE legislation_library SET
  title_cy = 'Deddf Cyflogaeth 2008',
  summary_cy = 'Yn cryfhau gorfodaeth yr Isafswm Cyflog Cenedlaethol drwy bwerau ymchwilio a chosbi GLIC uwch. Yn diwygio gweithdrefnau tribiwnlys cyflogaeth. Yn diddymu gweithdrefnau datrys anghydfodau statudol o Ddeddf Cyflogaeth 2002.',
  obligations_cy = 'Cydymffurfio ag ymchwiliadau GLIC ICG. Cynnal cofnodion ar gyfer cydymffurfiaeth â''r ICG. Ymateb i hysbysiadau gorfodaeth o fewn cyfnodau rhagnodedig.',
  key_provisions_cy = 'Rhan 1: Gorfodaeth ICG uwch, cosbau, enwi. Rhan 2: Asiantaethau cyflogaeth. Rhan 3: Diwygio tribiwnlys — diddymu datrysiad anghydfodau statudol, proses ACAS diwygiedig.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = '84a5176c-76f9-42ef-afb7-9c2b5258e113';

UPDATE legislation_library SET
  title_cy = 'Rheoliadau Diswyddo Cyfunol a Throsglwyddo Ymgymeriadau (Diwygio) 2014',
  summary_cy = 'Yn lleihau''r cyfnod ymgynghori diswyddo cyfunol gofynnol o 90 i 45 diwrnod lle cynigir 100+ o ddiswyddiadau. Yn diwygio TUPE 2006 i ganiatáu newidiadau i delerau a gytunwyd yn gyfunol ar ôl blwyddyn.',
  obligations_cy = 'Cychwyn ymgynghoriad cyfunol o leiaf 45 diwrnod cyn y diswyddo cyntaf (100+ o weithwyr). O leiaf 30 diwrnod ar gyfer 20-99. Ymgynghori â chynrychiolwyr priodol. Ffeilio ffurflen HR1 gyda''r Gwasanaeth Taliadau Diswyddo.',
  key_provisions_cy = 'Rh.3: Cyfnod ymgynghori wedi''i leihau i 45 diwrnod (100+ o ddiswyddiadau). Rh.4: Amrywiad TUPE o delerau a gytunwyd yn gyfunol ar ôl 12 mis. Rh.5: Eithriad busnes micro ar gyfer ymgynghori TUPE.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = 'a80b3b8d-7671-4aad-bc45-ac4498590d59';

UPDATE legislation_library SET
  title_cy = 'Rheoliadau Absenoldeb Rhieni Cyfun 2014',
  summary_cy = 'Yn galluogi rhieni cymhwysol i rannu hyd at 50 wythnos o absenoldeb a 37 wythnos o dâl statudol. Gall y naill riant neu''r llall gymryd absenoldeb mewn hyd at dri bloc ar wahân wedi''u britho â chyfnodau gwaith.',
  obligations_cy = 'Prosesu hysbysiadau ARC o fewn cyfnodau rhagnodedig. Derbyn ceisiadau absenoldeb di-dor. Ystyried ceisiadau absenoldeb di-dor-dor. Caniatáu 20 diwrnod RHANNU. Amddiffyn gweithwyr sy''n dychwelyd rhag anfantais.',
  key_provisions_cy = 'Rh.4-5: Cymhwysedd (26 wythnos o wasanaeth, prawf gweithgaredd economaidd partner). Rh.6-8: Hysbysiad (8 wythnos). Rh.12: Absenoldeb di-dor a di-dor-dor. Rh.19-20: Diwrnodau RHANNU (20 diwrnod). Rh.39-40: Amddiffyniad rhag anfantais a diswyddo.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = '5b3a15db-98dd-4641-bb50-21cb0f5d621e';

UPDATE legislation_library SET
  title_cy = 'Rheoliadau Absenoldeb Tadolaeth a Mabwysiadu 2002',
  summary_cy = 'Yn sefydlu hawliau statudol i absenoldeb tadolaeth (1-2 wythnos) ac absenoldeb mabwysiadu (52 wythnos). Amddiffyniad rhag anfantais a diswyddo. Mae Deddf HR 2025 yn gwneud absenoldeb tadolaeth yn hawl dydd-un o Ebrill 2026.',
  obligations_cy = 'Caniatáu absenoldeb tadolaeth ar hysbysiad priodol. Caniatáu absenoldeb mabwysiadu. Cynnal telerau yn ystod absenoldeb. Caniatáu dychwelyd i''r un rôl neu rôl addas. Dim anfantais am gymryd absenoldeb.',
  key_provisions_cy = 'Rhan 2: Absenoldeb tadolaeth (1-2 wythnos o fewn 56 diwrnod o enedigaeth). Rhan 3: Absenoldeb mabwysiadu (26 wythnos cyffredinol + 26 ychwanegol). Rh.28-29: Amddiffyniad rhag anfantais a diswyddo annheg. Rh.30: Hawl i ddychwelyd.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = '8c0b1e8b-dc13-4543-a6a5-390a5be3c89a';

UPDATE legislation_library SET
  title_cy = 'Deddf Absenoldeb Gofalwr 2023',
  summary_cy = 'Yn cyflwyno hawl statudol i un wythnos o absenoldeb gofalwr di-dâl y flwyddyn i weithwyr sy''n darparu neu''n trefnu gofal i ddibynnydd â anghenion gofal hirdymor. Cydsyniad Brenhinol 24 Mai 2023; mewn grym 6 Ebrill 2024. Hawl dydd-un — nid oes angen cyfnod cymhwyso.',
  obligations_cy = 'Rhaid i gyflogwyr: caniatáu i weithwyr cymhwysol gymryd hyd at un wythnos o absenoldeb gofalwr di-dâl y flwyddyn o ddiwrnod un. Dim ond gohirio absenoldeb lle byddai gweithrediad y busnes yn cael ei darfu''n ormodol. Peidio â pheri niwed i weithwyr am gymryd neu ofyn am absenoldeb gofalwr.',
  key_provisions_cy = 'Yn mewnosod aa.80L-80Q i Ddeddf HR 1996. Adran 80L: Hawl — un wythnos fesul cyfnod cylchol 12 mis. Adran 80M: Cymhwysedd — dibynnydd â anghen gofal hirdymor. Adran 80N: Gofynion hysbysiad. Adran 80O: Gohiriad cyflogwr mewn amgylchiadau cyfyngedig. Amddiffyniad rhag anfantais. Diswyddo annheg yn awtomatig.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = 'b08a133d-c582-4d04-a893-7da999e56b0b';

UPDATE legislation_library SET
  title_cy = 'Cod Ymarfer ACAS ar Gytundebau Setliad',
  summary_cy = 'Cod ymarfer statudol yn darparu canllawiau ar ddefnyddio cytundebau setliad i ddatrys anghydfodau yn y gweithle. Yn weithredol o 29 Gorffennaf 2013. Yn cwmpasu sgyrsiau gwarchodedig o dan a.111A Deddf HR 1996, sy''n caniatáu i drafodaethau cyn-derfynu fod yn annerbyniadwy mewn achosion diswyddo annheg cyffredinol.',
  obligations_cy = 'Dylai cyflogwyr: caniatáu o leiaf 10 diwrnod calendr i''r gweithiwr ystyried y cynnig setliad. Peidio â rhoi pwysau amhriodol ar y gweithiwr. Sicrhau bod gan y gweithiwr fynediad at gyngor cyfreithiol annibynnol. Darparu telerau ysgrifenedig clir. Deall nad yw amddiffyniad a.111A yn ymestyn i hawliadau gwahaniaethu neu chwibanodd.',
  key_provisions_cy = 'Canllawiau ar sgyrsiau gwarchodedig a.111A Deddf HR 1996. Egwyddorion ar gyfer trafodaethau setliad teg: dylid rhoi o leiaf 10 diwrnod calendr i''r gweithiwr ystyried. Rhaid i''r gweithiwr gael cyngor cyfreithiol annibynnol. Rhaid darparu telerau ysgrifenedig. Rhaid i''r broses fod yn wirfoddol heb bwysau amhriodol. Nid yw''r Cod yn berthnasol i hawliadau gwahaniaethu.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = 'b18d7519-ab9d-41b7-9d3c-33a73c47acbd';

