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


## AutoPort 0.19 — 3D detailkaardi mobiilikaamera

Godot 4 3D detailkaardi juhtimine on nüüd puuteekraanil eristatud: **üks sõrm lohistades pöörab** kaamerat, **üks lühike puudutus valib ehituskoha** ning **kahe sõrme näpistus suumib** ja **kahe sõrme koos nihutamine liigutab kaamera vaate keskpunkti**. Suumi ja nihutamise fookus säilib sõrmede keskpunkti all asuva maapinna punkti järgi. Kaamera kaugus on piiratud vahemikku 15–180 m ja vaate keskpunkt piiratakse detailala piiresse. Hiire parema nupuga pööramine ja rattaga suumimine jäävad alles.

Kahe sõrme vabastamine, sõrmede järjekorra muutumine ega orb-mouse-up sündmus ei käivita ehitise paigutamist. Uus `game/tests/detail_camera_v19.gd` katsetab reaalsesse 3D detailvaatesse ühendatud Godoti kaamera sünteetilisi Androidi puutesündmusi: kahe sõrme sisse-välja suum, suumifookuse säilimine, 3D panoraam, puudutuse ohutu lõppemine, ühe sõrme ehituskoha valimine ja kaamera pööramine. Kontroll lisatakse nii `sync-upstream.yml` kui ka `build-apps.yml` töövoogudesse.

**Väljalase:** 0.19 GitHub Actions'i väljalaskemärgis on `v0.19.<run_number>` ja kasutajaliidese kuvatav versioon on 0.19. Varasem 0.18 maailmakaardi kahe sõrme juhtimine ning 0.17 kaubakaravanid, AI ja salvestusvorming säilivad. Uued Godoti puutetestid vajavad veel CI läbimist ja füüsilisel Androidi seadmel kontrollimist. Godoti versioon ei ole endiselt kogu Three.js strateegiamängu täielik port.


## AutoPort 0.20 — nähtav ehitusruudustik ja täpne paigutamine

3D detailkaardil on nüüd 10-meetrise sammuga neutraalne ruudustik. Ehitise valimisel kuvatakse vabade kruntide kohal läbikumavad **rohelised** ja hõivatud või keelatud kruntide kohal **punased** märgid. Hiirekursori all olev 3D maapinnapunkt ümardatakse täpselt sama `Spatial.snap()` reegliga, mida kasutab ehitamise loogika. Eelvaate ruut on lubatud kohal kollane ja keelatud kohal punane. Nupp **Tühista ehitise paigutamine** katkestab valiku ilma materjale kulutamata.

Olemasolevad majandus-, tööjõu-, salvestus- ja teeotsimise reeglid jäid muutmata. `game/tests/detail_placement_v20.gd` kontrollib ruudustiku nähtavust, lubatud ja keelatud ruute, 10 m asukohta ümardamist, keelatud ehituse kuluta tagasilükkamist, valiku tühistamist, korrektset hoone ehitamist ja võõral kaardiruudul ehitamise tõkestamist. Test on lisatud nii GitHub Actionsi sünkroonimis- kui ka APK/EXE ehitusprotsessi. Kaamera ühe sõrme pööramine on veidi aeglasem ja kahe sõrme näpistuse tundlikkus pehmem. Väljalaskemärgis on `v0.20.<run_number>`.

**Kontrollistaatus:** lähtekood ja testid on üles laaditud, kuid automaattestide tulemused ning uue Androidi APK ja Windowsi EXE valmimine vajavad GitHub Actionsi kinnitust. Detailkaardi visuaal on endiselt Godoti prototüüp, mitte täielik Three.js mängu port.


## AutoPort 0.21 — pööratav läbipaistev 3D ehitise eelvaade

Kui 3D detailkaardil valida ehitis, ilmub maastikul selle **päris Godoti primitiivmudeliga sama kujuga** läbipaistev eelvaade. Rohelised/punased ruudud järgivad jätkuvalt 0.20 ehitusreegleid; eelvaate värvus muutub sõltuvalt koha lubatavusest. Kaamera all olev eelvaade ei kuluta ressursse ega ole linnas päriselt ehitatud.

Kaks uut nuppu (**Pööra ↶ 90°**, **Pööra ↷ 90°**) lubavad valida hoone suuna: 0°, 90°, 180° või 270°. Hoone tellimisel liigub suund läbi `build_at_requested` signaali majanduse ehitusfunktsiooni ja salvestatakse ehitise `rotation` väljana. Nii valmis hoone kui ka ehitusjärgus 3D karkass kasutavad selle suuna pööramiseks kohalikku 3D sõlme. Vanade salvestuste ehitised, millel `rotation` puudub, jäävad automaatselt suunaga 0°. Vana kolme argumendiga `_build_at(kind,x,z)` kutse jääb kehtima; eraldi mängumajanduse reeglid ja linnade kaubandus ei muutu.

Uus `game/tests/detail_rotation_v21.gd` kontrollib päris 3D kaardil erinevaid läbipaistvaid hoonemudeleid, pööramise normaliseerimist, keelatud ehituskoha tõrjumist, valitud asukohta ja suunda, ehitusmaterjalide kasutust, JSON-salvestust, varasemate 0.20 ehituskutsete sobivust ning vana salvestuse 0° vaikimisi suunda. Mõlemad GitHub Actionsi töövood peavad testi läbima enne uut väljalaset. Väljalaskemärgis on `v0.21.<run_number>`.

**Piirang:** mudelid on endiselt esialgsed Godoti 3D geomeetrilised hooned; pööramine ei lisa automaatselt uusi ukse-põhiseid rajaleidmise ja liikluse reegleid. CI, Windowsi EXE, Androidi APK ja füüsilise telefoni tulemused vajavad veel kinnitamist.

## AutoPort 0.22 — pööratavad hooneuksed ja kaubateed

Eelmise versiooni salvestatud `rotation` määrab nüüd hoone teenindussissepääsu: 0° = +Z, 90° = +X, 180° = −Z, 270° = −X. Uus `game/scripts/building_access_v22.gd` paigutab sissepääsu 20 meetri kaugusele hoone keskmest 10-meetrise A* ruudustiku järgi. Kui peasissepääs on hõivatud või ligipääsmatu, proovib rajaleidmine järjest kolme teist teeninduskülge.

Metsamaja ja kivimurru töölised väljuvad töökoja uksest ja naasevad sinna; ehitajad käivad ehitusplatsi sissepääsu ja linnahalli sissepääsu vahel; kaubavankrid kasutavad lähtehoone ja raekoja ukseesiseid. Kauba hulk, hind, juba salvestatud saadetiste väärtus ja ehituse materjalikulu ei muutu. Varasemate salvestuste hooned ilma `rotation` väljata säilitavad +Z suuna, ilma kohustusliku andmeskeemi migratsioonita.

Godoti 3D detailkaardil on pööratav `FrontDoorStep` ning `DoorAccessPath_*` ja `DoorAccessPoint_*` ühendused. Tegelikud pikemad teed tekivad ja kuluvad endiselt ainult liikumisest; lühikesed ehitise juurdepääsulõigud on illustratiivsed. Ehitise keeramisega ei teki uusi teid automaatselt läbi ehitiste, jõgede ega järsakute.

Uus test `game/tests/building_access_v22.gd` kontrollib nelja suunda, A* läbipääsetavust, ehitajate ja vankrite sihtkohti, blokeeritud ukse varuteed, kuue ühiku kauba säilimist, vana salvestuse +Z suunda ning 3D ukseesise nähtavust. Mõlemasse GitHub Actionsi töövoogu on lisatud sama test ning väljalaskeskripti versioon on `v0.22.<run_number>`. Automaattestide edukus ja uue APK/EXE avaldamine vajavad eraldi kinnitust.


## AutoPort 0.23 — kiiremad linnateed ja ühendatud tänavad

A* rajaleidmine on ümber tehtud: iga marsruudi jaoks arvutatakse hoonete läbimatud 10-meetrised ruudud ainult ühe korra (`Paths.occupancy`), mitte enam iga naabri uurimise ajal. Avatud punktide valik toimub kaheharulise prioriteedijärjekorra (binary heap) abil, mitte kogu järjekorra korduva läbivaatamisega. Nähtav maastik, 8 liikumissuunda, jõekoolmed, sillad, kaldepiirangud ja hoonete läbimatus jäävad kehtima. Marsruutide andmekuju ja salvestusfaili skeem ei muutu.

Uus `Paths.road_links` ühendab kõrvuti asuvad, piisavalt palju kasutatud teeruudud kitsaste 3D tänavalõikudega, sealhulgas turvalistes diagonaalsuundades. Ühendusi ei joonistata läbi hoonete, liiga järskude tõusude ega blokeeritud jõeruudu; otse läbi diagonalnurga minek on keelatud. Tänavad kujunevad kasutusest ja kaovad, kui neid ei kasutata. Varasemad 0.22 hooneukse ühendused ja 0.21 hoone pööramissuunad säilivad. Tegemist on endiselt esialgse väikese linna Godoti tänavasüsteemiga, mitte kogu veebimängu tänavavõrguga.

Uus Godoti test `game/tests/path_grid_v23.gd` kontrollib 867 ruutu tihedas linnas vanade takistusreeglite suhtes, mitut A* läbimist, tänavate ühendamise ning kadumise tingimusi, 3D tänavalõikude olemasolu ja JSON-salvestusega ühilduvust. Mõlemad GitHub Actionsi testitöövood sisaldavad uut testi. Uus väljalaskemärgis on `v0.23.<run_number>`. Tegelik APK/EXE avaldamine sõltub kogu regressioonikomplekti edukast läbimisest.


## AutoPort 0.24 — tihedam linn ja sujuvam 3D kaart

`game/scripts/city_planner_v24.gd` pakub mängijale soovituslikke 10 meetri ehitusruute. Elamud ja turuhooned koonduvad mõõdukalt linna südame ümber, ressursitöökohad eelistavad välisvööndit ning mets/maardlad mõjutavad soovituse kohta. Planeerija eelistab kompaktset linna ja jätab mõne keskse koridori teede jaoks. Enne pakkumist kontrollitakse nii kehtivaid `Spatial.can_place` piiranguid kui ka uksele ligipääsu A* abil. Valitud ehituskoht on **soovitus, mitte automaatne ehitus**: alles mängija klõps/sõrm käivitab sama hinnaga `City.build` toimingu.

3D detailvaates on ehitusmenüüs nupp **Soovita linna krunti**, mis kuvab ligipääsetava planeeritud koha ja võimaliku pööramissuuna. Telefonil näeb juba ehitise valimise järel algset soovitust, ent vana 0° algsuund jääb puutejuhtimises alles. Võimalik on endiselt ehitada muudesse lubatud kohtadesse. Plaanitud linnakeskus jääb esialgse 160 × 160 m ehitusala piiresse, mitte ei laienda veel maailmakaardi vallatavust.

Jõudluse jaoks taaskasutatakse sama värvi `StandardMaterial3D` ressursse ja sama suurusega `BoxMesh` meshe eri instantside vahel. Hover- ja valikuvärvi muutvad materjalid jäävad eraldi, et ühe hoone esiletõstmine teisi ei muudaks. Ehitusruudustiku neutraalsed ja värvilised materjalid ei loodu iga värskenduse jaoks uuesti. `Paths.connected_cells` arvutab ühe kontrolliga linnahallist ligipääsetava tänavate ala ja `Access.reachable_from_map` kasutab seda kogu 3D linnas, vältides iga maja kuvamiseks eraldi A* päringut. Töölistel ja kaubavankritel on endiselt täpne A* marsruut.

Test `game/tests/city_growth_v24.gd` kontrollib deterministlikke krundisoovitusi, >8 hoone paigutust, JSON-ühilduvust, hoonete ukseandmete sama tulemust vana A* ja uue ühiselt arvutatud ligipääsu korral, jagatud 3D meshe ja materjale, hoone tellimist ning algse hinna kulumist. Mõlemad CI töövood käivitavad 0.24 testi; avaldamismärgis on `v0.24.<run_number>`. Pärast CI läbimist valmivad uuendatud Windowsi ja Androidi failid.


## AutoPort 0.25 — linna naaberruudud ja ühine majandus

Godoti maailmakaardilt saab valida linnaga külgipidi piirneva kuiva, läbitava ruudu ja vajutada **Liida linna ruut**. Linn võib kasvada esialgsest pealinnaruudust naaberruutudele; igaks järgmiseks ruuduks on vaja vähemalt 6 täiendavat elanikku ning liitmine maksab **20 puitu ja 10 kivi**. Liitmine ei tööta meres, läbimatul mäestikul ega teise riigi algusruudul ning ei toimu diagonaalselt üle nurga. Olemasoleva ruudu teistkordne liitmine ei kuluta ressursse. Lisandunud ruudud salvestatakse linna olekus `districts_v25` koos maailma seemnega; vanad salvestused ilma selle väljata omavad automaatselt algset pealinnaruudu.

Maailmakaart joonistab linna ruudud kuldsega ja kõrvuti liidetud ruutude vahele omavahel ühendatud tänavalõigud. Need on maailmakaardi teed, mitte veel linnaosade vahelise 3D kaardi katkematu liikumise simulatsioon. Linnaosad kasutavad sama ressursside ladu, elanike arvu, tehnoloogiaid ja ehituse kulusid. Pealinna ning naaberruudu kohalikud ehituskoordinaadid on eraldi: sama 30,−10 m krundi kasutamine kahes maailmaruudus on lubatud ega dubleeri hooneid nende 3D vaadetes. Uute hoonete `district` väli määrab, millisel maailmakaardi ruudul nad asuvad; vanad hooned ilma selle väljata jäävad algsesse pealinna.

**Teadlik piirang 0.25-s:** töötajate ja kaubavankrite detailne 3D liikumine on seni ühe algse ruudu põhine. Naaberruudul saab maja tellida ja see kuulub ühisesse linna majandusse, kuid 3D tööjõutransport ja katkematu teevõrk kahe detailkaardi vahel vajavad järgmist suuremat portimisetappi. Naaberruudu avamine ei kirjuta enam üle algse linna salvestatud kohaliku maastiku andmeid.

`game/tests/world_districts_v25.gd` kontrollib kasvupiirangut, liitmiskulu, topeltliitmise tõkestamist, külgepidi ühendust, kuldseid maailmakaardi ülekatteid, 3D hoonete eristamist, salvestust ning vanade linnade ühilduvust. GitHub Actionsi automaatne Androidi APK ja Windowsi EXE ehitus käivitab testi koos kõigi varasemate testidega. Väljalaskemärgis on `v0.25.<run_number>`.


## AutoPort 0.26 — füüsilised linnaosadevahelised liikujad

Naaberruudud on nüüd ühendatud ühe **liikumisvõrguga**, mitte ainult maailmakaardile joonistatud teedega. `game/scripts/district_transit_v26.gd` hoiab linnale kuuluvate maailmaruutude graafi ning iga rändava töölise, ehitaja ja kaubavankri linnaosa ja kohalikke 3D koordinaate. Igas detailruudus kasutatakse 10-meetrise A* ruudustiku takistusreegleid; naaberruutu pääseb ainult külgepidi ühise tee värava kaudu. Väravast üle sõitmine kulutab eraldi 20 m teepikkuse ja vähemalt ühe mängukäigu. Jõest või hoonest läbimatud väljumised ei ole võimalikud ning süsteem proovib alternatiivseid läbitavaid väravapunkte.

Uue linnaosa hoonetest pärit valmis kaup läheb esmalt füüsilisele vankrile. Kaup lisatakse pealinna ühislattu **alles vankri saabumisel**, seda jälgitakse kaubabilansis ja see säilib salvestuses. Ehitustööde juba tellimisel mahaarvatud materjalid liiguvad ehitusplatsile samuti vankritega. Ehitusmeeskond peab linnaosa väravast ja kohalikest tänavatest läbi jõudma enne töö lõpetamist. Uue linnaosa metsamaja ja kivimurru töölised reisivad oma töökohta ja kasutavad sealseid eraldi piiratud puidu/kivi ressursipaiku. Pealinna vana A* töövoog säilib ning vanades salvestustes puuduv transpordikiht aktiveerub alles päriselt liidetud linnaosade puhul.

3D vaates näidatakse selle linnaosa kohal olevat liikuvat töölist või kaubavankrit ja väravani viivat teelõiku. Maailmakaardil on linnaosadevahelised tänavad ning liikujate tegeliku ruudu ja kohaliku asukoha järgi muutuvad markerid. 0.26 ei renderda veel kogu mitmest maailmaruudust koosnevat maastikku korraga ühes 3D kaameras; liikumise füüsiline võrk on ühine, vahetatavate detailvaadetega.

`game/tests/district_transit_v26.gd` kontrollib läbitavaid naaberruutude vahelisi marsruute, vähemalt ühe mängukäigu pikkust väravaületust, päris kaupa kandvat 3D vankrit, kaubakoguse säilimist igal käigul, ehitusmaterjalide ette tasumist, ehitajate töö valmimist ja marsruutide salvestamist. Test on osa mõlemast CI töövoost. Väljalase on `v0.26.<run_number>`.


## AutoPort 0.27 — naaberlinnaosad ühes 3D stseenis

Pealinna ja 0.25-s liidetud naaberlinnaosade 3D maastikku saab nüüd vaadata ühes Godoti stseenis. `game/scripts/continuous_city_v27.gd` joondab iga maailmakaardi ruudu keskpunkti 160 meetri sammuga: 70 m kummagi linnaosa sees, 20 m vaheline füüsiline väravaületus. Kombineeritud vaates kasutatakse ühe linnaosa kohta 160 × 160 m maastikku, mis ei kattu naaberlinnaosaga. Ühe linnaosa vana 225 × 195 m vaade jääb alles ja tema kaamerapiirid ei muutu.

Kõik kaamerast kuni nelja maailmaruudu kaugusel asuvad ühendatud ja omatud linnaosad kuvavad korraga oma maapinda, hooneid, kohalikke puu/kivivarusid ning parasjagu selles linnaosas olevaid 0.26 töölisi või kaubavankreid. Linnaruudud ühendatakse tegelike naaberlõikude vahel 3D teedega. Uued **Vaata kogu linna** ja **Järgmine linnaosa** nupud näitavad laiemat mänguala või viivad tähelepanu järgmisele linnaosale. Kui puudutada teise linnaosa maapinda, aktiveerub selle ehitusruudustik samas 3D stseenis, ilma maailmakaardile naasmata. Ühe puudutusega linnaosa vahetamisel ei toimu tahtmatut ehitust ega ressursikulu; järgmine puudutus saab sooritada ehitustoimingu valitud linnaosas.

0.26 käigupõhised tööliste ja kaubavankrite asukohad ja marsruudid on endiselt majanduse allikaks; 0.27 ei dubleeri transpordi- ega ehitusressursse. 3D geomeetria on teadlikult Godoti prototüübi materjalidest ja lihtobjektidest. Väljaspool avatud kaamerapiirkonda võib jääda linnaosi, mida ei renderdata samaaegselt, et hoida mobiili jõudlust. Praegused linnaruudud on tasapinnalised ka siis, kui nende maailmakaardil on mägimets või jõgi; detailne kõrguste ja jõgede sujuv kokkuviimine jääb tulevasse etappi.

Regressioonitest `game/tests/continuous_city_v27.gd` kontrollib 160 m maastikuruute, naaberhoonete samaaegset kuvamist, 3D tänavalõike, suurema ala kaamerapiire, ekraanilt linnaosa valimist, tahtmatu ehituse vältimist, reaalse maja ehitamist ühise ressursikuluga ning eemal oleva kaubavankri nähtavust. Test lisatakse mõlemasse GitHub Actionsi töövoogu; väljalaskemärgis on `v0.27.<run_number>`.


## AutoPort 0.28 — ühendatud maastik, jõed ja mobiilijõudlus

Mitme maailmaruuduga 3D linn on nüüd ühe ühendatud maastikupinnaga. `game/scripts/continuous_terrain_v28.gd` kasutab iga 160×160 m linnaosa kõrguste jaoks samu globaalseid maailmakoordinaate ja seemet. Seetõttu on kõrvuti asuvate ruutude servade kõrgused täpselt samad ning maastikuvahed ei teki. Kombineeritud maastiku resolutsioon on ühe ruudu kohta 16×16 (256 ruutu / 512 kolmnurka), mis on mobiilil odavam kui varasem 30×26 võrk. Ühe maailmaruudu vana eraldi 225×195 m detailvaade säilib. Maastik ei ole veel 1:1 algse Three.js maailma kõrgusmudeliga.

Kui mõlemal naaberruudul leidub jõgi, luuakse 3D jõelõigud ühist piiripunkti mööda ning madalam jõesäng lõigatakse sama kõrgusfunktsiooniga mõlemal pool piiri. Üksik jõeruut saab ainult oma territooriumi sisese lõigu, mitte vett keset naaberruudu kuivmaad. Kivi- ja puiduvarude 3D mudelid näidatakse ligipääsetaval kõrvalruudul; kaugemate linnaosade jaoks vähendatakse dekoratiivobjektide hulka.

Varem ehitas iga `refresh_buildings()` kogu mitmeruudulise 3D linna uueks. Nüüd jäävad naaberruutude maastikumeshed ja muutumata majad samaks Godoti objektiks, kuni vaade suletakse või nende ehitusstaadium päriselt muutub. Liikuvate vankrite ja tööliste asukohti uuendatakse olemasolevates 3D objektides; vaid lisanduvad või lahkuvad liikujad loovad või eemaldavad sõlme. See vähendab objektide loomist ja prügi kogumise koormust mobiilis. Varasemate salvestuste ning 0.26 transpordiarvestuse reeglid ei muutu. Nähtav jõgi on endiselt 3D-prototüübi maastikuillustratsioon, mille voolu ja veetakistuste täpne seos A* liikumisvõrguga vajab eraldi arendust.

`game/tests/terrain_seams_v28.gd` kontrollib vähemalt 17 samast kõrgusest koosnevat piirisämplit, jõe lõikude ühendamist mõlemas maailmaruudus, ühe pinnameshi kolmnurki, maastiku objektide taaskasutust, vankri liikumise uuendamist ilma mudelit uuesti loomata ning vanade salvestuste säilimist. Test lisatakse mõlemasse GitHub Actionsi töövoogu. Versioon: `v0.28.<run_number>`.


## AutoPort 0.29 — 3D jõed, koolmed, sillad ja sama rajaleidmine

0.28 ühise kõrgusmudeli kasutab nüüd ka kõigi liidetud linnaosade 10-meetrine A* rajaleidmine. `game/scripts/terrain_navigation_v29.gd` loeb sama maailma seemet, maailmaruudu koordinaate ja lühikest JSON-ühilduvat jõelõikude loendit, mille alusel `continuous_terrain_v28.gd` joonistab maastiku kõrgused ja vee. Terve maailmakaardi andmeid linna salvestusfaili ei kopeerita. Vana, ainult ühe detailruuduga 0.10 maastik ja selle salvestused jäävad seniste reeglitega tööle.

A* ei kontrolli enam üksnes 10-meetrise teelõigu lõpp-punkti: kogu liikumislõiku proovitakse iga 1,25 meetri tagant. Nähtavast veest ei pääse läbi ning ka diagonaalis kitsast jõge üle hüpata ei saa. Kitsamad koolmekohad jäävad kindlatesse jõelõigu kohtadesse. Mängija saab ehitada silla vahetult selle jõelõigu sobivasse kohta; sild avab sama koha töötajatele ja vankritele, joonistatakse 3D sillana ning maksab **28 puitu ja 18 kivi**. Korduv sillaehitus ei kuluta uuesti ressursse. Kogu ühe linna ressursiladu jääb ühiseks.

3D jalgradade kõrgused arvestatakse nüüd samast aluspinnast. Majade paigutus ei luba uue linnaosa nähtava vee peale ehitamist. Sildade ja koolmete 3D koordinaadid pärinevad samast ristumiskohtade arvutusest, mida kasutab A*. Eraldi on säilitatud vana ühe ruudu kaldepiirangu, jõesängi ja sillakoha loogika. **Praegune jõgi on esialgne ruutudevaheliste ühenduslõikudega vektorjoon**, mitte veel täpselt põhikaardi hüdroloogia või ajaloolise Three.js kaardi võrgustik.

Uus `game/tests/terrain_navigation_v29.gd` kontrollib 17 piirikõrguse punkti, vee läbimatust nii tavalises kui ka diagonaalses rajaleidmises, looduskoolme olemasolu, valmis silla avatud teed, ühe ehitamise hinnakulu, JSON salvestusühilduvust ning päris 3D silla- ja koolmeobjekte. Test on lisatud mõlemasse GitHub Actionsi töövoogu. Väljalase märgistatakse `v0.29.<run_number>`.


## AutoPort 0.30 — päriselt läbitavad ühendusteed ja suure linna 3D jõudlus

Maailmaruutude vahelised 3D teed ei joonistu enam automaatselt iga omatud naaberruudu täpsesse keskpunkti. `game/scripts/district_visuals_v30.gd` küsib iga ühenduse jaoks sama füüsilist väravakohta, mille valib 0.26 töötajate ja vankrite A* rajaleidmine. Kui keskmine läbipääs on suletud või jõgi/maastik ei luba seda kasutada, valitakse võimaluse korral alternatiivne värav (±20, ±40 või ±60 m külgsuunas). Kui ükski värav pole läbitav, ei kuvata ka sellel piiril eksitavat ühendusteed. Tee algus, lõpp ja 20 meetri pikkune ülekäik vastavad tegelikule simuleeritud liikumisele; kõrgus võetakse 0.28 globaalsest maastikust. Uute sildade ja hoonete tõttu muutunud läbipääsud tühistavad teede visuaalse vahemälu.

Pealinna aktiivse detailruudu valminud hoone 3D geomeetriat ei looda enam igal `refresh_buildings()` käigul uuesti: senine objekt ja materjal säilivad kuni ehitusstaadiumi, valmiduse või pöörde muutumiseni. Sama kehtib naaberruutude muutumatute majade, maastiku ja nendevaheliste ühendusteede kohta. Ühe linnaosa kaunistused on nüüd kolme detailsusastmega (lähedal kuni 14, keskmisel kaugusel kuni 5, kaugemal 0 ressursside mudelit). Dekoratsiooni vahemälu arvestab samuti puu/kivi ressursikoha ammendumist, ent majandus ise jääb täpselt samaks.

`game/tests/district_visuals_v30.gd` kontrollib 20 meetri ühendusteed, alternatiivse värava valimist, läbimatute piiriületuste puhul valeteede puudumist, staatilise materjali/maastiku/hoonete taaskasutust, detailsustasemeid ja salvestuste ühilduvust. Ka vana 0.27 test kontrollib nüüd, et joonistatud teede arv kattub tegeliku rajaleidmise lubatud ühendustega. Mõlemad GitHub Actionsi töövood käivitavad uue testi ja avaldamismärgis on `v0.30.<run_number>`.


## AutoPort 0.31 — mõõdetav mobiilijõudlus ja MultiMesh 3D mudelid

Linnaosade ressursiobjekte (puude tüvesid ja võrasid ning kive) ei renderdata enam iga puu/kivi eraldi MeshInstance3D-na. Uus `game/scripts/city_render_batch_v31.gd` koondab ühe linnaosa ühesuguse geomeetria **kolme MultiMeshInstance3D rühma** (tüved, võrad, kivid), mille GPU-instantsid hoiavad iga ressursikoha eraldi asukoha/suuruse. Testjuht 30 puu + 30 kivikohta koos kolme kiviga iga kivikoha kohta tähendab 150 endist üksikobjekti ja kuni 3 graafikarühma. Tegelik GPU draw-call kokkuhoid ja FPS sõltuvad seadmest, varjudest ning renderdusrežiimist — see näide on võrdlus rühmade arvu, mitte füüsilise telefoni mõõtmise põhjal. Ressursside tegelik kogus ega töömeeste marsruudid ei muutu. Muutumatu aktiivne ressursirühm ja neutraalne ehitusruudustik säilivad mängukäikude vahel.

3D vaate päises on **FPS** nupp, millega saab jõudlusnäidiku peita või avada. Näidik mõõdab jooksval seadmel kord sekundis `Engine.get_frames_per_second()`, sama 3D Viewporti nähtavate objektide ja draw-call arvu ning stseeni sõlmede hulka. Headless CI-s võivad GPU-loendurid olla null; CI test ei väida ega võrdle Androidi tegelikku FPS-i. Androidi mobiilil alustab vaade 720×450 eraldusvõimest, pärast vähemalt kolme järjestikust sekundit alla 28 FPS-i langetab 600×375-ni; üle 55 FPS-i püsimisel vähemalt viie sekundi jooksul tõstab detailsust (kuni 960×600). Vahemikus 28–55 FPS vaade ei kõigu. Arvutis kasutatakse endiselt 960×600 vaikevaadet.

Ühe sõrme kaamera-orbiidi liikumises kasutatakse väikest madalpääsfiltrit, et ekraanipuudutuste mikrovõnkumine ei põhjustaks hüplikku pöörlemist. Kahe sõrme pinch/pan hoiab vana maapinnale ankurdatud suumi ja ühe puudutuse ehituskäitumise. 0.31 muudatused on renderdus- ja kasutajaliideses; 0.29–0.30 rajaleidmise, sildade, linnaosade ja majanduse salvestusandmed jäävad muutmata.

Uus `game/tests/city_performance_v31.gd` kontrollib tõelist MultiMesh instantside ja sõlmede arvu, erinevaid LOD piiranguid, ressursside muutumatust, vaate sõlmede taaskasutust, FPS näidiku välju ja eraldusvõime hüstereesi. Vana 0.19 kaamera regressioon ja varasemad majanduse/linna testid peavad samuti läbima. Test käivitatakse mõlemas GitHub Actionsi töövoos. Avaldamismärgis on `v0.31.<run_number>`.


## AutoPort 0.32 — hoonete GPU MultiMesh, kaamera kauguspiir ja sujuv liikumine

Uue `game/scripts/city_building_lod_v32.gd` abil on **aktiivne linnaosa** alati detailselt nähtav. Lähedal asuva naaberlinnaosa majad kasutavad seniseid täis-3D mudeleid, kaugemal (umbes 195–335 m) koondatakse samaliigilised majad GPU MultiMesh rühmadesse ning kauges linnapanoraamis kasutatakse kõigi hoonete jaoks vaid üht lihtsustatud hoonete siluettide rühma. Näidiskaardil 72 maja asemel piisab keskmisel kaugusel kahest (majad/põllud) ja kaugel ühest MultiMesh rühmast. Siluetid näitavad tegelikke hooneid ja nende asukohti; majandushooneid ei kustutata ega peideta salvestusest. Poolikud ehitised jäävad keskmisel kaugusel eraldi madalama mudeli gruppi.

Kui linnaosa asub liiga kaugel kaamera fookusest ja kaamera pole kogu linna ülevaatel, jäetakse selle linnaosa 3D sõlm renderdamata (`visible=false`). Kui kaamera tagasi liigub, taastub täielik vaade. FPS-i mõõdik ja 0.31 graafikaresolutsiooni adaptsioon jäävad alles. 3D vaatekaardil kontrollitakse kaamera fookuskaugusi korrapäraselt, mistõttu kaugele kerides ei jää detailid eelmise linnaosa asukohta rippuma. Nähtavus puudutab ainult Godoti graafikat: 0.26 töötajate ja kaubavankrite liikumine ning linna majanduse käigud toimivad edasi sõltumata kaamera positsioonist.

`detail_camera_v07.gd` hiirerulliga suum on nüüd animeeritud liikumisega, säilitades 15 m minimaalse ja iga linna suurusega seotud maksimaalse suumikauguse. Käsuga „Järgmine linnaosa” liigub kaamera fookus sihtpunkti sujuvalt. Kahe sõrme pinch/suum on endiselt vahetu ja säilitab sõrmede all oleva maailmapunkti, et vanad mobiilis kasutatavad puutežestid ei muutuks.

Uus test `game/tests/city_building_lod_v32.gd` kontrollib 72 hoone päris MultiMesh instantside arvu, detailsuse vahetamist, kaamerast kaugel linnaosa peitmist ja taastamist, muutumatute mudelite GPU vahemälu, sujuva suumi vastust ning kõikide majandushoonete säilimist JSON-is. Endised 0.19 kaamera ja 0.31 MultiMesh jõudlustestid jäävad alles mõlemasse GitHub Actionsi töövoogu. Väljalaske versioon on `v0.32.<run_number>`.


## AutoPort 0.33 — stabiilne 3D kaamera ja linnaosa LOD

0.32 kaamerast sõltuva hoonete detailsuse peamine puudus oli 195 ja 335 meetri lähedaste väikeste kaameraliigutustega kaasnenud pidev mudelite loomine ja eemaldamine. `game/scripts/city_lod_stability_v33.gd` lisab ±20 meetri hüstereesi lähedaste ja kaugemate hoonete detailsuse piiridel ning ±35 meetri varu linnaosa nähtavuse peitmisele. Kui kaamera hüppab ühe liigutusega väga kaugele või tagasi, valitakse kohe sobiv detailsus. Linnaosade tegelikke majandusandmeid, kaartide ühendusi ja transpordi marsruute ei muudeta.

Keskmisel kaugusel lülitatakse üksikasjalikud majaobjektid välja, aga säilitatakse 3D mälus; nende asemele ilmuvad 0.32 GPU MultiMesh-rühmad. Kaamera tagasiliikumisel taaskasutatakse sama detailse hoone 3D objekti, ilma uut mudelit loomata. Väga kaugel vabastatakse detailne maja mälu, jättes alles ühe lihtsustatud GPU-instantseeritud kujutise, mis uuel lähenemisel taas detailseks muutub. Linnaosa nähtavuse muutmisel säilib ehitusinfo ja elanike arv salvestuses.

Regressioonitest `game/tests/city_lod_stability_v33.gd` kontrollib LOD vahetuse stabiilsust piiride ümbruses, suuremaid kaamerahüppeid, kaugemal detailsete 3D objektide vabastamist, keskmisel kaugusel sama mudeli taaskasutust, tagasitulekul õiget renderdust ning salvestuse muutumatust. Test käivitatakse mõlemas GitHub Actionsi töövoos koos 0.32 ja varasemate regressioonidega. Väljalase: `v0.33.<run_number>`.


## AutoPort 0.34 — nähtav maapind ja kompaktne detailkaardi UI

Mobiili horisontaalvaates jäetakse 3D detailvaatele piisavalt ruumi. Ülemine majandusinfo on üks lühendatud rida, kõik ehitusnupud on ühel horisontaalselt keritaval 46-pikslisel ribal ja FPS näidiku saab avada päisenupust. Mitmekümne ehituse prioriteedinupu lisamine ei suurenda enam tööriistariba kõrgust. Kahepoolne ja valgustusest sõltumatu maastikumaterjal tagab, et nii 225×195 m üksikdetaili kui ka 160×160 m ühendatud linnaosa pind on nähtav. Eelmise detailkaardi pind eemaldatakse enne uue loomist, vältides kattuvaid/valesti nime saanud sõlmi.

Windowsi käivitusprogrammi järeltesti aegunud 0.17-versiooni kontroll on asendatud käivitatud sisu ja projekti versioonide kooskõla kontrolliga. `game/tests/detail_screen_v34.gd` avab 720×420 ekraanil detailvaate ja kontrollib 3D vaate kõrgust, nupuriba kõrgust ka 70 lisanduva ehitusnupuga, korrektset kaamera suunda, maapinna kahepoolset pinnameshi ja kahe linnaosa maastiku olemasolu. Vanade salvestuste ja majanduse reegleid ei muudeta. Versioon `v0.34.<run_number>`.


## AutoPort 0.35 — esimene mängitav riiklik teadussüsteem

- Uus `game/scripts/research_v35.gd` kasutab olemasolevat V118 tehnoloogiate eeldusgraafi, kiviaja/pronksiaja uurimiskestusi ning eksporditud teadus- ja ajastumaterjalide reegleid.
- Kiviaja linnavaates saab uurimist alustada, jälgida teaduspunktide kogunemist ja salvestada avastusi. Iga elanik annab ühe teaduspunkti mänguminutis; ka teise linna elanikud panustavad.
- Pronksiaega jõudmisel tuleb teadustöö lõpetamise järel korraga tasuda 35 puitu, 25 kivi ja 15 toiduühikut. Ressursipuuduse korral teadustöö ootab ning osalisi kulusid ei võeta.
- Varasemad salvestused täiendatakse ilma olemasoleva majandusseisundi või hoonete muutmiseta. 0.5 majanduspariteedi arvutus jääb puutumata.
- Kontrolltest `research_v35.gd` käib nii ehitamise kui ülesvoolu reeglite sünkroonimise CI-s.

**Piir:** see on teaduse esimene mängitav port kiviajast pronksiaega. Eureka boonused, kõigi hilisemate ajastute uurimine, järjekorrad ja kõigi hoonete tehnoloogiapõhised lukud on veel lõpetamata. 3D lahinguid ja täielikku AI tsivilisatsiooni ei ole.


## AutoPort 0.36 — tehnoloogiate nõuded ehitistele

Teadusavastused avavad nüüd ehitised. Samad reeglid kehtivad linnamenüüs, mobiili detailkaardil, otseses ehitamisfunktsioonis ja teise linna AI-s. Kaev vajab veevarustust, kivimurd kivitööriistu, talu põlluharimist. Saekaater, veski, pagarikoda, turg ja laod on seotud vastavate teadustega. Olemasolevaid maju ei kustutata ning 0.5 majanduse pariteeditest jääb muutmata. Detailkaardi ehitusribalt pääseb nüüd teadusmenüüsse. Kontroll: `game/tests/building_unlocks_v36.gd`.


## AutoPort 0.37 — pronksiaja linnapilt ja teise linna AI

- Jätkab olemasolevaid Three.js-st genereeritud `city_buildings` retsepte: **saeveski, materjaliladu, turg, toidukelder ja köögiviljaaed**. Kõik kasutavad tegelikku tootmist, tarbimist, ehitusaega ja teaduslukke.
- Uus `bronze_city_ai_v37.gd` valib teise linna jaoks eluliselt vajaliku hoone ja seejärel pronksiajal kõrgema taseme töökojad/teenused. Elamute siht kasvab kuni kümneni, farmide siht kolmeni; uusi ressursse õhust ei teki ega toimu automaatset rahvusvahelist ostu.
- Detailkaardil on viiele hoonetüübile eristatavad 3D mudelid ja pronksiaja hoonetele kivist soklid. Kompaktne üherealine horisontaalselt keritav mobiilimenüü laseb need välja valida.
- `bronze_city_v37.gd` testib AI ehitusjärjestust, tegelikku köögiviljatootmist, teaduslukke, salvestamist ja viis eri 3D mudelit. Sama regressioonitest käib nii Android/Windows ehitamisel kui Three.js reeglite sünkroonimisel.

See on laiendatud Godot prototüüp, mitte veel kogu Three.js tsivilisatsiooni- ja sõjasüsteemi port.


## AutoPort 0.38 — pealinna automaatne ehitamine

- Uus eraldi lüliti linnamenüüs ja mobiili 3D detailkaardi horisontaalselt keritavas tegevusribas. Vaikimisi välja lülitatud, ka vanades salvestustes.
- Kasutab 0.37 teaduspõhist AI ehitusjärjekorda, 0.24 ligipääsetavate linnakruntide planeerijat ning päris City.build() reegleid. Ehitamine järgib hoone kulusid, avastusi ja vabu krunte ning kasvab kesksest linnasüdamest väljapoole.
- Kasutusest tekkivaid teid ei muudeta: 0.9 töötajate liikluse rada tekib ja hääbub edasi. Teine linn töötab oma eraldi AI-ga.
- Pealinna AI seadistus ja viimased 30 ehitusotsust salvestatakse koos linnaga. Test capital_ai_v38.gd kontrollib ligipääsetavust, kruntide kattumatust, salvestamist, teede säilimist ja mobiili nuppe.


## AutoPort 0.39 — automaatne teadusuuringute puu

- **Teaduse AI** on eraldi sisse/välja lülitatav linna teadusmenüüst ja kitsalt 3D detailkaardi horisontaalsest nupuribast. Uuel mängul on nii teadus kui ehitus käsitsi juhitav. **Pealinna AI** sisselülitamine käivitab ühtlasi Teaduse AI; viimase saab eraldi välja lülitada.
- Eesmärgipõhine graafialgoritm valib kiviaja elutähtsad avastused (kivitööriistad, veevarustus, põlluharimine), lahendab seejärel sõltuvusahela (AND ja oneOf) kuni pronksiaja avamiseni. Pärast pronksiaega uurib see teenuseid, tööriistu ja linnatehnoloogiaid.
- Valik ei tühista käsitsi käivitatud uurimist. Teaduspunktid arvestatakse endiselt elanike arvu ja olemasolevate minutipõhiste reeglite järgi; pronksiaeg nõuab endiselt **35 puitu, 25 kivi ja 15 toitu**. Puuduse korral valmis uuring ootab, kuni materjalid on olemas.
- AI seaded ja viimased 30 valikut salvestatakse. Vana 0.38 salvestatud pealinna-AI saab esmakordsel laadimisel automaatse teaduse partneri. Olemasoleva majandusvõrdluse, linnaehituse, maastiku ja kasutusest tekkivate teede loogikat ei muudeta.
- Regressioonitest `research_ai_v39.gd` katab sõltuvusahela, 450-minutilise ülesandepiiriga pronksiajani arengu, käsitsi uurimise eelisõiguse, salvestuse, materjalide ootejärjekorra ja mobiili UI.


## AutoPort 0.40 — 3D maailmakaart ja naaberruutude detailnavigeerimine

- 220×165 ruudustiku **päris 3D kõrgusvõrgu** kujul maailmakaart, samad kontinendid, mäed, metsad ja mereruudud. Kaart kasutab värvitud 3D kolmnurki, mitte 2D tekstuuri. Vajuta ruutu valimiseks, topeltpuuduta detailkaardi avamiseks; lohista ja suumi kahe sõrmega. Lihtne 2D kaart jääb käsitsi lülitatavaks varuvalikuks.
- Detailkaardi 3D vaates **Kaart ↑ ↓ ← →** nupud läbivad päriselt maailma koordinaadid. Iga naaberruut on avatav vaateks sõltumata sellest, kas kuulub mängijale; ehitamine jääb lubatud ainult oma territooriumil. Mereruutu saab vaadata, seal ei saa veel ehitada ega laevaga sõita.
- Mobiili maailmakaardi nupuriba on ühe rea kõrgune ja keritav, vältides kaardi katmist. Maailmakaardi 2D ja 3D valik sünkroniseeruvad detailkaartidega.
- Test `map_nav_v40.gd` kontrollib 3D maastiku reaalset kõrgust, kaartide vahetust, 2D varurežiimi, suunanuppe, mereruutude vaateid, piire ja 720×420 telefoni UI-d.


## AutoPort 0.41 — veebimängu detailkaartide juhtimine

Veebimängu V123 eeskujul ei vahetata kaarte enam ainult nuppudega. Detailkaart on 225 × 195 m. Ühe sõrme või hiire vasaku nupu lohistamine liigutab kaamera fookust; üle detailruudu ääre liikudes avatakse vastav naaberruut, säilitades kaamera asukoha ja suumi. Ka diagonaalne suund toimib. Hiire parema nupuga saab endiselt kaamerat pöörata. Detailvaates lõpuni välja suumides naaseb mäng 3D maailmakaardile just selle ruudu kohale. Maailmakaardi topeltpuudutus avab endiselt detailvaate. Vana nelja noolega juhtimine jääb abivõimaluseks. Eraldi test detail_web_v41.gd kontrollib veebiversiooni piiriületuse koordinaate, sujuvust ja tagasipöördumist.

Lisaks joonistatakse aktiivse detailkaardi ümber kuni kaheksa kerget naaberruudu maastikueelvaadet (3 × 3 naabrus), nii et üle serva lohistamisel ei ole enne järgmist kaarti tühi taust. Linna olemasolev ühise 3D detailkaartide visualiseerimine jääb muutmata.


## AutoPort 0.42 – pidev naabermaastik veebiversiooni järgi

- Kõik kaheksa 3D detailkaardi naaberruutu saavad nüüd päris kõrguse ja varjutusega 225×195m maastikuvõrgud tasaste kastide asemel. Maastiku kõrgused arvutatakse maailma ühiskoordinaatidest, nii et kahe tühja detailruudu piirilt ei teki kõrgusastmeid.
- Lähedased metsad ja mäed on ka naaberruutudes näha juba enne kaamera piirist üle lohistamist: piiratud arv instantsitud puid, võrad ja kaljud ei koorma mobiili kümnete eraldi objektidega. Meri ja jõed on samuti naaberruutudel nähtavad.
- Varem lisatud 0.41 kaamera pööramise ja suumi säilitamine ning maailmakaardile suumimine jääb alles, samuti mängija ehitusõiguse piirangud, läbitud radadest kasvavad teed ning 0.27 ühendatud linnaosa olemasolev 160m geomeetria.
- Uus `seam_terrain_v42.gd` test kontrollib igas suunas täpseid maastikupiire, 3×3 naabervõrku, mitme järjestikuse detailkaardi läbimist, kaamera suuna/suumi säilimist ja maailmapiiride käsitlemist.


## AutoPort 0.43 — ehitatava linna ja detailnaabrite ühine 3D serv

- Üksiku pealinna ja teise linna keskuse kohalik maapind kasutab jätkuvalt päris `detail_sim` maastiku, fordide, sildade ning rajaleidmise kõrgusi. Linna keskosas ei muutu ükski ehituskoht ega teekalle.
- Detailruudu viimase 30 meetri jooksul sulandub maastik järk-järgult samasse maailmakoordinaatidel arvutatud pinnasse, mida kasutatakse ümbritseval 3×3 naaberruutude võrgul. 225×195 m servas kattuvad kõrgused täpselt, ka diagonaalsete nurkade juures. Varem nähtav linna ja järgmise ruudu kõrgusaste kaob.
- Täiendav test `city_seam_v43.gd` kontrollib 4 piiri, nurki, tõelisi linna jõeületusi, ehitatava linna sisekõrgust ning 720×420 mobiilivaate säilimist.
- Tavaline koodimuudatus käivitab GitHubis ainult reeglite sünkroonimise ja regressioonitestid. Android APK ja Windows EXE ehitatakse kulude vähendamiseks eraldi käsitsi GitHub Actions `Build Android APK, Windows EXE and auto-update content` kaudu.


## AutoPort 0.44 — naaberlinn on 3D eelvaates päriselt nähtav

- Kõrvalruudu 3×3 detailmaastikus näidatakse mängija enda **tegelikult salvestatud** linnahooneid ka siis, kui vaatad linna kõrvalt. Kerged MultiMesh LOD32 siluetid kasutavad õiget hoonetüüpi, suurust, asukohta ja valmisolekut. Väljamõeldud külasid või linnahooneid ei genereerita.
- Eelvaade ei muuda elanikke, ressursse, hoonete ehitust, mänguseisu ega teede kujunemist. Väljaspool linna asuvatelt ruutudelt puuduvad jätkuvalt ehitusõigused.
- Uus `city_preview_v44.gd` regressioon kinnitab tegeliku hoonete arvu, kaugemal vale linna puudumise, ehitusõigused ning hoonete/varude püsimise edasi-tagasi detailkaartidel liikudes.


## AutoPort 0.45 — detailkaardi naaberlinna ehtsad 3D mudelid

- Lähenedes 3D detailkaardilt kõrvalruudu **päriselt salvestatud linnale**, asenduvad kaugemal olevad MultiMesh siluetid aktiivses linnas kasutatavate samade `_building` ja `_construction_site` Godoti mudelitega. Valmis peamaja, elumaja, kaev jms on nüüd lähedalt vaadates päris ehitised, mitte kuubikud.
- Uued ehitusplatsid ja valmis majad on ruutude vahel järjepidevad: lähivaade näitab tegelikku ehitusjärku ja kasutab salvestatud hoone koordinaate/pööret. Kaugemal on jälle kerge LOD; üle 18 hoonega kõrvalküla kasutab telefoni jõudluse hoidmiseks alati instantsitud kuju.
- `detail_buildings_v45.gd` kontrollib kaamerale reageerivat lähedast ja kauget taset, ehtsat peamajamudelit, ehitusplatsi uuendust, renderduse vahemälu, ressursi puutumatust ning kaamera suuna/suumi säilimist.
- Release workflow jääb teadlikult `workflow_dispatch` režiimi; APK/EXE avaldatakse eraldi, mitte iga commit'iga.


## AutoPort 0.46 — hybrid buildings in large 3D cities

- Show up to 8 real full 3D structures on Android (12 desktop) at the near edge of dense neighboring cities. Prioritize the genuine saved town hall and the visible edge. All other stored buildings remain in efficient MultiMesh LOD batches, without duplicate geometry.
- Unfinished building stages, visual cache reuse, camera transitions, resource conservation and small-screen UI are regression tested by detail_hybrid_v46.gd. Normal changes do not automatically rebuild APK or EXE.


## AutoPort 0.47 — teise linna päris 3D detailkaart

Teine linn avaneb maailmakaardilt ja linnapaneelist sama toimiva kaardivahetuse kaudu. Kaardi kõrvalruutudel kuvatakse päriselt ehitatud teise linna hooned ja ehitusplatsid, lähivaatel 3D mudelid ning kaugemal jõudluse säästvad LOD kujud. Teise linna detailvaate AI nupp lülitab ainult kohaliku ehitamise AI-d, mitte pealinna AI-d ega kogu riigi teadust. Kaubavahetus toimub endiselt tegelike karavanide ja iseseisva lao põhjal. Test `second_city_detail_v47.gd` kontrollib omandit, teise linna ehitamist, puidu vedu, kaartide vahel kaamera säilimist ja salvestuse ühilduvust. APK/EXE ehitus jääb käsitsi käivitatavaks.


## AutoPort 0.48 — isetekkivad teed ja liikuvad töötajad naaberdetailkaartidel

- Pealinna ja teise linna 3D eelvaated kuvavad nüüd ka tegeliku liikluse teel tekkinud jalgrajad ning linna salvestatud töötajad (metsatöölised, kiviraiujad ja ehitajad). 3D teed on `spatial_paths_v09.gd` `road_tiles()` samad liikluslahtrid — rajad tekivad vaid liikumisega ja kaovad, kui tee jääb piisavalt kauaks kasutamata.
- Teise linna töötajate ja teede vahemälu sõltub linna tõelisest `detail_sim` olekust. Eelvaates kasutatakse kahte väikest MultiMesh tõmmet ja telefoni jõudluse kaitseks maksimaalselt 120 teelahtrit ning 24 töötajat; 3D allikat ei tohi genereerimise ajal muuta.
- Oma linna hoonete, maakonna ja teise linna ehitusõigused ei muutu. Metsikus naaberruudus ei saa ehitada. Test `second_city_traffic_v48.gd` kontrollib puidu tegelikku korjamist ja toomist, loomulikku liiklusjälge, vanade teede hääbumist, naaberruudu 3D näitamist, materjalide iseseisvust ja salvestust.
- APK ning Windows EXE tehakse ainult käsitsi `workflow_dispatch` korral, mitte iga koodimuudatusega.


## AutoPort 0.49 — päris 3D kaubatee ja karavanid maailmakaardil

- Pealinna ja teise linna 3D maailmakaardil kuvatakse tegelik salvestatud maismaatee; 3D tee ei läbi merd ega mägesid ning kasutab üht instantsitud GPU-meshi. Mõlemad linnad on eraldi tähistatud.
- Mõlemas suunas liikuvad kaubavankrid järgivad samu \`progress / duration\` väärtusi kui 2D kaardil ning kaovad alles siis, kui algne majandussimulatsioon on kauba kohale toimetanud. Kaubavarud, veokulud ja marsruudi pikkused ei muutu.
- \`WorldMap.set_trade_route()\` värskendab korraga 2D ja 3D vaadet. Teed jäetakse mängukäikude vahel vahemällu; uuesti luuakse ainult liikuvad vankrid. Uue maailmaseemne või aegunud marsruudi korral vana tee eemaldatakse.
- \`world_trade_3d_v49.gd\` regressioon kontrollib liikuvat kaupa, mõlema suuna asukohti, saabumisaega, vahemälu, 2D/3D ühtivust ning mõlema linna ressursside puutumatust.
- APK ja Windows EXE ehitus jääb ainult käsitsi käivitatavaks.


### Godot 0.50 – Webi maastiku värvipaleti ühildamine

Godoti 3D maailmakaart, detailkaardi maapind, kõrvalruudud ja laiendatud linnaosad kasutavad nüüd sama deterministlikku veebimängu järgi valitud paletti: süvameri, rannavesi, rannaliiv, mets, rohumaa, kivine mägi ja niiske jõeserv. Kohalik detailpind ei ole enam igal ruudul täiesti ühetooniline. Värvivahetus ei muuda jõe pikkust, kõrgusi, majandusreegleid, ehitusruute ega salvestusi. Uus automaattest `web_biomes_v50.gd` kontrollib visuaali, determinismi ja mobiili detailvaadet. See on esimene osa ulatuslikumast graafikaportimisest; algsed Web GLB mudelid lisatakse eraldi.
