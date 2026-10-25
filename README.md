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
