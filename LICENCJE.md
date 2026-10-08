# Zasoby i licencje

Kod gry i scenariusz: Piotr Piłka (z pomocą Claude). Poniższe zasoby pochodzą od innych autorów.

| Zasób | Autor / źródło | Licencja |
|---|---|---|
| Modele ludzi (mieszkańcy, klienci, policja) | Microsoft Rocketbox Avatar Library — github.com/microsoft/Microsoft-Rocketbox | MIT |
| Animacje postaci (Universal Animation Library 1 i 2), dawne sylwetki bazowe | Quaternius — quaternius.com | CC0 1.0 |
| Drzewa, krzewy, trawy (Stylized Nature MegaKit), rekwizyty i pies | Quaternius — quaternius.com | CC0 1.0 |
| Modele mebli i rekwizytów (m.in. stół, regał, kanapa, kosze, beczki) | Poly Haven — polyhaven.com | CC0 1.0 |
| Tekstury PBR (asfalt, beton, cegła, tynk, ziemia, blacha…) | Poly Haven — polyhaven.com | CC0 1.0 |
| Nieba HDRI (dzień, popołudnie, zmierzch, noc, deszcz) | Poly Haven — polyhaven.com | CC0 1.0 |
| Efekty dźwiękowe interfejsu i otoczenia | Kenney — kenney.nl | CC0 1.0 |
| Muzyka w klubie: „Night Prowler”, „Sewer Nightclub” | section31 — opengameart.org | CC0 1.0 |
| Muzyka w radiu: „The Root of All Evil” | Cleyton Kauffman — soundcloud.com/cleytonkauffman (opengameart.org) | CC0 1.0 |
| Muzyka w radiu: „Funky Disco Beats to Boogie/Woogie to” | Fupi — opengameart.org | CC0 1.0 |
| Muzyka w prologu: „Technomania101”; w zapasie „Party Sector” | Fupi; Joth — opengameart.org | CC0 1.0 |
| Odgłosy imprezy w prologu i wibracja telefonu (okrzyki, gwar, śpiew, wciąganie, torsje) | Joseph Sardin i inni — bigsoundbank.com | CC0 1.0 |
| Okrzyki i wiwaty bawiącej się grupy w prologu (`sfx/party/wiwat_*.wav`, `tlum.wav`; wycinki z „crowd partying cheering applause all around”, „Short Crowd Cheer”, „Woo Hoo”) | kyles, qubodup, Rocotilos — freesound.org/s/637468, /s/182571, /s/341488 | CC0 1.0 |
| Syrena policyjna: zawodzenie i szybki sygnał (`sfx/syrena_wail.wav`, `syrena_yelp.wav`; z „MISC_Police_Siren_Wailer_Static_001” i „Wail and Yelp”) | conleec, WBJB1 — freesound.org/s/159753, /s/223824 | CC0 1.0 |
| Łomot w drzwi i pukanie (`sfx/lomot_*.wav`, `pukanie.wav`; z „Door pounding – increasing intensity” i „Heavy Door Pounding”) | jhumbucker, mrh4hn — freesound.org/s/250539, /s/426618 | CC0 1.0 |
| Bieg kilku osób korytarzem (`sfx/bieg_korytarz.wav`; z „multiple people running” i „run in corridor”) | leoanderson67, cupido-1 — freesound.org/s/710765, /s/519640 | CC0 1.0 |
| Długie wciągnięcie nosem w prologu (`sfx/party/wciagniecie.wav`, przerobione z „Sniffing”) | spookymodem — https://opengameart.org/content/sniffing | CC-BY 3.0 |
| Ikony interfejsu | Lucide — lucide.dev | ISC |
| Czcionki: Barlow, Barlow Condensed, Bebas Neue, Oswald, Sedgwick Ave Display, Rubik Spray Paint | Google Fonts | SIL Open Font License 1.1 |
| Czcionka: Permanent Marker | Google Fonts | Apache License 2.0 |
| Silnik | Godot Engine — godotengine.org | MIT |

Licencja MIT biblioteki Microsoft Rocketbox jest w `godot/assets/people/LICENSE-Microsoft-Rocketbox.md`
(modele pobrane bez zmian, tekstury zmniejszone). Graffiti, plakaty, liście i trawa to własne tekstury gry,
generowane skryptami z `godot/tools/` (czcionki z listy powyżej).

Pełne teksty licencji czcionek są w `godot/assets/fonts/licencje/`, a licencja ikon Lucide w
`godot/assets/icons/LICENSE.txt`.

Muzyka (klub, radio w kawalerce, okna bloków) to nagrania na licencji CC0 z tabeli powyżej, w `godot/assets/music/`.
Syrena, deszcz, szum miasta, stukot kolejki, odgłosy prologu i „mamrotanie” postaci są generowane przez grę
(własna synteza). Modele z `godot/assets/models/` powstają ze skryptów Blendera w `godot/tools/blender/`.
Gra nie zawiera żadnych utworów chronionych prawem autorskim; pliki, które sam wrzucisz do `godot/muzyka/`,
pozostają Twoje i nie są częścią projektu.

## Ubrania na postaci (godot/assets/wear)

Siatki ubrań (bluza, kurtka, koszula, spodnie, rękawiczki, buty, komin, czapki) powstają skryptem
`godot/tools/blender/make_ubrania.py` z powierzchni awatara Microsoft Rocketbox (licencja MIT, patrz wyżej) —
są jego opracowaniem i podlegają tej samej licencji. Okulary, łańcuch, faktury tkanin i wszystkie detale są własne.

## Muzyka prologu (godot/assets/music/pro_*)

| Plik | Utwór i autor | Źródło | Licencja |
|---|---|---|---|
| pro_napiecie.mp3 | „Shadow Protocol” (track 1) — American Made Media (IndieDevs), https://x.com/TheArtBros1776 | https://opengameart.org/node/183126 | CC-BY 3.0 |
| pro_akcja.ogg | „Chase!” — Ted Kerr | https://opengameart.org/content/chase | CC0 |
| pro_skradanie.mp3 | „Savage Ambush” — Ruskerdax | https://opengameart.org/content/savage-ambush | CC0 |
| pro_final.mp3 | „Cinematic Epic Trailer – With SFX” (Cinematic Trailer Music) — Gregor Quendel | https://opengameart.org/content/cinematic-trailer-music-collection | CC-BY 4.0 |

`godot/assets/sfx/party/impreza_stereo.wav`: 31,6 s stereo z istniejącego nagrania kyles „crowd partying cheering applause all around”, https://freesound.org/s/637468/, CC0. Korekcja pasma, dopasowanie głośności i krótkie wygaszenia; źródło jest w `godot/tools/audio_src/`. Muzyka prologu pozostaje bez zmian.
