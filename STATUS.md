# AutoPort staatus — 25.10.2026

**AutoPort 0.2.0: reeglite automaatimport ja kuue päris mängufunktsiooni kontroll Godotis.**

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
- Automaatsed upstream-kontrollid: `02:17`, `08:17`, `14:17` ja `20:17 UTC`; lisaks käsitsi `workflow_dispatch` (GitHubi ajastaja võib viibida).
- Kuus GDScripti mängufunktsiooni (linnamahud, asunikud, armeed, teadus ja linnakasv).
- JS vs Godot: 864 deterministlikku juhtumit, edukas töövoog: https://github.com/orogdor/Kuningriigid-Godot-AutoPort/actions/runs/40169211794
- Konkureerivate commit'ide puhul korduskatse ilma force-push'ita.
- Vana Godoti port ja veebimäng: muutmata.

**Piirangud:** kuus eraldiseisvat funktsiooni on üle kantud ja testitud, kuid kogu majandustsükkel, AI otsused, tehnoloogiapuu edenemine ega mängu visualiseerimine ei ole automaatselt tõlgitud. Godoti näidisvaade on ainult reeglite kontroll, mitte mängitav kampaania. Android APK puudub.

**Järgmine etapp:** ühendada need funktsioonid tõelise Godoti simulatsiooniseisundiga ning lisada linnade ressursside tootmine ja tarbimine, koos samade sisenditega JavaScripti ja Godoti võrdlustestidega.
