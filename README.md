# Kuningriigid → Godot AutoPort

**Eraldi tööriistaprojekt** veebimängu [orogdor/Kuningriigid](https://github.com/orogdor/Kuningriigid) mängureeglite kontrollitavaks automaatseks ülekandmiseks Godot 4 mootorisse.

See projekt **ei muuda** Three.js veebimängu ega olemasolevat Godoti arendusharu. Lähtekoodi loetakse avalikust `main` harust. Praegune 0.2.0 ekspordib automaatselt mängureegleid ja võrdleb kuut käsitsi GDScripti portitud arvutusfunktsiooni tegeliku JavaScripti lähtekoodiga. See ei ole täielik JS → GDScript konverter, 3D mäng ega Androidi APK.

## Esimene töövõimeline osa

`tools/port.mjs` loeb ja ekspordib 15 rühma mänguandmeid:
- 111 V118 tehnoloogiapuu kirjet (tingimused ja ajastud);
- V125 uued tehnoloogiad ja tootmisreformid;
- kaubad, erikauba tootmishooned ja seitsme ajastu linnatarbed;
- kuue ajastu materjalihinnad ning tehnoloogia-ajastu vastendused;
- pronksiaja minimaalne kestus ja müüride rahvaarvulävendid;
- teaduse algväärtused ja Eureka osakaal.

Genereeritud JSON-andmed asuvad `game/data/generated/`. Iga väljundiga käib kaasas algse faili SHA-256, genereeritud faili räsi, algse GitHubi commit ja tabeli nimi. `tools/verify-parity.mjs` kontrollib nende võrdsust sõltumatult.

Konverter **ei käivita** lähteprojekti JavaScripti; see tunneb ainult staatilisi literaale ja keeldub programmiavaldistest, muutuja viidetest ning tundmatutest sõltuvustest. Nii ei saa töövoog märkamatult tõlkida vale andmestruktuuri.

## Käivitamine oma arvutis

Vajalik: Node.js 20+ (soovitatavalt 22+), Git; Godot 4.4+ ainult näidisvaate avamiseks.

```bash
git clone https://github.com/orogdor/Kuningriigid.git upstream
npm test
npm run port -- --source upstream --out game/data/generated
npm run parity -- --source upstream --out game/data/generated
```

Ava `game/project.godot`, et näha eksporditud tabelite lugemist toimivas Godoti stseenis. See ei ole veel mängitav kampaania.

## GitHub Actions

`.github/workflows/sync-upstream.yml` käivitub töövoo käsitsi avamisel, uue repositooriumi `main` haru koodimuudatusel ja iga päev:

1. Checkout sellest projektist ja avaliku Three.js mängu `main` harust.
2. Käivita Node.js turva-, stabiilsus- ja terviklustestid.
3. Ekspordi 15 andmerühma täpselt viidatud lähtecommitist.
4. Kontrolli lähte-väljundandmete võrdsust ja sõltuvusi.
5. Kontrolli Godot 4.4.1 skriptide importi ja peastseeni laadimist.
6. Commit'i genereeritud andmed **ainult siia reposse**, kui andmed muutusid.
7. Lisa genereeritud reeglifailid GitHub Actionsi artefaktina.

Automaattöövoog on kavandatud nii, et algse mängu reeglite muutumisel ebaõnnestub vale teisendus nähtavalt, mitte ei muudeta mängu vaikselt.

## AutoPort 0.2.0: mänguarvutuste kontroll

Godotisse on viidud kuus eraldiseisvat arvutusreeglit: linnade arvu piirang, asunike loomise reeglid, armeede mahupiirang, teaduse ajastupõhine kulukordaja, linnade teaduskordaja ning pronksi-/rauaaja jõuka linna kasv.

Iga GitHub Actionsi töövoog loeb originaalseid JavaScripti mooduleid otse veebimängu `main` harust, genereerib nende tulemustest 864 deterministlikku testjuhtumit ning kontrollib Godot 4.4.1 headless-režiimis, kas GDScripti väljundid on samaväärsed. Pariteedihälve peatab töövoo. Sünkroonimiskontroll on seadistatud iga 6 tunni järel (GitHub võib käivitusi edasi lükata).

Olulised failid: `game/scripts/logic_v02.gd`, `game/tests/logic_parity.gd` ja `tools/generate-logic-fixtures.mjs`. Automaatne tulemus asub Actionsi logis; APK ei ole veel loodud.

## Järgmised etapid

1. **Puhas arvutusloogika:** majanduse, teaduse ja toiduvaru funktsioonide pariteeditestid Node.js ja GDScripti vahel.
2. **Simulatsiooniseisundi teisendus:** linna varud, asunikud, elanikkond, uurimistöö, kaubandus ja AI.
3. **200 käigu võrdlus:** kontrollitavad identsed lähteseisud ja mängutulemused.
4. **Godoti visuaalid:** detailkaart, maailmakaart, 3D hooned, mobiili UI ja üksused.
5. **Android:** alles seejärel APK ning uuendussüsteem ja telefonitestid.

**Oluline:** kontrolltabelite edukas import ei tähenda, et kogu Three.js mängumehaanika oleks Godotisse üle kantud. Ka käsitsi Godoti-spetsiifilist tööd jääb vaja.

## AutoPort 0.3: Windows EXE, Android APK ja uuendatav sisupakett

Püsivad käivitajad on saadaval [GitHubi viimases väljalaskes](https://github.com/orogdor/Kuningriigid-Godot-AutoPort/releases/latest): `Kuningriigid.exe` (Windows x64), `Kuningriigid.apk` (Android ARM64) ja `Kuningriigid-Content.pck` (mõlema mängusisu).

Käivitaja küsib igal avamisel avalikust GitHub Releases API-st viimast väljalaset, leiab `Kuningriigid-Content.pck` SHA-256 räsi, võrdleb seda oma vahemäluga, laadib muutunud paketi alla ja kontrollib SHA-256 täpset vastavust enne laadimist. Kui võrku pole, avaneb varem kontrollitud või APK/EXE kaasa pandud sisu. Pakett laaditakse läbi `ProjectSettings.load_resource_pack()` ja seejärel käivitatakse `res://content.tscn`. Käivitaja ise ei kirjuta APK-d ega EXE-d üle.

Automaatne ehitus: `.github/workflows/build-apps.yml` ekspordib Godot 4.4.1 abil Windowsi EXE, Androidi test-APK ja PCK, lisab kontrollsummad ning avaldab GitHub Releases'i. Lisaks kontrollib see lõpetatud ajastatud veebimängu sünkroonimist ja jätab muutumata lähtekoodi korral kordusväljalaske tegemata.

**Piirangud:** Androidi test-APK allkirjastatakse iga CI ehituse ajutise debug-võtmega. Sisupaketi uuendamine ei vaja uut APK paigaldamist, kuid uue APK versiooni installimine eelmise peale võib allkirja erinevuse tõttu nõuda vana APK eemaldamist. Päris ametlikuks APK uuendamiseks tuleb seadistada püsiv, salajas hoitav allkirjastamisvõti GitHubi Secrets'isse; seda ei tohi repositooriumis avaldada. Windowsi ja Androidi koodiga seotud mootoriparandused nõuavad mõnikord uue APK/EXE käsitsi paigaldamist. Praegune mängusisu on endiselt pordi kontrollrakendus.

## AutoPort 0.4 — Windowsi väike käivitaja ja päris failistruktuur

Uus [Windowsi `Kuningriigid.exe`](https://github.com/orogdor/Kuningriigid-Godot-AutoPort/releases/latest) on **ligikaudu 5,7 MiB käivitaja**, mitte 93 MB sisseehitatud mootor. Esmakäivitus vajab internetti: programm võtab GitHubi viimasest väljalaskest `Windows-files.json` ja eraldi `Kuningriigid-Engine.exe` (u 149 MiB), salvestab Godoti mootori oma `runtime` kausta ning laeb GitHubi kindla commit'iga seotud mängufailid eraldi koos SHA-256 kontrolliga.

Iga järgnev avamine kontrollib GitHubi uusimat väljalaset. Muutumata failid kopeeritakse eelmisest versioonist; ainult muutunud allalaetavad failid võetakse kinnitatud Git-commit'ist. Lõpetamata uuendus ei asenda töötavat versiooni ja ilma internetita saab käivitada eelmise kohapeal olemas oleva versiooni. Windowsis kasutatakse lahtiseid `.gd`, `.tscn`, `.godot` ja `.json` faile; Android jääb praegu senisele pakitud `.pck` uuendusele.

Pärast esmakäivitust loob käivitaja oma EXE kõrvale sellise kataloogistruktuuri:

```text
Kuningriigid.exe                     # väike Windowsi käivitaja
Kuningriigid-Data/
  active.json                        # viimati edukalt paigaldatud versioon
  runtime/
    <godot-sha256>/
      Godot.exe                      # mootor, laaditakse esimesel korral
  versions/
    <repo-commit-sha>/
      manifest.json                  # kohaliku mängu failiräside loend
      game/
        project.godot
        main.tscn
        content.tscn
        scripts/
          content.gd
          logic_v02.gd
          ...
        data/
          generated/
            tech_tree.json
            goods.json
            ...
```

GitHub Actions ehitab EXE ja Androidi APK, genereerib Windowsi manifesti ning avaldab mootorifaili ja APK/PCK eraldi. [Kontrollitud 0.4.26 väljalase](https://github.com/orogdor/Kuningriigid-Godot-AutoPort/releases/tag/v0.4.26) sisaldab kuut faili: väike EXE, Windowsi mootor, manifest, APK, PCK ja kontrollsummad. Kui EXE on kirjutuskaitstud kataloogis (näiteks Program Files), ei pruugi kohapealsete failide loomine õnnestuda; käivita alguses tavalisest kirjutusõigusega kaustast.

**Piirang:** kinnitatud on GitHub Actionsi Windowsi käivitaja koostamine, 29-failise manifesti genereerimine, Godoti impordi test ning APK ehitamine. Tegelikku esmakäivitust Windowsi graafilisel töölaual tuleb veel eraldi kontrollida. Godoti port ise näitab praegu reeglite eelvaadet, mitte veel mängitavat maailma.

**Windowsi integratsioonitest läbitud 25.10.2026:** [GitHub Actions #40174914067](https://github.com/orogdor/Kuningriigid-Godot-AutoPort/actions/runs/40174914067) tõmbas esmakäivitusel alla käivitaja, eraldi Godoti mootori ja mängufailid, kontrollis päris failistruktuuri, käivitas Godoti projekti peata režiimis ning kinnitas teise käivituse ilma internetita. Mängu täielikku kasutajaliidest pole veel eraldi testitud.

## AutoPort 0.5 — mängitav kiviaja linnamajandus

`game/scripts/city_sim_v05.gd` sisaldab ühe linna GDScripti majandussimulatsiooni. `game/scripts/content.gd` pakub interaktiivset ehitusmenüüd, hoonete töö- ja ehitusstaatust, varusid, elanike ja majade mahtu, toitlustust, veevaru, teaduse baasmäära, 1/10/200 käigu nuppe, automaatset käiguvahetust ning salvestust `user://autoport_city_v05.json` kaudu.

Mänguajad: üks käik on üks mänguminut; toidukulu `0,60` ja veekulu `0,45` elaniku kohta minutis, linnahalli mahutavus `4` ja elamu lisamahutavus `1,5`. Majanduse tootmistsüklid, ehituskulud, hoonete nõuded, töötajate tõhusus ja elanike kasv on võetud originaalist `economy.js`, `labor.js` ja kontrollitud `civilization-core.js` muudatustest. Veebimängu ennast ei muudeta.

**Pariteedikontroll:** `tools/generate-city-v05-fixtures.mjs` käivitab originaalse `economy.js::tickEconomy()` kuues stsenaariumis **200 järjestikust käiku** ning `game/tests/city_v05_parity.gd` kontrollib kõiki 1200 tulemust Godoti enda arvutustega. Test hõlmab tootmist, tööliste jaotust, ehituse valmimist, toidu/vee tarbimist, puudusest tingitud elanike vähenemist ja turu- ning jõukusboonust. `game/tests/city_v05_ui.gd` kontrollib stseeni käivitamist, hoone ehitamist, kümmet käiku ja salvestust. Mõlemad testid peavad läbima GitHub Actionsi enne uut väljalaset.

**Oluline piirang:** see on sihilikult piiratud, aga reeglitruu *ühe linna* majanduskatse. Allalaaditav linn ei ole veel 3D-maailm ega terviklik RTS. Simulatsioonis jõuavad kaubad abstraktselt kohe lattu, maardlate ammendumist, kaugtranspordi, põldude geomeetriat, AI linnade otsuseid ja sõdu veel ei arvutata. Teadus on näidatud elanike baasmäärana, täielik avastuste uurimine on alles lisamata. AutoPort 0.5 alustatakse vana käivitajaga uue sisupaketina; Windows saab üksikfailid GitHubist ja Android jätkab PCK uuendust.


## AutoPort 0.6 — maailmakaardi esimene mängitav vaade

Godoti maailmakaardi moodulid:
- `game/scripts/world_gen_v06.gd`: veebimängu `continent-map.js` seemnepõhise mandri-/saaregeomeetria ja nelja lähteasukoha otsene ülekanne, 220 × 165 ruutu ning Godoti esmane kõrgustiku, ranniku ja jõgede arvutus. Jõgede äravool on prioriteet-üleujutuse põhimõttel nagu `world-geography.js`.
- `game/scripts/world_canvas_v06.gd`: kaarditekstuur, mäed, metsad, rannad, jõed, riikide asukohad; hiirerattaga suum, lohistamine, ruudule klõpsamine ja telefoni ühe sõrmega liigutamine.
- `game/scripts/world_map_v06.gd`: kaardi infopaneel, uus maailma seeme, suumikaardi lähtestamine, valitud ruudu info ja ühendus 0.5 linnamajandusega.
- `game/scripts/content.gd`: maailmakaardi ja olemasoleva linnavaate vahel liikumine. 0.5 majanduse salvestus jääb alles.

**Võrdlustestid:** `tools/generate-world-v06-fixtures.mjs` arvutab originaalse `continentLayout` järgi kuus maailmakonfiguratsiooni ning `game/tests/world_v06_parity.gd` nõuab sama mandrite/saarekeste polygoniseerimist ja eraldatud stardikohti Godotist. `game/tests/world_v06_ui.gd` kontrollib 220 × 165 ruudu olemasolu, nelja stardikohta, jõgede äravoolu, ruuduvalikut ja linnavaatesse liikumist. Samuti peavad varasemad 0.5 majandustestid läbima kõik kontrollid enne APK/EXE väljalaset.

**Piirangud:** mandrite/saarekeste paigutus kattub originaaliga, kuid kõrguse müra, osa rannajoonest ning reljeef ei ole veel `continentHeight` 1:1 port. Kaart on praegu kahemõõtmeline strateegiavaade. Jõed on äravooluvõrguga, aga nende visuaalne jõesäng ja 3D detailreljeef pole veel üle kantud. Neli alguskohta on kaardile märgitud, kuid ülejäänud riikide linnade majandust ega AI-d pole veel ühendatud. Mängitav linnamajandus on endiselt üks eraldi prototüüplinn.


## AutoPort 0.7 — kiviaegse linna 3D detailkaardi prototüüp

- `game/scripts/detail_view_v07.gd`: valitud maailmaruudu iseseisev Godoti 3D vaade (detailala ~225 × 195 meetrit) koos maapinna, künklikkuse, mere, jõelõigu, puude ja kividega. 3D geomeetria on praegu Godoti lihtsatest algkujunditest; täpsed veebimängu mudelid ja kõrguskaardi parity tulevad hiljem.
- `game/scripts/detail_camera_v07.gd`: pööratav ja suumitav kaamera hiirega, telefoni sõrmega pööramine.
- Eristatavad kiviaja 3D prototüübid: peahoone (hall), elumaja (house), metsamaja (lumber), kaev (well), kivimurd (quarry), põld (farm). Teisi olemasolevaid tootmishooneid näidatakse ajutise töökojamudelina.
- Maailmakaardil saab valida ruudu ja vajutada **Ava 3D detailkaart**. Tagasi maailmakaardile saab detailvaate nupuga.
- Ehitamine on prototüübis lubatud ainult mängija esimese riigi pealinna maailmaruudul. Ehituskulu, ehituse valmimine, 10 käigu liigutamine ja linna salvestamine kasutavad olemasolevat 0.5 majandussüsteemi. Mujal saab detailmaastikku vaadata.
- `game/tests/detail_v07_ui.gd` kontrollib 3D maastiku ilmumist, linna peahoone kujutamist, metsamaja ehitamist ja ressursikulu, 10-käigulist valmimist, salvestamist, maailmakaardile naasmist ja valesse ruutu ehitamise keeldu. Enne väljalaset jäävad kehtima 0.5 majandus- ja 0.6 maailmakaardi testid.

**Piirangud:** tegu on toimiva 3D vaate ja linnamajandusega seotud ehitusprototüübiga, mitte veel veebimängu 1:1 detailkaardiga. Füüsilised töölised ja rajaleidmine, hoonete täpne ruumipõhine paigutus, maavarade ammendumine, mitu linna, AI ja lahingud puuduvad. Windowsi väikese käivitaja failihaaval uuendused ja Androidi PCK jäävad samaks.


## AutoPort 0.8 — detailkaardi ehituskohad ja füüsiline kogumine

AutoPort 0.8 laiendab 0.7 3D detailkaarti, säilitades 0.5 majanduse ja 0.6 maailmakaardi:

- `game/scripts/spatial_economy_v08.gd` lisab pealinnale päris X/Z ehituskoordinaatidega 10 m sammuga ehitusruudud, hoonete kattumise kontrolli, piiratud metsa- ja kivivarud ning iga töötaja töö ja koju tagasiliikumise.
- `game/scripts/detail_camera_v07.gd` kasutab paremklõpsuga kaamera pööramist ja vasakklõpsuga detailkaardi ehituskoha valimist (telefonis ühe sõrmega puudutus/lohistamine). Nupp `Ehita <hoone>` valib hoonetüübi, klõps paigutab selle rohelisele vabale ruudule.
- `game/scripts/detail_view_v07.gd` kuvab tegelikud ehituskrundid, etteantud puude ja kivide ressursisõlmed, liikuvad töölised ja kaasaskantava materjali.
- `game/scripts/city_sim_v05.gd` kasutab 0.8 aktiveeritud pealinnas metsamaja ja kivimurru materjalide krediteerimiseks ainult tegelikult töötaja poolt koju toodud kaupa. Kui mõlemasse kaevandusse kuuluv ressurss otsa saab, kaob vastav tootmine. Füüsilist süsteemi pole 0.5 JS-pariteedistsenaariumides aktiveeritud; vanad 1200 käigu võrdlustestid jäävad kehtima.
- `game/tests/detail_v08_ui.gd` kontrollib hoone paigutust klõpsuga, varude kulumist, tööliste liikumist ja toodangu laekumist, hoone kattumise keeldu, kivimurru töötajat, salvestamist ja maailmakaardile naasmist.

**Ulatuspiirang:** tegemist on algelise sõlmede vahel liikuva kogumissüsteemiga, mitte veel originaalse veebimängu 1:1 tööliste rajaleidmise, lõpliku metsade taassünni, 3D inimese animatsioonide või töökohtade täieliku tööjõuloogikaga. 0.8 aktiveerub pealinna detailkaardi avamisel ning tööliste tootmine jätkub pärast seda ka linnamajanduse ekraanil käike vahetades. Liikumine on hetkel käigupõhine, mitte sujuvalt animeeritud.


## AutoPort 0.9 — 3D tööliste rajaleidmine ja loomulikult tekkivad teed

0.9 jätkab 0.8 pealinna detailkaardi füüsilise tootmise süsteemi:

- `game/scripts/spatial_paths_v09.gd`: 10-meetrise sammuga A*-teekonnaotsing 17 × 17 ruudustikul, hoonete ümbruse läbimatuse kontroll, diagonaalsest nurkast läbilõikamise keelamine ja vajaduse korral uue marsruudi arvutamine pärast ehitamist. Jõesängi lihtsustatud reservatsioon jätab etteantud madalad ületuskohad (0.9 ei ole veel täielik ülemaailmne teede/vee/maastiku 1:1 port).
- `game/scripts/spatial_economy_v08.gd`: metsamaja ja kivimurru töölised valivad ligipääsetava ressursisõlme, liiguvad sinna ja tagasi rajaleidmisega, krediidivad materjali laovarus alles tagasijõudmisel. Igast läbitud ruudust jääb liiklussageduse jälg.
- `game/scripts/detail_view_v07.gd`: läbikäidud radade kuvamine pruuni 3D maapinnaribana; liikuvad töölised interpoleeritakse tween-animatsiooniga järgmisse käigupõhisesse asukohta.
- **Teede dünaamika:** rada kuvatakse alates kolmest läbimisest; liiklussagedus koguneb kuni kindla maksimumini ning väheneb 35 mängukäigu pikkuste kasutuspauside järel. Korduvalt kasutatud teel on marsruudivalikul väike kulueelis. See ei ole veel veebimängu täpne teevõrk, kuid tekib mängureeglitest, mitte suvalisest visuaalist.
- `game/tests/spatial_paths_v09.gd`: kontrollib teekonda ümber hoone, diagonaalsete nurkade vältimist, liiklusega teede teket, tee hääbumist, JSON-salvestust ning 0.8 salvestuse migratsiooni. Samuti jooksevad jätkuvalt 0.5 majanduse ja 0.6 maailma pariteeditestid.

**Ulatuspiirang:** töötajad liiguvad praegu arvutatud rajal diskreetsete strateegiakäikudega, kuid kuvatavad mudelid liiguvad käikude vahel sujuva animatsiooniga. Täielikke sujuvaid pärisaja üksusi, 3D füüsikaga rajaleidmist, sildu, teede maailmakaardi/detailkaardi sünkrooni ja sõjalist AI-d pole veel üle kantud.


## AutoPort 0.11 — päris ehitustöölised ja ehituse etapid

0.11 jätkab Godoti 0.10 ruumilist majandusprototüüpi. `game/scripts/construction_v11.gd` loob iga poolelioleva hoone juurde tegeliku ehitustöölise, kes alustab peahoone juurest, leiab A*-teekonna vabasse ehitusplatsi kõrvalasukohta ning ehitab ainult kohal olles ja majandussüsteemis määratud tööjõu korral. Töötajad jagatakse pärast ehituse valmimist järgmisele tööle; nende asukoht, ülesanne ja käimisrada salvestatakse olemasoleva `detail_sim` alla (skeem 4).

Hooned arenevad vähemalt kolme aktiivse ehituskäigu vältel. Visuaal muutub vundamendist karkassiks ja seinteks ning alles valmis hoone kasutab lõplikku 3D mudelit. `game/scripts/detail_view_v07.gd` joonistab ehitajad sinise riietuse ja lihtsustatud töövarustusega ning liikumine on sujuvamaks tween'itud.

Majanduses lisatud ehitustöölised kasutavad olemasolevat töötajate jaotusvalemit, nii et tööjõupuudus aeglustab ehitamist. 0.11 sekkub ainult avatud 3D detailkaardiga pealinna majandusolekusse. Originaalse veebimängu 0.5 pariteetmudel ja 1200 järjestikust JavaScripti referentskäiku jäävad muutmata.

**Testid:** `game/tests/construction_v11.gd` kontrollib ehitaja päris liikumist, tööetappe, töötaja taaskasutust, salvestust, 3D vundamendi ja töötajamudeli olemasolu ning hoone lõpuleviimist. GitHubi automaattestid kontrollivad ka 0.5–0.10 funktsioone, APK/EXE ehitamist ja Windowsi käivitajat.

**Piirangud:** konstruktsioonielemendid ja töötajad on esialgsed primitiivmudelid, mitte ajalooliselt viimistletud 3D varad. Ehituse füüsiline materjalivedu, mitme ehitustöölise koostöö sama hoone juures ning kõigi linnade samaaegne AI-ehitus on järgmised portimisetapid. Üks käik jääb üheks mänguminutiks.


## AutoPort 0.13 — ehitusjärjekorra prioriteedid ja laiem logistika

Versioon 0.13 lisab pealinna Godoti 3D detailvaates ehitusobjektidele **low / normal / high** prioriteedi. Poolelioleva hoone järel olev nupp vahetab tasemeid, see salvestatakse linna JSON-seisu. `game/scripts/construction_scheduler_v13.gd` jagab piiratud hulga ehitustöölisi kõigepealt kõrge, seejärel tavalise ja lõpuks madala prioriteediga ehitusprojektidele. Ühe hoone juurde lubatakse endiselt kuni kaks ehitajat, kuid mitmel objektil võivad töötajad tegutseda paralleelselt. Töölisi ei teki rohkem kui linnas on elanikke.

Juba materjalikoormaga teel olev ehitaja lõpetab vana objekti veo ka siis, kui objekti prioriteet muutub. Uuesti jagatakse ainult koormata tööjõudu; seega ei kao või dubleeru tellimisel juba tasutud materjal. `game/scripts/construction_v12.gd` võtab nüüd füüsilise ehituskaubana arvesse kõiki positiivse kogusega *mitte-toidu* materjale, mitte ainult puitu, kivi ja laudu. Leiva/toidu kulu jääb tellimisel tarbimiseks. Puuduolevaid kaupu ei tellita automaatselt ning füüsiline veosimulaator arvestab juba tellitud kaubaga.

Vanad 0.12 salvestused saavad puuduvaks prioriteediks `normal`, varu, ehitusprogress ja senised marsruudid säilivad. 0.13 kontrollid on `game/tests/construction_v13.gd`: tööjõu prioriteetne jaotus, kahjuta veovahetus, kahe samaaegse ehituse valmimine, eri materjalide transport, varasema skeemi migratsioon ja 3D prioriteedinupu püsimine pärast salvestamist. Kõik 0.5–0.12 olemasolevad testid jäävad väljalaske eeldusteks.

**Piirang:** praegu on see ühe mängija pealinna tööjõu/kaubaveo prototüüp. Täielik kaupade logistika eri linnade ja maakondade vahel, loomad/veokärud, töötajate animatsioonide viimistlus ja AI ehitusprioriteetide juhtimine on veel portimata.


## AutoPort 0.14 — kaupade füüsiline vedu tootmisest lattu

Godoti 0.14 lisab tootmishoonete valmis kaupadele tegeliku 3D transpordi. `game/scripts/freight_v14.gd` loob järjekorra, milles on saatjahoone, kauba liik ja kogus. Talude, saekaatrite ning teiste 0.5 majandusretseptide toodang kantakse linna lattu **alles siis**, kui vagun on kaubaga tagasi peahoone juurde jõudnud. Kaubavedu ei muuda algse veebimängu ühes keskpunktis toimuva 0.5 võrdlusmudeli käike, sest uus süsteem töötab ainult pärast 3D detailkaardi aktiveerimist.

Korraga töötab kuni kaks lihtsustatud 3D veoüksust, ühe koorma maht on 12 kaubaühikut. Veol kasutatakse olemasolevat `spatial_paths_v09.gd` rajaleidmist, hoonete vältimist ja jõe ületuskohti. Sissekäidud tee peal kiireneb veoliikumine 20%, kaupade tegelik kohaletoimetamine omakorda lisab teedele kasutussagedust. `game/scripts/detail_view_v07.gd` kuvab lihtsustatud vankrid (kere, rattad, juht ja koorem) ning pealinna teabereal ootel ja teel oleva kauba.

**Säilivus:** järjekorras ootav kaup + koormas olev kaup + lattu saabunud kaup peab võrduma tootmishoonete väljastatud kogusega. Selleks salvestatakse järjekord, vankrite asukohad, koormad ja kohaletoimetamiste ajalugu olemasolevasse `detail_sim` andmestikku (skeem 7). Vana salvestus ilma veojärjekorrata avatakse tühja järjekorraga, kaotamata olemasolevaid linnavarusid ja tööjõudu. Kontrolli `game/tests/freight_v14.gd` raames tehakse nii talu kui ka saeveski transport, teedest tekkiv liikumiskiiruse muutus, kaupade säilivus, 3D vanker ja salvestustest.

**Piirangud:** esialgu kantakse vankriga tootmishoonetest kesklattu valmis toodang, kuid 0.8 metsa- ja kivimurru tooraineresursside kogumissüsteem krediteerib lao endiselt töökoja juurde jõudes. Sissetulevate tootmissisendite füüsiline vedu, käruveo tööjõu üksikasjalik kulu, kaupmehed ja mitme linna vaheline logistika on järgmised etapid. 3D vankrid on prototüüpmudelid, mitte ajalooliselt viimistletud veovahendid.


## AutoPort 0.15 — tootmissisendite transport, tööjõukulu ja esimene kaubalinn

Godoti pealinna 3D-majanduses peavad saeveski, veski ja pagarikoja **sisendkaubad** nüüd jõudma peahoonest töökotta vankriga. Kui tootmistsükkel vajab toorainet, reserveeritakse ja lahutatakse see keskladu varust **ainult ühe korra**. Toodangut ei teki enne tegelikku kohaletoimetamist. Sisendite ja väljundkaupade veojärjekord teenindab mõlemat suunda vaheldumisi, et üks tootmisahel ei takistaks teisi. Olemasolev 0.14 toodangu vedu lattu säilib.

Aktiivsed vankrijuhid võtavad Godoti 3D-pealinnas osa linna tööjõust: väikeses linnas on korraga üks, vähemalt kaheksa elanikuga linnas kuni kaks veoüksust. Tööhõive arvestus vähendab saadaval olevat tootmistööjõudu. Vankrid kasutavad jätkuvalt A*-rajaleidmist, teid ja jõgede ületuskohti. Sisendite tellimused, laadungid ja nende saabumine kuuluvad salvestatavasse `detail_sim` skeemi 8. Vanade mänguseisude majandusvarusid ümber ei arvestata.

Lisaks on `game/scripts/two_city_trade_v15.gd`: **teise linna kaubalao prototüüp**. Linnamajanduse menüü alt saab tasu eest avada teise asula lao ning käsitsi saata 5 ühikut puitu või leiba pealinnast sinna ja puitu tagasi. Karavan võtab kuus mängukäiku, kaup lahutatakse lähtevarust väljumisel ning saabub sihtkoha eraldi lattu alles kohale jõudes. Teel olev karavan salvestatakse. See on **kahe lao ja kaubakaravani vertikaallõik**, mitte veel teine täisväärtuslik ehitatav või AI juhitud linn ega ka maailmakaardile paigutatud tegelik marsruut.

Uus `game/tests/logistics_v15.gd` kontrollib saeveski sisendipuidu vedu enne tootmist, kaubavankrite tööjõukulu, valmis laudade toimetamist lattu, kuuekäigulist karavaniliikumist, tagasivedu ja salvestuse taastamist koos linnamenüü toimingutega. Varasemad 0.5–0.14 testid jäävad samuti kohustuslikuks, sealhulgas 1200 JavaScripti originaalmajandusega võrreldud käiku.

**Piirangud:** veotööjõu jaotus on esialgne (1 või 2 vankrit), metsast ja karjäärist tooraine kogumine jääb senise töökoja juurde toomise loogikaga, kaubapunkti elanikkond ei arene iseseisvalt ja täpne maailmakaardi kaubatee ning hinnad puuduvad.


## AutoPort 0.17 – teise linna ehitus-AI ja päris maailmakaardi kaubatee

Teise linna asutamine linnamajanduse menüüs lülitab nüüd sisse **ehitus-AI**, mille saab samas menüüs käsitsi välja või sisse lülitada. AI ehitab ühe poolelioleva hoone kaupa, lähtudes ressurssidest, tööjõust ja olemasolevast hoonete tehnoloogilisest eeltingimusest. Eelistusjärjestus algab metsamajast, kaevu ja elamutega ning jätkub kivimurru, põllu ja laoga. Ehitus toimub ainult teise linna oma varudest ja legaalsetel vabadel 3D ehitusplatsidel; automaatseid riikidevahelisi oste endiselt ei tehta. Teise linna arendust saab käigupõhiselt jälgida linnainfo real ja tööde ajaloost salvestuses (`ai_log`).

`game/scripts/world_trade_routes_v17.gd` otsib maailmakaardi 220 × 165 ruudust läbitava maismaatee alguslinna ja teise linna vahel, vältides merd ja läbimatuid mäestikuruute. Tee joonistatakse `world_canvas_v06.gd` kaardile ning karavanide asukohad kuvatakse teel kauba liikumise osakaalu järgi. Vaid tõendatult kättesaadav maismaaruut sobib uue linna asukohaks. Uute karavanide sõiduaeg oleneb kaubatee tegelikust ruutude arvust (esialgne prototüübikiirus kolm maailmaruutu käigu kohta, vähemalt kaks käiku). **Juba salvestatud vanade karavanide kuuekäiguline aeg jääb muutmata**, samuti ei vähendata või suurendata nende laadungit.

Automaatkontroll `game/tests/world_trade_v17.gd` kontrollib, et tee on külgnev ja kuiv, kauba väärtus kandub õigel käigul ainult sihtlinna, vanad saadetised säilitavad ETA, AI tellib teise linna esimese ehitise oma materjalidest, kasutajaliidese AI lüliti säilib salvestuses ning kaubatee ja karavanid kuvatakse maailmakaardil. Säilivad ka kõik varasemad pariteedi-, logistika- ja 0.16 kahe linna ehitustestid.

**Piirangud:** tegemist on piiratud teise linna ehitus-AI-ga, mitte täisväärtusliku strateegilise riigi-AI-ga. Tee on esialgu maismaa ruutude järjestus, mitte realistlik vankritega läbiv sõidetav kogu maailma 3D tee. Linnadevahelised teehooldus- ja transpordihinnad ning merevedu vajavad veel arendust.


## AutoPort 0.18 — maailmakaardi mobiilsed puutežestid

Androidi Godoti maailmakaardil on nüüdsest kahe sõrme näpistusega suumimine ning kahe sõrme samaaegne liigutamine panoraamimiseks. Suum ankurdatakse sõrmede keskpunkti: kaardi asukoht ei hüppa žesti ajal. Ühe sõrmega saab endiselt kaarti nihutada ja lühikese puudutusega ruudu valida. Pärast kahe sõrme žesti ei tekita kummagi sõrme lahtilaskmine juhuslikku kaardiruudu valikut.

`game/tests/world_v06_ui.gd` käivitab päris Godoti ekraanil sünteetilised kahe sõrme puudutus-, lohistamis- ja vabastussündmused ning kontrollib suumi suurenemist, valiku säilimist, järgmist ühe sõrme puudutust ja ühe sõrmega panoraamimist. Kontroll käivitub nii lähtereglite sünkroonimisel kui ka Windowsi EXE / Androidi APK väljalaske ehitamisel. Need muudatused ei muuda 0.17 majandust, karavanide ETA-d ega salvestusskeemi.

**Piirang:** testid kontrollivad Godoti puutežestide loogikat headless-keskkonnas. Füüsilise Androidi seadme multitouch-käitumise käsitsi valideerimine on eraldi vajalik. 3D detailkaardi kaamera kasutab endiselt varasemat ühe sõrme pööramisrežiimi.
