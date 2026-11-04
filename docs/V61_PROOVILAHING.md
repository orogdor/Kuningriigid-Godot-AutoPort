# AutoPort 0.61 — ühe vajutusega proovilahing

## Kuidas mängida
1. Ava **Kiviaja sõjavägi**.
2. Vajuta **Proovilahing kohe (tasuta)**. Laagrit, sõjapidamise teadust, ressursse ega värvatud armeed pole vaja.
3. 3D-lahingus on **3 × 24 oma sõdurit** (odamehed, kirvemehed, kiviviskajad) ja **24 vaenlast**. Vastane on päriselt juhitav lahingumootori poolt.
4. Demo alustab automaatselt võitlust. Vajuta **⏸ Peata võitlus**, kui tahad väesalgale või üksiksõdurile ise käske anda. Vajuta **▶ Jätka võitlust**, et simulatsioon edasi läheks.
5. **Kogu lahing**, **Suumi +/−** ja **Suumi sõdurile** muudavad kaamera suurust. Sihtpunkti liikumine toimib puudutusega.
6. Kui lahing lõpeb, vajuta **Proovilahing uuesti**, et alustaksid nullist.

## Mida demo EI tee
- See ei vähenda päris armee HP-d ega muuda kampaania raha, puitu, kivi, sõdureid või käiguloendurit.
- **Harjutuslahing päris vägedega** on eraldi nupp. Selle kaotused jäävad päris mängus alles.
- Tegemist on kiviaja lahingu testiga, mitte terve Three.js lahingusüsteemi 1:1 portimisega.
- Odameeste torked, kirvemeeste löögid, kiviviskajate liigutused ja tabamuse reaktsioonid on **protseduurilised poosid olemasolevatel GLB-mudelitel**. Need ei asenda veel luustikupõhist animatsiooni.

## Kohustuslik test
GitHub Actions käivitab `game/tests/battle_demo_v61.gd` päris `content.tscn` vaates:
- tühi linn -> tasuta demo -> 96 päris 3D GLB mudelit;
- aktiivne lahing, automaatne käik ja paus;
- sõdurite liikumine, käsud, salvestamine;
- 3 erineva sõdalasetüübi löögipoosid;
- lahing peab lõppema võiduga;
- kampaania ressursid ja päris armeed ei muutu;
- uus proovilahing peab käivituma samast kasutajaliidesest.

Vanad tasulise lahingu ja kampaanialahingu regressioonitestid jäävad alles.
