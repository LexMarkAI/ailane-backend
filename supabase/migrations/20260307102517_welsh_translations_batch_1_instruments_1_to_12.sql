-- Migration: 20260307102517_welsh_translations_batch_1_instruments_1_to_12
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: welsh_translations_batch_1_instruments_1_to_12


UPDATE legislation_library SET
  title_cy = 'Deddf Diogelu Data 2018',
  summary_cy = 'Gweithrediad y DU o Reoliad Cyffredinol ar Ddiogelu Data yr UE, gan ategu''r GDPR a gadwyd gyda darpariaethau penodol i''r DU. Sefydlu''r fframwaith diogelu data ar gyfer prosesu data personol yn y DU, gan gynnwys data gweithwyr. Cydsyniad Brenhinol 23 Mai 2018; mewn grym 25 Mai 2018. Yn cwmpasu sail gyfreithlon ar gyfer prosesu, hawliau''r testun data, egwyddorion diogelu data, amodau ar gyfer prosesu data categori arbennig (gan gynnwys iechyd, aelodaeth undeb llafur, data biometrig), a rôl Swyddfa''r Comisiynydd Gwybodaeth fel awdurdod goruchwylio.',
  obligations_cy = 'Rhaid i gyflogwyr: gael sail gyfreithlon ar gyfer prosesu data personol gweithwyr. Cynnal cofnodion o weithgareddau prosesu. Cynnal Asesiadau Effaith Diogelu Data ar gyfer prosesu risg uchel. Penodi Swyddog Diogelu Data lle bo''n ofynnol. Ymateb i geisiadau mynediad o fewn un mis. Gweithredu mesurau diogelwch technegol a threfniadol priodol. Adrodd am doriadau data personol i''r ICO o fewn 72 awr. Darparu hysbysiadau preifatrwydd i weithwyr.',
  key_provisions_cy = 'Rhan 1: Rhagarweiniol — diffiniadau a chwmpas. Rhan 2: Prosesu cyffredinol (yn ategu GDPR y DU). Rhan 5: Pwerau a dyletswyddau''r ICO. Rhan 6: Gorfodi — hysbysiadau asesu, hysbysiadau gorfodi, hysbysiadau cosb, troseddau troseddol. Atodlen 1: Amodau data categori arbennig a chollfarn droseddol gan gynnwys darpariaethau penodol i gyflogaeth.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = '267b3b4a-0eb2-473d-a941-106cdb0845a3';

UPDATE legislation_library SET
  title_cy = 'Deddf Cydraddoldeb 2010',
  summary_cy = 'Y fframwaith gwrth-wahaniaethu cynhwysfawr sengl ar gyfer Cymru, Lloegr a''r Alban. Yn gwahardd gwahaniaethu, aflonyddu a chosbi ar sail naw nodwedd warchodedig: oedran, anabledd, ailbennu rhywedd, priodas/partneriaeth sifil, beichiogrwydd/mamolaeth, hil, crefydd/cred, rhyw, a chyfeiriadedd rhywiol. Cydsyniad Brenhinol 8 Ebrill 2010; prif ddarpariaethau cyflogaeth mewn grym 1 Hydref 2010.',
  obligations_cy = 'Rhaid i gyflogwyr: beidio â gwahaniaethu wrth recriwtio, o ran telerau, dyrchafiad, hyfforddiant a diswyddo. Gwneud addasiadau rhesymol ar gyfer gweithwyr anabl. Darparu cyflog cyfartal am waith cyfartal. Atal aflonyddu gan gynnwys aflonyddu rhywiol. Rhaid i gyrff y sector cyhoeddus roi sylw dyledus i ddileu gwahaniaethu, hyrwyddo cyfle cyfartal a meithrin cysylltiadau da. Cyhoeddi data bwlch cyflog rhywedd (250+ o weithwyr).',
  key_provisions_cy = 'Rhan 2 Pen.1: Naw nodwedd warchodedig. Rhan 2 Pen.2: Ymddygiad gwaharddedig — gwahaniaethu uniongyrchol, gwahaniaethu anuniongyrchol, aflonyddu, cosbi. Rhan 5: Darpariaethau gwaith. Dyletswydd i wneud addasiadau rhesymol. Darpariaethau cyflog cyfartal (aa.64-80). Dyletswydd Cydraddoldeb y Sector Cyhoeddus (a.149). Beichir diffynnydd i brofi ar ôl i achos prima facie gael ei sefydlu (a.136).',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = '29d02fd7-9b0c-4645-9a03-4beca967ce69';

UPDATE legislation_library SET
  title_cy = 'Rheoliadau Rheoli Iechyd a Diogelwch yn y Gwaith 1999',
  summary_cy = 'Y prif reoliadau sy''n gweithredu dyletswyddau cyffredinol o dan Ddeddf Iechyd a Diogelwch yn y Gwaith 1974. Yn ei gwneud yn ofynnol i gynnal asesiadau risg, penodi personau cymwys, sefydlu gweithdrefnau argyfwng, darparu gwyliadwriaeth iechyd a chydweithredu yn y gweithle. Yn gweithredu Cyfarwyddeb Fframwaith yr UE 89/391/EEC.',
  obligations_cy = 'Cynnal ac archifo asesiadau risg. Penodi cynghorwyr iechyd a diogelwch cymwys. Sefydlu gweithdrefnau argyfwng. Darparu gwyliadwriaeth iechyd lle bo''n ofynnol. Darpariaethau amddiffyn arbennig ar gyfer mamau newydd a disgwylgar.',
  key_provisions_cy = 'Rh.3: Asesiad risg (ysgrifenedig os 5+ o weithwyr). Rh.5: Trefniadau iechyd a diogelwch. Rh.6: Gwyliadwriaeth iechyd. Rh.7: Personau cymwys. Rh.8: Gweithdrefnau argyfwng. Rh.10: Gwybodaeth i weithwyr. Rh.13: Hyfforddiant. Rh.16-18: Mamau newydd a disgwylgar.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = 'e62e99b9-846a-45f5-8807-7ab17ac4e77d';

UPDATE legislation_library SET
  title_cy = 'Deddf Undebau Llafur a Chysylltiadau Llafur (Cydgrynhoad) 1992',
  summary_cy = 'Y prif ddeddfwriaeth sy''n llywodraethu undebau llafur, bargeinio cyfunol, camau diwydiannol a chymdeithasau cyflogwyr ym Mhrydain Fawr. Yn cwmpasu cydnabyddiaeth undebau llafur, hawliau bargeinio cyfunol, gweithdrefnau camau diwydiannol cyfreithlon, diswyddo annheg am weithgareddau undeb llafur, a rhwymedigaethau gwybodaeth/ymgynghori. Cydsyniad Brenhinol 16 Hydref 1992.',
  obligations_cy = 'Rhaid i gyflogwyr: beidio â diswyddo na pheri niwed i weithwyr am aelodaeth neu weithgareddau undeb llafur. Cydnabod undebau llafur annibynnol lle dangosir cefnogaeth fwyafrif. Datgelu gwybodaeth ar gyfer bargeinio cyfunol. Ymgynghori ar doriadau cyfunol (20+ o weithwyr o fewn 90 diwrnod). Caniatáu amser rhesymol i ffwrdd ar gyfer dyletswyddau undeb llafur.',
  key_provisions_cy = 'Rhan III: Hawliau o ran aelodaeth undeb (aa.137-177). Rhan IV: Cysylltiadau diwydiannol — bargeinio cyfunol, cydnabyddiaeth (Atodlen A1), datgelu gwybodaeth. Rhan V: Camau diwydiannol — imiwned (a.219), gofynion pleidlais (aa.226-235). Rhan VII: Diswyddo annheg am resymau undeb llafur (yn awtomatig annheg).',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = '1d87b8fb-1837-4c40-b194-e7b50bc4c95a';

UPDATE legislation_library SET
  title_cy = 'Deddf Hawliau Cyflogaeth 1996',
  summary_cy = 'Conglfaen cyfraith cyflogaeth unigol y DU. Yn sefydlu''r fframwaith statudol ar gyfer diswyddo annheg, taliadau diswyddo, amddiffyn cyflogau, datganiadau ysgrifenedig o gyflogaeth, cyfnodau rhybudd, a hawliau absenoldeb teuluol. Cydsyniad Brenhinol 22 Mai 1996. Yn cael ei ddiwygio''n sylweddol gan Ddeddf Hawliau Cyflogaeth 2025.',
  obligations_cy = 'Rhaid i gyflogwyr: darparu datganiad ysgrifenedig o fanylion cyflogaeth. Peidio â gwneud didyniadau anawdurdodedig o gyflogau. Dilyn gweithdrefn deg ar gyfer diswyddiadau. Talu diswyddo statudol. Caniatáu ceisiadau gweithio hyblyg. Darparu absenoldeb teuluol. Peidio â diswyddo na niweidio gweithwyr am chwythu''r chwiban neu arfer hawliau statudol.',
  key_provisions_cy = 'Rhan I: Manylion cyflogaeth. Rhan II: Amddiffyn cyflogau. Rhan IVA: Datgeliadau gwarchodedig/chwythu''r chwiban. Rhan V: Amddiffyniad rhag anfantais. Rhan VIII: Absenoldeb mamolaeth a theuluol. Rhan VIIIA: Gweithio hyblyg. Rhan IX: Taliadau diswyddo. Rhan X: Diswyddo annheg — hawl i beidio â chael eich diswyddo''n annheg (a.94), cyfnod cymhwyso 2 flynedd (yn gostwng i 6 mis Ionawr 2027).',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = '6509408b-c7bc-48c5-9c0c-20990025f074';

UPDATE legislation_library SET
  title_cy = 'Deddf Iechyd a Diogelwch yn y Gwaith ayb 1974',
  summary_cy = 'Y prif ddeddfwriaeth sy''n llywodraethu iechyd, diogelwch a lles yn y gweithle ym Mhrydain Fawr. Yn sefydlu''r ddyletswydd gyffredinol ar gyflogwyr i sicrhau, hyd y mae''n rhesymol ymarferol, iechyd, diogelwch a lles yn y gwaith eu holl weithwyr. Cydsyniad Brenhinol 31 Gorffennaf 1974. Y Ddeddf riant y gwneir cannoedd o reoliadau iechyd a diogelwch penodol oddi tani.',
  obligations_cy = 'Rhaid i gyflogwyr: sicrhau iechyd, diogelwch a lles gweithwyr hyd y mae''n rhesymol ymarferol. Darparu a chynnal offer ac offer diogel. Sicrhau trin sylweddau''n ddiogel. Darparu gwybodaeth, cyfarwyddyd, hyfforddiant a goruchwyliaeth. Cynnal gweithle diogel. Paratoi polisi iechyd a diogelwch ysgrifenedig (5+ o weithwyr). Ymgynghori â chynrychiolwyr gweithwyr.',
  key_provisions_cy = 'Adran 2: Dyletswydd gyffredinol i weithwyr — sicrhau iechyd, diogelwch a lles hyd y mae''n rhesymol ymarferol. Adran 3: Dyletswydd i bobl nad ydynt yn weithwyr. Adran 4: Dyletswydd personau sy''n rheoli safle. Adran 7: Dyletswydd gweithwyr i gymryd gofal rhesymol. Adran 33: Troseddau. Adran 37: Atebolrwydd cyfarwyddwyr. Adrannau 15-50: Yr ASB a''r fframwaith gorfodi.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = '96bd3ed2-dd5a-42b2-bea2-567d71013cc7';

UPDATE legislation_library SET
  title_cy = 'Deddf Hawliau Cyflogaeth 2025',
  summary_cy = 'Y diwygiad cyfraith cyflogaeth mwyaf arwyddocaol mewn cenhedlaeth. Cydsyniad Brenhinol 18 Rhagfyr 2025. Gweithrediad wedi''i raddio dros 2026-2027. Prif ddiwygiiadau yn cynnwys: lleihau''r cyfnod cymhwyso diswyddo annheg i chwe mis o Ionawr 2027; dileu''r cap statudol ar iawndal diswyddo annheg; cyfyngu ar dân a chyflogi o''r newydd; cyflwyno oriau gwarantedig ar gyfer gweithwyr dim-oriau; cryfhau hawliau undeb llafur; sefydlu''r Asiantaeth Gwaith Teg.',
  obligations_cy = 'Gweithrediad wedi''i raddio: Ebrill 2026 — SSP a thadolaeth yn hawliau dydd-un; Asiantaeth Gwaith Teg yn lansio. Hydref 2026 — hawliau mynediad undeb llafur. Ionawr 2027 — cyfnod cymhwyso 6 mis; cyfyngiadau tân a chyflogi o''r newydd; cap iawndal wedi''i ddileu. 2027 — oriau gwarantedig; diwygio gweithio hyblyg; absenoldeb profedigaeth; cynlluniau gweithredu menopôs/bwlch cyflog rhywedd ar gyfer cyflogwyr 250+.',
  key_provisions_cy = 'Rhan 1: Cyfnod cymhwyso diswyddo annheg wedi''i leihau i 6 mis. Cap iawndal wedi''i ddileu. Cyfyngiadau tân a chyflogi o''r newydd. Oriau gwarantedig ar gyfer gweithwyr dim/oriau isel. Rhan 2: Hawliau mynediad undeb llafur wedi''u cryfhau. Pleidleisio electronig. Rhan 3: Asiantaeth Gwaith Teg. Terfynau amser tribiwnlys wedi''u hymestyn. Rhan 4: Absenoldeb profedigaeth. Hawliau tadolaeth dydd-un. Dyletswydd aflonyddu rhywiol wedi''i chryfhau.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = 'e7761f3c-949c-473a-a0d4-c250f30cbb88';

UPDATE legislation_library SET
  title_cy = 'Rheoliadau Trosglwyddo Ymgymeriadau (Amddiffyn Cyflogaeth) 2006',
  summary_cy = 'Yn amddiffyn telerau ac amodau gweithwyr pan fo''r busnes y maent yn gweithio iddo yn trosglwyddo i gyflogwr newydd, neu pan fo darpariaeth gwasanaeth yn newid. Yn gweithredu Cyfarwyddeb Hawliau a Gafaelwyd yr UE. Mewn grym 6 Ebrill 2006. Yn trosglwyddo contractau cyflogaeth, parhad gwasanaeth, a chytundebau cyfunol yn awtomatig i''r cyflogwr newydd.',
  obligations_cy = 'Rhaid i''r trosglwyddwr: darparu gwybodaeth atebolrwydd gweithwyr i''r derbynnydd o leiaf 28 diwrnod cyn trosglwyddo. Hysbysu ac ymgynghori â chynrychiolwyr gweithwyr. Rhaid i''r derbynnydd: anrhydeddu telerau ac amodau gweithwyr a drosglwyddwyd. Peidio â diswyddo oherwydd y trosglwyddiad oni bai am reswm ETO. Ymgynghori ar unrhyw fesurau sy''n effeithio ar weithwyr.',
  key_provisions_cy = 'Rheoliad 3: Trosglwyddiad perthnasol — trosglwyddiadau busnes a newidiadau darpariaeth gwasanaeth. Rheoliad 4: Trosglwyddo awtomatig contractau cyflogaeth. Rheoliad 5: Trosglwyddo cytundebau cyfunol. Rheoliad 7: Diswyddo oherwydd trosglwyddiad yn awtomatig annheg oni bai am reswm ETO. Rheoliad 11: Dyletswydd i hysbysu ac ymgynghori. Rheoliad 12: Methiant i hysbysu ac ymgynghori — iawndal hyd at 13 wythnos o dâl.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = 'ba3d43f2-cc79-4cf5-a5c4-ea36075a8e60';

UPDATE legislation_library SET
  title_cy = 'Deddf Mewnfudo, Lloches a Chenedligrwydd 2006',
  summary_cy = 'Yn sefydlu dyletswydd cyflogwyr i wirio hawl i weithio yn y DU ac yn creu cosbau sifil a throseddol am gyflogi gweithwyr anghyfreithlon. Cydsyniad Brenhinol 30 Mawrth 2006. Rhan 3 yn creu system cosb dwy haen: cosbau sifil am gyflogi gweithwyr anghyfreithlon yn esgeulus, a chosbau troseddol am wybod am gyflogi rhywun heb hawl i weithio.',
  obligations_cy = 'Rhaid i gyflogwyr: cynnal gwiriadau hawl i weithio ar bob darpar weithiwr cyn dechrau cyflogaeth. Derbyn dogfennau rhagnodedig yn unig. Cynnal gwiriadau dilynol ar gyfer caniatadau amser-cyfyngedig. Cadw copïau am gyfnod cyflogaeth ac am 2 flynedd wedi hynny. Peidio â gwahaniaethu ar sail hil wrth gynnal gwiriadau.',
  key_provisions_cy = 'Adran 15: Cosb sifil am gyflogi person heb hawl i weithio. Adran 16: Gwrthwynebiad ac apeliadau. Adran 21: Trosedd droseddol am gyflogi gweithiwr anghyfreithlon yn fwriadol. Adran 22: Cod statudol ar osgoi gwahaniaethu wrth gynnal gwiriadau.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = 'a10738e9-7b90-414b-8d10-15fa2f5a3f64';

UPDATE legislation_library SET
  title_cy = 'Deddf Tribiwnlysoedd Cyflogaeth 1996',
  summary_cy = 'Yn sefydlu system Tribiwnlysoedd Cyflogaeth ar gyfer Cymru, Lloegr a''r Alban a''r Tribiwnlys Apeliadau Cyflogaeth. Yn diffinio awdurdodaeth tribiwnlys, cyfansoddiad, gweithdrefn a phwerau. Yn darparu''r fframwaith statudol yr adjudicedir hawliadau diswyddo annheg, gwahaniaethu, cyflogau ac eraill drwyddo.',
  obligations_cy = 'Rhaid i gyflogwyr ymateb i hawliadau tribiwnlys o fewn terfynau amser rhagnodedig. Mae cydymffurfiaeth â gorchmynion a dyfarniadau tribiwnlys yn orfodadwy yn gyfreithiol. Gellir dyfarnu costau tribiwnlys yn erbyn ymddygiad afresymol.',
  key_provisions_cy = 'Rhan I: Tribiwnlysoedd Cyflogaeth — awdurdodaeth, cyfansoddiad, gweithdrefn, costau. Rhan II: Tribiwnlys Apeliadau Cyflogaeth. Adran 18: Cymod ACAS. Adran 21: Rheoliadau ar weithdrefn tribiwnlys.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = '86b43aad-5498-4ae5-90aa-0d762ef59a11';

UPDATE legislation_library SET
  title_cy = 'Deddf Hawliau Dynol 1998',
  summary_cy = 'Yn ymgorffori Confensiwn Ewropeaidd ar Hawliau Dynol i gyfraith ddomestig y DU. Yn ei gwneud yn ofynnol i bob awdurdod cyhoeddus weithredu''n gyson â hawliau''r Confensiwn. Mae darpariaethau cyflogaeth perthnasol yn cynnwys Erthygl 8 (preifatrwydd), Erthygl 9 (crefydd), Erthygl 10 (mynegiant), Erthygl 11 (cymdeithas) ac Erthygl 14 (gwahaniaethu).',
  obligations_cy = 'Rhaid i gyflogwyr y sector cyhoeddus sicrhau bod pob penderfyniad cyflogaeth yn cydymffurfio â hawliau''r Confensiwn. Cyflogwyr preifat yr effeithir arnynt lle maent yn arfer swyddogaethau cyhoeddus. Gwyliadwriaeth yn y gweithle, codau gwisg, a llety crefyddol yn cael eu hasesu yn erbyn cymesuredd.',
  key_provisions_cy = 'Adran 3: Dehongliad yn gyson â hawliau''r Confensiwn. Adran 6: Anghyfreithlon i awdurdod cyhoeddus weithredu''n anghydnaws. Adran 7: Hawl i ddod â chafael. Erthygl 8: Hawl i fywyd preifat. Erthygl 11: Rhyddid ymgynnull a chymdeithas.',
  welsh_available = TRUE, translation_method = 'ai_assisted', updated_at = NOW()
WHERE id = 'b7514925-201f-4a96-9953-d442246dfeef';

