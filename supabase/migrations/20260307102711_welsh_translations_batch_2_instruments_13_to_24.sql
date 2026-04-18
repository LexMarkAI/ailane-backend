-- Migration: 20260307102711_welsh_translations_batch_2_instruments_13_to_24
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: welsh_translations_batch_2_instruments_13_to_24


UPDATE legislation_library SET
  title_cy = 'Rheoliadau Adrodd am Anafiadau, Clefydau a Digwyddiadau Peryglus 2013',
  summary_cy = 'Yn ei gwneud yn ofynnol i gyflogwyr adrodd am ddamweiniau gweithle penodol, clefydau galwedigaethol a digwyddiadau peryglus i''r ASB. Adnabyddir fel RIDDOR. Mae methiant i adrodd yn drosedd droseddol.',
  obligations_cy = 'Adrodd am anafiadau marwol a phenodedig ar unwaith. Adrodd am analluogrwydd dros 7 diwrnod o fewn 15 diwrnod. Adrodd am glefydau galwedigaethol a digwyddiadau peryglus. Cadw cofnodion am o leiaf 3 blynedd.',
  key_provisions_cy = 'Rh.4: Marwolaethau ac anafiadau penodedig. Rh.5: Analluogrwydd dros 7 diwrnod. Rh.7: Clefydau galwedigaethol y gellir eu hadrodd. Rh.8: Digwyddiadau peryglus. Rh.12: Cadw cofnodion (o leiaf 3 blynedd).',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = '806ee6b5-4ab7-4267-99cc-035198d2a929';

UPDATE legislation_library SET
  title_cy = 'Rheoliadau Rheoli Sylweddau Peryglus i Iechyd 2002',
  summary_cy = 'Yn ei gwneud yn ofynnol i gyflogwyr reoli amlygiad i sylweddau peryglus. Adnabyddir fel COSHH. Yn cwmpasu cemegion, asiantau biolegol, llwch, mygdarthau. Yn ei gwneud yn ofynnol i gynnal asesiad, atal neu reoli, monitro, gwyliadwriaeth iechyd, a hyfforddiant.',
  obligations_cy = 'Cynnal asesiadau COSHH. Gweithredu mesurau rheoli. Monitro lefelau amlygiad. Darparu gwyliadwriaeth iechyd. Hyfforddi gweithwyr ar beryglon.',
  key_provisions_cy = 'Rh.6: Asesiadau COSHH. Rh.7: Atal neu reoli amlygiad. Rh.9: Cynnal a chadw. Rh.10: Monitro amlygiad. Rh.11: Gwyliadwriaeth iechyd. Rh.12: Gwybodaeth, cyfarwyddyd a hyfforddiant.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = '5ac311bb-98d5-429e-b4fa-4511f2ee2077';

UPDATE legislation_library SET
  title_cy = 'Rheoliadau Adeiladu (Dylunio a Rheoli) 2015',
  summary_cy = 'Y prif reoliadau sy''n llywodraethu iechyd a diogelwch mewn prosiectau adeiladu. Adnabyddir fel CDM 2015. Yn neilltuo dyletswyddau i gleientiaid, dylunwyr, prif ddylunwyr, prif gontractwyr a chontractwyr.',
  obligations_cy = 'Cleientiaid: penodi prif ddylunydd a phrif gontractwr ar gyfer prosiectau aml-gontractwr. Pob deiliad dyletswydd: cydweithredu, cydgordio, adrodd. Cynlluniau cam adeiladu yn ofynnol.',
  key_provisions_cy = 'Rhan 2: Dyletswyddau cleient (Rh.4-7). Rhan 3: Dyletswyddau iechyd a diogelwch mewn dylunio a rheoli. Rh.12-14: Dyletswyddau prif ddylunydd a phrif gontractwr. Atodlen 2: Cyfleusterau lles gofynnol.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = '349237f5-e0a3-4bf4-ab02-041950ec9197';

UPDATE legislation_library SET
  title_cy = 'Deddf Datgeliadau er Budd y Cyhoedd 1998',
  summary_cy = 'Y ddeddfwriaeth amddiffyn chwibanodd yn y DU. Yn mewnosod Rhan IVA i Ddeddf Hawliau Cyflogaeth 1996, gan amddiffyn gweithwyr sy''n gwneud datgeliadau cymhwysol am gamwedd rhag anfantais a diswyddo. Mae iawndal am ddiswyddo chwibanodd yn awtomatig annheg heb cap.',
  obligations_cy = 'Rhaid i gyflogwyr: peidio â diswyddo na pheri niwed i weithwyr am wneud datgeliadau gwarchodedig. Sefydlu gweithdrefnau chwibanodd mewnol. Sicrhau nad yw cymalau cyfrinachedd yn atal datgeliadau gwarchodedig.',
  key_provisions_cy = 'Yn mewnosod i Ddeddf HR 1996: Adran 43A: ystyr datgeliad gwarchodedig. Adran 43B: datgeliadau cymhwysol — 6 categori. Adran 47B: amddiffyniad rhag anfantais. Adran 103A: diswyddo annheg yn awtomatig am wneud datgeliad gwarchodedig.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = '70454963-168c-4719-b2cd-200ba0157d41';

UPDATE legislation_library SET
  title_cy = 'Cod Ymarfer ACAS ar Weithdrefnau Disgyblu a Chwynion',
  summary_cy = 'Y cod ymarfer statudol sy''n nodi egwyddorion ar gyfer trin sefyllfaoedd disgyblu a chwyn yn y gwaith. Gall tribiwnlysoedd cyflogaeth addasu dyfarniadau iawndal hyd at 25% am fethiant afresymol i ddilyn y Cod. Fersiwn bresennol yn weithredol o 11 Mawrth 2015.',
  obligations_cy = 'Dylai cyflogwyr: ddilyn Cod ACAS wrth drin materion disgyblu a chwyn. Cynnal ymchwiliad rhesymol. Hysbysu''r gweithiwr am honiadau yn ysgrifenedig gyda digon o fanylion. Cynnal cyfarfod. Caniatáu i''r gweithiwr gael ei gyfeillio. Darparu penderfyniad ysgrifenedig. Cynnig hawl i apelio.',
  key_provisions_cy = 'Egwyddorion craidd: sefydlu ffeithiau cyn cymryd camau. Hysbysu''r gweithiwr yn ysgrifenedig. Caniatáu i''r gweithiwr ymateb mewn cyfarfod disgyblu. Caniatáu i''r gweithiwr gael ei gyfeillio gan gynrychiolydd undeb llafur neu gydweithiwr. Hawl apelio. Gweithredu''n brydlon ac yn gyson. Mae''r Cod yn berthnasol i faterion ymddygiad a pherfformiad, nid diswyddo.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = 'e9046e62-ac38-4a9e-ac64-5a688d534e22';

UPDATE legislation_library SET
  title_cy = 'Deddf Undebau Llafur 2016',
  summary_cy = 'Cyflwynodd ofynion ychwanegol ar gyfer pleidleisiau camau diwydiannol. Mae''r rhan fwyaf o ddarpariaethau trothwy pleidlais wedi''u diddymu gan Ddeddf Hawliau Cyflogaeth 2025. Mae adrodd ar amser cyfleuster ar gyfer cyflogwyr y sector cyhoeddus yn parhau mewn grym.',
  obligations_cy = 'Cyflogwyr y sector cyhoeddus: cyhoeddi data amser cyfleuster yn flynyddol. Cydymffurfio â gofynion goruchwylio picedu. Nodyn: gofynion trothwy pleidlais wedi''u diddymu gan Ddeddf HR 2025.',
  key_provisions_cy = 'Adran 3: 40% trothwy cefnogaeth ar gyfer gwasanaethau cyhoeddus pwysig. Adran 7: Dyddiad dod i ben mandad pleidlais. Adran 10: Goruchwyliaeth bicedu. Adrannau 12-13: Adrodd am amser cyfleuster (sector cyhoeddus). Nodyn: trothwy trosiant 50% wedi''i ddiddymu gan Ddeddf HR 2025.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = '3063fba6-d11d-4be0-afe5-afd067df8330';

UPDATE legislation_library SET
  title_cy = 'Deddf Mewnfudo 2014',
  summary_cy = 'Cryfhaodd y drefn wirio hawl i weithio ar gyfer cyflogwyr. Cyflwynodd gosbau sifil uwch am gyflogi gweithwyr anghyfreithlon o dan Adrannau 33-46.',
  obligations_cy = 'Cynnal gwiriadau dogfen hawl i weithio rhagnodedig cyn dechrau cyflogaeth. Cynnal gwiriadau dilynol ar gyfer caniatâd cyfyngedig o ran amser. Cadw copïau am gyfnod cyflogaeth ac am 2 flynedd wedi hynny.',
  key_provisions_cy = 'Rhan 3: Mynediad i Wasanaethau. Adrannau 33-46: Cynllun cosb sifil hawl i weithio. Adran 34: Cosb sifil uwch. Adran 35: Gwiriadau dogfen rhagnodedig. Adran 40: Hysbysiadau cau gweithio anghyfreithlon.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = 'c7e9ad1f-168b-4be0-8eef-c1c144702657';

UPDATE legislation_library SET
  title_cy = 'Deddf Cysylltiadau Cyflogaeth 1999',
  summary_cy = 'Cyflwynodd y weithdrefn gydnabyddiaeth undeb llafur statudol a chryfhaodd hawliau cyflogaeth cyfunol. Cydsyniad Brenhinol 27 Gorffennaf 1999. Darpariaethau allweddol yn cynnwys: cydnabyddiaeth undeb llafur gorfodol, hawl i gael cwmni mewn gwrandawiadau disgyblu, a gwarchod gweithwyr ar streic gyfreithlon.',
  obligations_cy = 'Rhaid i gyflogwyr: ymgysylltu â''r weithdrefn gydnabyddiaeth statudol os caiff ei sbarduno. Caniatáu i weithwyr gael cwmni mewn gwrandawiadau disgyblu a chwynion. Peidio â diswyddo gweithwyr yn rhan o gamau diwydiannol cyfreithlon. Cydweithredu â phrosesau''r Pwyllgor Canolog Cyfarbitraeth.',
  key_provisions_cy = 'Adrannau 1-9 + Atodlen A1: Gweithdrefn gydnabyddiaeth undeb llafur statudol drwy''r PCC. Adrannau 10-15: Hawl i gael cwmni — gall gweithiwr ofyn am gwmni mewn gwrandawiad disgyblu neu gwyn. Adrannau 16-17: Diswyddo annheg gweithwyr sy''n streicio — gwarchod wedi''i ymestyn gan Ddeddf HR 2025.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = '8eabb911-90a6-4c5a-b9ad-3eb6295c9eb6';

UPDATE legislation_library SET
  title_cy = 'Deddf Isafswm Cyflog Cenedlaethol 1998',
  summary_cy = 'Yn sefydlu''r hawl statudol i isafswm cyflog cenedlaethol i weithwyr yn y DU. Cydsyniad Brenhinol 31 Gorffennaf 1998; mewn grym 1 Ebrill 1999. Cyfraddau wedi''u gosod yn flynyddol gan yr Ysgrifennydd Gwladol ar argymhelliad y Comisiwn Cyflog Isel. O Ebrill 2025: Cyflog Byw Cenedlaethol (21+) £12.21/awr.',
  obligations_cy = 'Rhaid i gyflogwyr: talu o leiaf y gyfradd ICG/CBG berthnasol am yr holl amser gweithio. Cynnal cofnodion digonol. Peidio â pheri niwed i weithwyr am honni hawliau ICG. Cyfrifo amser gwaith yn gywir gan gynnwys teithio, ar alwad, a hyfforddiant gofynnol.',
  key_provisions_cy = 'Adran 1: Hawl gweithwyr i ICG. Adran 3: Eithriadau — hunangyflogedig, gwirfoddolwyr gwirioneddol, gweithwyr teuluol. Adran 10: Hawl gweithiwr i beidio â dioddef anfantais. Adran 14: Hawl gweithiwr i gael mynediad at gofnodion. Adran 17: Diffyg cydymffurfiaeth yn cael ei drin fel didyniad anawdurdodedig. Adran 31: Troseddau troseddol am esgeuluso talu''r ICG yn fwriadol.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = '32bab6ab-d34d-4a67-9519-9a46f4eb4d0a';

UPDATE legislation_library SET
  title_cy = 'Rheoliadau Amser Gweithio 1998',
  summary_cy = 'Yn gweithredu Cyfarwyddeb Amser Gweithio yr UE. Yn sefydlu uchafswm oriau gwaith wythnosol, seibiannau gorffwys, gwyliau blynyddol â thâl, a therfynau gwaith nos. Mae gan weithwyr hawl i 5.6 wythnos o wyliau â thâl, uchafswm wythnos waith cyfartalog o 48 awr (gyda''r opsiwn optio allan unigol) a 11 awr o orffwys dyddiol di-dor.',
  obligations_cy = 'Rhaid i gyflogwyr: sicrhau nad yw gweithwyr yn rhagori ar wythnos gyfartalog 48 awr oni bai am opsiwn optio allan dilys. Caniatáu seibiannau a chyfnodau gorffwys. Darparu 5.6 wythnos o wyliau â thâl. Cynnig asesiadau iechyd am ddim i weithwyr nos. Sicrhau bod opsiynau optio allan yn wirfoddol.',
  key_provisions_cy = 'Rheoliad 4: Uchafswm wythnos gyfartalog 48 awr. Rheoliad 5: Opsiwn optio allan unigol (gwirfoddol, yn ysgrifenedig). Rheoliadau 10-12: Gorffwys dyddiol (11 awr), gorffwys wythnosol (24 awr), seibiannau gorffwys (20 munud os shift >6 awr). Rheoliadau 13-16: Gwyliau blynyddol — 5.6 wythnos. Rheoliad 6: Terfyn gwaith nos — 8 awr ar gyfartaledd.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = '7fe1daa2-386d-4d1f-b4fb-eb2ecf8e6ea6';

UPDATE legislation_library SET
  title_cy = 'Rheoliadau Isafswm Cyflog Cenedlaethol 1999',
  summary_cy = 'Y rheoliadau manwl sy''n gweithredu Deddf Isafswm Cyflog Cenedlaethol 1998. Yn pennu sut y cyfrifir amser gwaith a chyflog ar gyfer cydymffurfiaeth â''r ICG ar draws pedwar categori o waith: gwaith oriau cyflogedig, gwaith amser, gwaith allbwn, a gwaith heb ei fesur. Mewn grym 1 Ebrill 1999.',
  obligations_cy = 'Rhaid i gyflogwyr: categoreiddio math o waith pob gweithiwr yn gywir. Cyfrifo amser gwaith yn gywir gan gynnwys amser teithio rhwng aseiniadau, hyfforddiant gofynnol, ac amser ar alwad. Eithrio cildyrnau a gorbremia goramser o gyfrifiad ICG. Cynnal cofnodion sy''n dangos cydymffurfiaeth.',
  key_provisions_cy = 'Rheoliad 3: Dehongliad a categorïau gwaith. Rheoliadau 4-8: Gwaith oriau cyflogedig. Rheoliadau 9-13: Gwaith amser gan gynnwys ar alwad. Rheoliad 30: Taliadau wedi''u heithrio o ICG — gorpremia goramser, gorpremia shift, cildyrnau. Rheoliad 36: Gwrthbwyso llety.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = 'a3e47f88-caa5-4005-8207-6d4a65c83c3f';

