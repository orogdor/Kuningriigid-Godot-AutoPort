# AutoPort staatus — 24.10.2026

**AutoPort 0.1.0 on uues GitHubi repositooriumis käivitatud ja kontrollitud.**

- Repositoorium: https://github.com/orogdor/Kuningriigid-Godot-AutoPort
- Algne mäng: https://github.com/orogdor/Kuningriigid, ainult lugemine (muudatusi ei tehta).
- Esimene edukas GitHub Actions jooks: https://github.com/orogdor/Kuningriigid-Godot-AutoPort/actions/runs/40129777955
- Automaatne ülesvoolu lähtecommit: `681c0793fb6922b335926d353b66d297799b25a7`.
- Node.js turva/pariteedi testid: **6/6 läbitud**.
- Eksporditud andmerühmad: **15/15**, pluss `manifest.json`.
- Andmed: 111 tehnoloogiat, 26 teadusreformi, 20 kaubaliiki, 17 erikauba tootmishoonet, 6 ajastu materjalihinda.
- Sõltumatu allika-väljundi võrdsuskontroll: **edukas**, koos SHA-256 failiräsidega.
- Godot 4.4.1 headless import ja rakenduse käivitamine: **edukas**.
- GitHub Actionsi allalaaditav artefakt: `kuningriigid-godot-rules`.
- Automatiseeritud igapäevane kontroll: `04:17 UTC`; saadaval ka käsitsi `workflow_dispatch`.
- Vana Godoti port ja veebimäng: muutmata.

**Piirangud:** tegemist on statsionaarsete reeglite andmepordiga; tegelik Three.js majandus-, AI- ja teadusloogika ei ole veel automaatselt GDScripti tõlgitud. Godoti näidisvaade on ainult reeglite kontroll, mitte mängitav kampaania. Android APK puudub.

**Järgmine etapp:** iseseisvate majandus- ja teadusfunktsioonide ülekandmine koos samade sisendite väljundpariteedi testidega originaal-JavaScripti ning Godoti vahel.
