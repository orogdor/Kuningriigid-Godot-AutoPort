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

## AutoPort 0.2.0: mänguarvutuste kontroll\n\nGodotisse on viidud kuus eraldiseisvat arvutusreeglit: linnade arvu piirang, asunike loomise reeglid, armeede mahupiirang, teaduse ajastupõhine kulukordaja, linnade teaduskordaja ning pronksi-/rauaaja jõuka linna kasv.\n\nIga GitHub Actionsi töövoog loeb originaalseid JavaScripti mooduleid otse veebimängu `main` harust, genereerib nende tulemustest 864 deterministlikku testjuhtumit ning kontrollib Godot 4.4.1 headless-režiimis, kas GDScripti väljundid on samaväärsed. Pariteedihälve peatab töövoo. Sünkroonimiskontroll on seadistatud iga 6 tunni järel (GitHub võib käivitusi edasi lükata).\n\nOlulised failid: `game/scripts/logic_v02.gd`, `game/tests/logic_parity.gd` ja `tools/generate-logic-fixtures.mjs`. Automaatne tulemus asub Actionsi logis; APK ei ole veel loodud.\n\n## Järgmised etapid

1. **Puhas arvutusloogika:** majanduse, teaduse ja toiduvaru funktsioonide pariteeditestid Node.js ja GDScripti vahel.
2. **Simulatsiooniseisundi teisendus:** linna varud, asunikud, elanikkond, uurimistöö, kaubandus ja AI.
3. **200 käigu võrdlus:** kontrollitavad identsed lähteseisud ja mängutulemused.
4. **Godoti visuaalid:** detailkaart, maailmakaart, 3D hooned, mobiili UI ja üksused.
5. **Android:** alles seejärel APK ning uuendussüsteem ja telefonitestid.

**Oluline:** kontrolltabelite edukas import ei tähenda, et kogu Three.js mängumehaanika oleks Godotisse üle kantud. Ka käsitsi Godoti-spetsiifilist tööd jääb vaja.
