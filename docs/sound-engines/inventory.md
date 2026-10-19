# Sound engines by game

Found by scanning each game's own files in DOS_ACT and DOS_THNK (executables, overlays and
driver files) for each engine's signature strings and driver file names (19 Oct 2026). Games
whose folder holds no program files were scanned on their disc images instead, marked "on its
disc"; a disc can carry other programs, so those are less certain. Packed executables (LZEXE,
PKLITE) hide the strings: a few games appear as "own" whose trace shows a known engine (Hocus
Pocus: Apogee; Kyrandia 1 and 2, Dune II: the AIL 2 SB Pro driver built in).

- **Engine**: the engine found, or for the rest ("own"): the devices the game's code names or
  touches. "SB + AdLib", "SB", "AdLib": named in the text or a `mov dx,22xh`/`388h` in the code;
  "speaker": only the PC speaker's PIT channel 2; "nothing visible": no device found (often packed).
- **Names**: the devices named in the game's files (a setup menu's list).
- **Also**: GUS support; companies' layers beside the engine (Smacker video, Westwood, Origin).
- **Traced**: "yes" when an 86Box port trace exists (the engine pages use them); "no card traffic"
  when the game ran 35 s without touching the Sound Blaster (menus, FM-only music, a failed start).

## Totals

| Engine (as found) | Games |
|---|---|
| own: SB + AdLib | 141 |
| own: speaker | 105 |
| own: SB | 97 |
| Miles MSS 3 | 62 |
| own: AdLib | 59 |
| HMI SOS | 57 |
| own: nothing visible | 54 |
| Sierra SCI | 52 |
| Creative drv | 26 |
| own: runs from its disc | 19 |
| Miles AIL 2 | 18 |
| Miles | 15 |
| Miles AIL 2, DigPak/MidPak | 14 |
| AdLib driver | 11 |
| Apogee SS | 10 |
| DigPak/MidPak | 10 |
| DMX | 7 |
| MicroProse | 6 |
| Sound Images | 6 |
| HMI SOS (on its disc) | 5 |
| CMS | 4 |
| Miles, HMI SOS | 4 |
| Miles MSS 3, DiamondWare | 3 |
| Miles, DigPak/MidPak | 3 |
| iMUSE | 3 |
| Allegro | 3 |
| DSMI | 2 |
| Miles MSS 3, HMI SOS | 2 |
| Miles MSS 3, DigPak/MidPak | 2 |
| Creative drv (on its disc) | 2 |
| HMI SOS, Apogee SS | 2 |
| HMI SOS, DSMI | 2 |
| Loudness SS | 2 |
| Miles, HMI SOS (on its disc) | 2 |
| Melodix | 1 |
| CMS, Tandy | 1 |
| Miles, HMI SOS, DiamondWare | 1 |
| DMX (on its disc) | 1 |
| Miles, HMI SOS, DiamondWare, DSMI (on its disc) | 1 |
| DSMI/SDI | 1 |
| Miles, DiamondWare (on its disc) | 1 |
| HMI SOS, DigPak/MidPak | 1 |
| DSMI (on its disc) | 1 |
| HMI SOS, Sierra SCI | 1 |
| DMX, Apogee SS | 1 |
| Vision SL | 1 |
| MIDAS | 1 |
| Miles, HMI SOS, DMX, DSMI (on its disc) | 1 |
| Sound Images, Tandy | 1 |
| Miles (on its disc) | 1 |
| AdLib driver, Covox SDL | 1 |
| Miles, HMI SOS, DMX (on its disc) | 1 |
| AdLib driver, CMS, Tandy | 1 |
| Miles MSS 3, DigPak/MidPak, Creative drv | 1 |
| HMI SOS, iMUSE (on its disc) | 1 |
| Creative drv, iMUSE (on its disc) | 1 |
| Miles AIL 2, DigPak/MidPak, Sierra SCI | 1 |
| Tandy | 1 |
| HMI SOS, DMX, DSMI (on its disc) | 1 |
| DigPak/MidPak, Creative drv | 1 |
| DigPak/MidPak, Sierra SCI | 1 |
| Miles AIL 2, HMI SOS | 1 |

## Action library (DOS_ACT)

| Game folder | Engine | Names | Also | Traced |
|---|---|---|---|---|
| 1993 | own: speaker |  |  |  |
| 386SPYS | own: nothing visible |  |  |  |
| 3DBOMBER | own: SB | SB GM |  |  |
| ABUSE | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS | yes |
| ABZERO | Miles MSS 3 | SB AdLib MT-32 GM GUS PAS Speaker Tandy | GUS |  |
| ACSUPXRS | own: SB | SB |  |  |
| ADARK1 | own: SB + AdLib | SB AdLib GUS Tandy Covox | GUS |  |
| ADARK2 | own: SB + AdLib | SB AdLib GUS Tandy Covox | GUS |  |
| ADARK394 | own: SB + AdLib | SB AdLib GUS Tandy Covox | GUS |  |
| ADVTIN | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| AFRICANT | own: speaker |  |  |  |
| AFTERTHE | own: SB |  |  |  |
| AGE2 | own: SB + AdLib | SB AdLib |  |  |
| AIRBORNE | own: speaker | Tandy |  |  |
| AJACK | own: SB + AdLib | SB AdLib GUS Tandy Covox | GUS |  |
| ALIENBRE | Melodix | SB AdLib MT-32 |  | yes |
| ALIENBRT | own: runs from its disc |  |  |  |
| ALIENCAR | own: speaker |  |  |  |
| ALIENODY | Miles MSS 3 | SB AdLib MT-32 GM GUS PAS Speaker | GUS |  |
| ALIENRAM | Apogee SS | SB AdLib GM GUS PAS Tandy Covox | GUS |  |
| ALIENSYN | own: speaker | CMS |  |  |
| ALIENTRI | Miles MSS 3 | SB AdLib MT-32 GUS PAS Speaker | GUS |  |
| ALLEYCAT | own: speaker |  |  |  |
| AMOK | Miles | Speaker Tandy |  |  |
| AMZSMAN | own: nothing visible | Tandy |  |  |
| ANIGHTMA | own: SB | SB Tandy |  |  |
| ANIMAL | Miles MSS 3 | SB MT-32 GUS PAS Speaker Tandy | Smacker video, GUS |  |
| APB | own: nothing visible | Tandy |  |  |
| ARCHIMED | Miles MSS 3 | SB MT-32 GUS PAS Speaker Tandy | GUS |  |
| ARCTICFO | own: nothing visible | Tandy |  |  |
| ARCTICMO | Creative drv | SB |  |  |
| ARK88 | own: speaker |  |  |  |
| ARKA93 | own: SB |  |  |  |
| ARKANOI2 | CMS, Tandy | AdLib Tandy CMS |  |  |
| ARKANOID | own: nothing visible |  |  |  |
| ARMYMOVE | own: nothing visible |  |  |  |
| ASSAULTR | own: SB | SB GUS | GUS |  |
| ASTERIXG | own: speaker |  |  |  |
| ASTROFIR | own: speaker |  |  |  |
| AXEOFRAG | own: speaker | Tandy |  |  |
| BAAL | own: SB |  |  |  |
| BABYJOIN | own: AdLib | AdLib Tandy |  |  |
| BACKLASH | own: SB + AdLib | SB AdLib Speaker |  |  |
| BADBLOOD | CMS | AdLib MT-32 Tandy CMS Covox |  |  |
| BALLISTI | own: nothing visible |  |  |  |
| BANANOID | own: speaker |  |  |  |
| BARONBAL | own: SB + AdLib | SB |  |  |
| BARYON | own: SB | SB GM |  |  |
| BATMANCC | own: SB |  |  |  |
| BATRAC95 | own: SB | SB |  | yes |
| BATRET | Creative drv | SB AdLib |  |  |
| BATTLEAR | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| BCRACERS | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| BCSQUEST | Sierra SCI |  |  |  |
| BEETLEJU | own: speaker | Tandy |  |  |
| BEYONDCA | own: SB |  |  |  |
| BIGREDRA | Miles MSS 3 | SB AdLib MT-32 GUS PAS | GUS |  |
| BIOFORGE | Miles | SB AdLib MT-32 GM | Origin | no card traffic |
| BIOMENAC | own: AdLib | AdLib |  |  |
| BLACKTHO | Miles | SB AdLib MT-32 GM GUS PAS |  |  |
| BLAKESTA | own: SB + AdLib | SB AdLib |  | no card traffic |
| BLAKESTP | own: SB + AdLib | SB AdLib |  |  |
| BLASTER! | Miles MSS 3 | SB MT-32 GUS PAS Speaker Tandy | Smacker video, GUS |  |
| BLOOD | Apogee SS | SB AdLib MT-32 GM GUS PAS Speaker Tandy Covox | Smacker video, GUS | yes |
| BLOODMON | own: speaker |  |  |  |
| BLUBRO | own: AdLib |  |  |  |
| BLUBROJA | own: speaker |  |  |  |
| BODYBLOW | own: SB | SB |  | no card traffic |
| BOLO1993 | own: nothing visible |  |  |  |
| BRUCELEE | own: speaker |  |  |  |
| BSTORM | own: runs from its disc |  |  |  |
| BUBBBOBB | own: AdLib | AdLib Tandy CMS |  |  |
| BUBBLEDI | own: SB |  |  |  |
| CAPTAINC | own: speaker |  |  |  |
| CARDRIVE | DigPak/MidPak | SB AdLib MT-32 Speaker |  |  |
| CARMAGED | Miles, HMI SOS, DiamondWare | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | Smacker video, GUS | no card traffic |
| CASTLE91 | own: nothing visible |  |  |  |
| CASTLEVA | own: SB + AdLib | AdLib Tandy |  |  |
| CASTLEWO | own: speaker |  |  |  |
| CATACO2 | own: speaker |  |  |  |
| CATACO3D | own: AdLib | AdLib |  |  |
| CATACOMB | own: SB |  |  | no card traffic |
| CDOGS | DSMI |  |  | yes |
| CHASMTHE | own: SB + AdLib | SB AdLib GUS CMS | GUS |  |
| CKEEN1 | own: nothing visible |  |  |  |
| CKEEN2 | own: speaker |  |  |  |
| CKEEN3 | own: SB |  |  |  |
| CKEEN4 | own: AdLib | AdLib |  | no card traffic |
| CKEEN5 | own: AdLib | AdLib |  |  |
| CKEEN6 | own: AdLib | AdLib |  |  |
| CKEENDR | own: AdLib | AdLib |  |  |
| CONANTHE | own: runs from its disc |  |  |  |
| CONTINUU | own: SB | Tandy |  |  |
| CONTRA | own: speaker |  |  |  |
| COOLSPOT | Creative drv | SB AdLib PAS Speaker |  | yes |
| COSMOSCO | own: AdLib | Covox |  |  |
| COVERTAC | MicroProse | AdLib MT-32 Tandy |  | no card traffic |
| CRAZYCAR | own: nothing visible |  |  |  |
| CREATURE | own: SB | SB MT-32 GM GUS | GUS |  |
| CRIMEPAT | DMX (on its disc) |  |  |  |
| CRUSREGR | own: SB | SB GUS | Origin, GUS |  |
| CRUSREMO | own: SB | SB GUS | Origin | no card traffic |
| CRYPTICP | Apogee SS | SB AdLib MT-32 GM GUS PAS Speaker Tandy Covox | Smacker video, GUS |  |
| CRYSTALC | own: speaker |  |  |  |
| CURSEOFT | own: AdLib |  |  |  |
| CYBERDOG | DSMI | SB GUS PAS | GUS | yes |
| CYBERIA | own: SB | SB |  |  |
| CYBERIA2 | Miles, HMI SOS, DiamondWare, DSMI (on its disc) |  |  |  |
| CYBERMAG | HMI SOS | SB AdLib MT-32 GM GUS PAS Speaker Tandy Covox | GUS |  |
| CYCLONES | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| DANGDAVD | own: nothing visible |  |  |  |
| DANGDAVH | own: speaker |  |  |  |
| DANGDAVR | own: SB | Covox |  |  |
| DARKLIGH | Miles MSS 3 | SB MT-32 GUS PAS Speaker Tandy | GUS |  |
| DAVEGOES | own: speaker | Covox |  |  |
| DAVIDWOL | own: AdLib | AdLib MT-32 Tandy |  |  |
| DDRAGON | own: speaker | Tandy |  |  |
| DDRAGON2 | own: SB | Tandy |  |  |
| DDRAGON3 | own: SB + AdLib | SB AdLib MT-32 Speaker |  |  |
| DEATHRAL | own: SB + AdLib | SB |  | no card traffic |
| DEATHSWO | own: speaker |  |  |  |
| DEATHTRA | AdLib driver | SB AdLib MT-32 Speaker Tandy |  |  |
| DEDERBY | Miles MSS 3 | SB MT-32 GUS PAS | GUS |  |
| DEDERBY2 | Miles MSS 3 | SB MT-32 GUS PAS | GUS |  |
| DESCENT | HMI SOS | SB AdLib MT-32 GM GUS PAS Speaker | GUS | yes |
| DESCNT2V | Miles, HMI SOS | SB AdLib MT-32 GM GUS PAS Speaker Tandy Covox | GUS |  |
| DESERT | own: SB + AdLib | SB AdLib MT-32 Speaker Tandy |  |  |
| DESSTR | HMI SOS (on its disc) |  |  |  |
| DIEHARD | own: AdLib |  |  |  |
| DISNEYSA | DSMI/SDI | SB PAS Speaker Covox |  | no card traffic |
| DIZZYPRI | own: SB |  |  |  |
| DONKEY81 | own: speaker |  |  |  |
| DONKEYKO | own: nothing visible |  |  |  |
| DOOM | DMX | SB AdLib GUS PAS | GUS |  |
| DUKE3D | Apogee SS | SB AdLib MT-32 GM GUS PAS Speaker Tandy Covox | GUS | yes |
| DUKEN11 | own: speaker |  |  |  |
| DUKEN12 | own: speaker |  |  |  |
| DUKEN13 | own: speaker |  |  |  |
| DUKEN2 | own: AdLib |  |  |  |
| DWARS | Miles, DiamondWare (on its disc) |  |  |  |
| ECSTATI2 | own: SB | SB MT-32 GM GUS | GUS |  |
| ECSTATIC | own: SB | SB MT-32 GM GUS | GUS |  |
| ELF | own: SB + AdLib | SB AdLib MT-32 Tandy |  |  |
| ENIGMA96 | own: SB | SB |  |  |
| EPIC | Creative drv | SB AdLib MT-32 Speaker |  | yes |
| EWJ | own: SB + AdLib | SB GUS PAS CMS | GUS |  |
| EWJ2 | HMI SOS (on its disc) |  |  |  |
| EXTERMIN | own: AdLib | AdLib MT-32 |  |  |
| EXTREMEA | Miles MSS 3, HMI SOS | SB AdLib MT-32 GM GUS PAS Speaker Tandy | GUS |  |
| EXTREMER | Apogee SS | SB AdLib GM GUS PAS Speaker Tandy Covox | GUS |  |
| F40PURSU | own: speaker |  |  |  |
| FADETOBL | Miles MSS 3 | SB AdLib MT-32 GM GUS PAS Speaker | GUS |  |
| FANTASYW | own: speaker |  |  |  |
| FINALDOO | DMX | SB AdLib GUS PAS | GUS |  |
| FIREAICE | own: speaker |  |  |  |
| FIREHAWK | Sierra SCI | SB AdLib MT-32 Speaker Tandy CMS |  |  |
| FIREPOWE | own: speaker |  |  |  |
| FIROKLAW | Miles MSS 3 | SB AdLib MT-32 GM GUS PAS Speaker Tandy | Smacker video, GUS |  |
| FIRSTSAM | own: SB + AdLib | SB AdLib Speaker |  |  |
| FLASHBAC | own: SB + AdLib | SB MT-32 Speaker |  | no card traffic |
| FLY1984 | own: nothing visible |  |  |  |
| FLYINGT2 | own: SB + AdLib | SB GUS PAS | GUS |  |
| FLYINGTI | own: SB + AdLib | SB GUS PAS | GUS |  |
| FRANKOTH | own: SB | SB GUS | GUS |  |
| FUTUREDI | own: speaker |  |  |  |
| FXFIGHTE | own: SB + AdLib | SB GUS | GUS |  |
| GALACTIX | own: SB + AdLib | SB AdLib |  |  |
| GAUNTLE2 | own: nothing visible | Tandy |  |  |
| GAUNTLET | own: speaker |  |  |  |
| GHOSTBU2 | AdLib driver | AdLib MT-32 Speaker Tandy |  |  |
| GHOSTSNG | own: speaker |  |  |  |
| GODS | own: SB + AdLib | SB AdLib MT-32 Speaker Tandy |  | no card traffic |
| GOLDENAX | AdLib driver | AdLib |  | no card traffic |
| GREATESC | own: nothing visible |  |  |  |
| GTA | Miles MSS 3, DiamondWare | SB AdLib MT-32 GUS PAS Speaker Tandy | Smacker video, GUS | yes |
| GTRACING | own: SB |  |  |  |
| HARLEY-D | own: SB + AdLib |  |  |  |
| HERETICS | DMX | SB AdLib GUS PAS | GUS |  |
| HEXENBEY | DMX | SB AdLib GUS PAS | GUS | yes |
| HEXENDEA | DMX | SB AdLib GUS PAS | GUS |  |
| HOCUSPOC | own: SB + AdLib | SB AdLib GM GUS PAS Covox | GUS | yes |
| HORRORZO | own: nothing visible |  |  |  |
| HYPERSPE | own: SB + AdLib | SB AdLib |  |  |
| IAS | own: speaker |  |  |  |
| IGNITION | own: SB | SB |  |  |
| INCA1 | own: SB + AdLib | SB |  |  |
| INCA2 | own: SB + AdLib | SB AdLib |  | no card traffic |
| INFERNO | Miles, DigPak/MidPak | SB AdLib MT-32 GUS PAS Speaker Tandy Covox |  |  |
| INNERWOR | own: SB | SB GUS | GUS |  |
| INTERPHA | own: SB + AdLib | AdLib Tandy |  |  |
| INTOTHEE | own: speaker |  |  |  |
| IRONASSA | own: SB + AdLib | SB AdLib |  |  |
| JAMESPON | own: SB + AdLib |  |  |  |
| JAWS89 | own: speaker |  |  |  |
| JAZZCD | own: SB | SB GUS PAS | GUS |  |
| JAZZJACK | own: SB | SB GUS | GUS |  |
| JILLGU | Creative drv | SB AdLib GUS |  |  |
| JILLJUNG | Creative drv | SB AdLib GUS |  | yes |
| JILLSTP | Creative drv | SB AdLib GUS |  |  |
| JOEMACCA | own: nothing visible |  |  |  |
| JOHNNYBA | own: nothing visible |  |  |  |
| JUNGLEST | HMI SOS | SB AdLib GUS PAS Speaker Tandy Covox |  |  |
| JURASSIC | own: SB + AdLib | AdLib |  |  |
| KARATEKA | own: nothing visible |  |  |  |
| LAMBORGH | own: AdLib |  |  |  |
| LASTNINJ | own: speaker | Tandy |  |  |
| LBA | Miles | SB AdLib MT-32 GUS PAS Tandy | GUS | yes |
| LEGENDS | own: runs from its disc |  |  |  |
| LETHALWE | own: SB + AdLib | AdLib MT-32 |  |  |
| LEWLEON | own: SB | SB GUS Covox | GUS |  |
| LIERO | own: SB | SB |  | yes |
| LIGHTSPE | MicroProse | SB AdLib MT-32 Tandy |  |  |
| LOLLYPOP | own: AdLib | AdLib MT-32 |  |  |
| LOTUSTHE | own: nothing visible |  |  |  |
| LUCKYLUK | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| MACH3 | own: nothing visible |  |  |  |
| MADDOGII | own: runs from its disc |  |  |  |
| MADDOGMC | own: AdLib | AdLib |  |  |
| MADMIX | own: speaker |  |  |  |
| MAGCARP | HMI SOS, DigPak/MidPak | SB AdLib MT-32 GM GUS PAS Speaker Tandy Covox |  |  |
| MAGCARP2 | Miles MSS 3 | SB AdLib MT-32 GM GUS PAS Tandy | GUS |  |
| MAGICLAN | own: SB |  |  |  |
| MANICKAR | own: nothing visible |  |  |  |
| MASSDEST | Miles MSS 3 | SB MT-32 GUS PAS Speaker | GUS |  |
| MCKIDS | own: SB + AdLib | AdLib CMS |  |  |
| MDK | HMI SOS | SB AdLib GUS PAS Speaker Tandy Covox | GUS | yes |
| MECHW2 | Miles MSS 3, DigPak/MidPak | SB AdLib MT-32 GM GUS PAS Speaker Tandy CMS | Smacker video, GUS |  |
| MECHW2M | Miles MSS 3 | SB AdLib MT-32 GUS PAS Speaker CMS | Smacker video, GUS |  |
| MEGAMANX | Miles MSS 3 | SB AdLib MT-32 GM GUS PAS Speaker Tandy | GUS |  |
| MEGARAC2 | Miles MSS 3 | SB MT-32 GUS PAS Speaker Tandy | GUS |  |
| MEGARACE | DSMI (on its disc) |  |  |  |
| METALGEA | own: SB + AdLib |  |  |  |
| METALMUT | own: AdLib |  |  |  |
| METLTECB | HMI SOS, Sierra SCI | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| METLTECE | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| MICROMA2 | own: SB | SB GUS | GUS |  |
| MICROMAC | Sound Images |  |  |  |
| MK | Miles MSS 3 | SB AdLib MT-32 GUS PAS | GUS | no card traffic |
| MK2 | Sound Images | SB MT-32 GUS |  | no card traffic |
| MKTRIL | Miles MSS 3, HMI SOS | SB AdLib MT-32 GM GUS PAS Speaker Tandy | Smacker video, GUS |  |
| MONSTERB | own: SB + AdLib | AdLib |  |  |
| MONTYPYT | AdLib driver | AdLib |  |  |
| MONUMENT | own: speaker |  |  |  |
| MOTORMA | Miles MSS 3 | SB MT-32 GUS PAS Speaker Tandy | Smacker video, GUS |  |
| MWARRIOR | AdLib driver | AdLib MT-32 Speaker Tandy |  |  |
| MYSTMIDP | own: runs from its disc |  |  |  |
| MYSTMIDR | own: runs from its disc |  |  |  |
| MYSTTOW | own: SB | SB Speaker |  |  |
| NIGHTRAI | own: SB |  |  |  |
| NIGHTSHI | own: AdLib | Tandy |  |  |
| NINJA | own: speaker |  |  |  |
| NINJAGA2 | own: AdLib | AdLib |  |  |
| NINJAGAI | own: speaker |  |  |  |
| NOVA9RET | own: SB + AdLib | SB AdLib MT-32 Tandy |  |  |
| NOVASTOR | own: runs from its disc |  |  |  |
| ONEMUSTF | own: SB | SB GUS | GUS |  |
| OPWOLF | own: AdLib | AdLib Tandy CMS |  |  |
| OSCAR | Creative drv (on its disc) |  |  |  |
| OSTEALTH | own: AdLib | AdLib |  |  |
| OUTOFTHI | own: nothing visible |  |  |  |
| OVERKI92 | own: nothing visible |  |  |  |
| PACIN-T | own: SB + AdLib | SB AdLib |  |  |
| PANGO | own: speaker |  |  |  |
| PAPERBO2 | Creative drv | SB AdLib Speaker Tandy |  |  |
| PAPERBOY | own: SB |  |  |  |
| POPCORN | own: speaker |  |  |  |
| POWERDRO | own: AdLib | AdLib MT-32 Tandy |  |  |
| PPERSIA | own: SB + AdLib | SB AdLib MT-32 PAS Speaker Tandy CMS Covox |  |  |
| PPERSIA2 | CMS | SB AdLib MT-32 GM PAS Speaker Tandy CMS Covox |  |  |
| PREHIST2 | own: SB + AdLib | SB |  |  |
| PREHISTO | Creative drv | SB AdLib MT-32 Tandy |  | yes |
| PRIMALRA | Miles MSS 3 | SB AdLib MT-32 GM GUS PAS Speaker Tandy | GUS |  |
| PRIV2SE | Miles MSS 3 | SB MT-32 GUS PAS Speaker Tandy CMS | Origin, GUS |  |
| PROJECTP | own: SB + AdLib | AdLib |  |  |
| PROTO | own: SB | SB GUS |  |  |
| QUAKE | own: SB + AdLib | SB AdLib GUS | GUS |  |
| QUAKEM1 | own: SB + AdLib | SB AdLib GUS | GUS |  |
| QUAKEM2 | own: SB + AdLib | SB AdLib GUS | GUS |  |
| QUARANT | Miles, HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| QUARANT2 | HMI SOS | SB AdLib MT-32 GUS PAS | GUS |  |
| RADWARRI | own: speaker |  |  |  |
| RAMPAGE | own: speaker | Tandy |  |  |
| RAPTORCA | DMX, Apogee SS | SB AdLib MT-32 GM GUS PAS Speaker Covox | GUS | yes |
| RASTAN | own: AdLib | AdLib Tandy CMS |  |  |
| RAYMAN | HMI SOS | SB AdLib GUS PAS Speaker Tandy Covox | GUS | yes |
| RAYMANF | HMI SOS | SB AdLib GUS PAS Speaker Tandy CMS Covox | GUS |  |
| REALMSOF | Apogee SS | SB AdLib MT-32 GM GUS PAS Speaker Covox | GUS | yes |
| REDRAM | Apogee SS | SB AdLib MT-32 GM GUS PAS Speaker Tandy Covox | GUS |  |
| REDRAMRA | HMI SOS, Apogee SS | SB AdLib MT-32 GM GUS PAS Speaker Tandy Covox | GUS |  |
| RENBFJS | Miles AIL 2 | SB MT-32 GUS PAS Speaker Covox | GUS |  |
| RICKDAN2 | AdLib driver | AdLib Tandy |  |  |
| RICKDANG | own: nothing visible | Tandy |  |  |
| RISKYWOO | own: SB + AdLib | SB AdLib MT-32 Speaker |  |  |
| ROBOCOP | own: SB | Tandy |  |  |
| ROBOCOP3 | Creative drv | SB AdLib MT-32 Speaker |  |  |
| ROTH | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| ROTTDW | Apogee SS | SB AdLib GM GUS PAS Speaker Tandy Covox | GUS | yes |
| SANGOFI2 | own: speaker |  |  |  |
| SANGOFIG | own: SB + AdLib | SB AdLib MT-32 GM Speaker |  |  |
| SAVAGEWA | Miles AIL 2 | SB AdLib MT-32 GM GUS | GUS |  |
| SCREAMER | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS | yes |
| SCREAMR2 | HMI SOS, DSMI | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| SCRMRAL | HMI SOS, DSMI | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| SEALTEAM | Miles AIL 2, DigPak/MidPak | SB AdLib MT-32 PAS Speaker Tandy |  |  |
| SECRETAG | own: speaker | Speaker |  |  |
| SEEKANDD | Vision SL | SB GUS PAS |  | yes |
| SF | own: speaker | CMS |  |  |
| SF2 | own: SB + AdLib | SB AdLib MT-32 |  |  |
| SHADCAST | Miles | SB MT-32 |  |  |
| SHADOWWA | Apogee SS | SB AdLib MT-32 GM GUS PAS Speaker Tandy Covox | GUS | yes |
| SHATTERE | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy CMS Covox | GUS |  |
| SHELLSHO | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS | yes |
| SHINOBI | own: speaker | Tandy |  |  |
| SHUTTLET | own: SB | MT-32 |  |  |
| SILPHEED | Sierra SCI | SB MT-32 Speaker Tandy CMS |  |  |
| SKYNET | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| SKYRDS | own: speaker |  |  |  |
| SKYRDSX | own: AdLib |  |  |  |
| SLEEPWAL | own: runs from its disc |  |  |  |
| SLICKSNS | own: speaker |  |  |  |
| SLIPSTRE | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| SOCCERKI | own: SB | SB |  |  |
| SOD3D | own: AdLib | AdLib |  |  |
| SOPWITH | own: nothing visible |  |  |  |
| SPACAC2 | own: SB + AdLib | SB AdLib PAS Tandy |  |  |
| SPACEACE | own: SB + AdLib | SB AdLib Tandy |  |  |
| SPEEDRAC | own: SB + AdLib | SB AdLib MT-32 PAS Speaker CMS |  |  |
| SPIROU | HMI SOS | SB AdLib GUS | GUS |  |
| SSF2T | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| SSTRDUST | MIDAS | SB GUS PAS | GUS | yes |
| STARCRUS | own: nothing visible |  |  |  |
| STARGUNN | own: SB | SB GUS PAS | GUS |  |
| STDS9HAR | Miles MSS 3 | SB AdLib MT-32 GUS PAS Speaker Tandy | Smacker video, GUS |  |
| STELLAR7 | own: runs from its disc |  |  |  |
| STORM96 | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| STREETRA | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| STRIDER | own: speaker |  |  |  |
| STUNTDRI | own: SB + AdLib | Tandy |  |  |
| STUNTS | own: SB + AdLib | SB AdLib MT-32 Speaker Tandy |  |  |
| STUNTTRA | own: nothing visible |  |  |  |
| SUPERC | own: AdLib | AdLib Tandy |  |  |
| SUPERFRO | own: SB | SB GUS | GUS |  |
| SUPERKAR | own: nothing visible |  |  |  |
| SWDFORC | iMUSE | SB AdLib MT-32 GM GUS PAS | GUS | yes |
| SWIV3D | Miles MSS 3 | SB MT-32 GUS PAS Speaker Tandy | Smacker video, GUS |  |
| SWRA | own: runs from its disc |  |  |  |
| SWRA2 | Miles, HMI SOS, DMX, DSMI (on its disc) |  |  |  |
| SWTIECD | iMUSE | SB AdLib MT-32 GM GUS PAS | GUS | yes |
| SWXWCD | iMUSE | SB AdLib MT-32 GM GUS Speaker | GUS | yes |
| SYSTEMSH | Miles MSS 3 | SB AdLib MT-32 GM GUS PAS Speaker Tandy |  | yes |
| TAITOSSU | Sound Images, Tandy | AdLib MT-32 Tandy |  |  |
| TEMPEST2 | Sierra SCI | SB AdLib MT-32 GUS | GUS |  |
| TERMFS | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| TERMRAMP | Miles (on its disc) |  |  |  |
| TERMVEL | Miles AIL 2, DigPak/MidPak | SB AdLib GM GUS PAS Speaker Tandy Covox | GUS |  |
| THECATAC | own: AdLib |  |  |  |
| THECYCLE | own: SB + AdLib | AdLib Tandy |  |  |
| THEFANTA | own: SB + AdLib | SB AdLib Speaker |  |  |
| THELASTB | own: runs from its disc |  |  |  |
| THELASTN | own: speaker | Tandy |  |  |
| THELIONK | own: SB | SB GUS PAS Covox | GUS |  |
| THEPUNIS | AdLib driver, Covox SDL | AdLib Speaker Tandy Covox |  |  |
| THESMURF | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| THETHREE | own: speaker |  |  |  |
| THEXDER | Sierra SCI | Tandy |  |  |
| THUNSTRI | own: nothing visible |  |  |  |
| TIMEWARR | own: SB + AdLib | SB |  |  |
| TIMMORTA | own: AdLib | AdLib |  |  |
| TINTININ | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| TNFSSE | own: SB | SB GUS | GUS |  |
| TOMBRAIG | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS | yes |
| TOOBIN | own: nothing visible | Tandy |  |  |
| TOWERTOP | own: speaker | Tandy |  |  |
| TRACKATT | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| TRAFFICD | own: SB + AdLib | SB AdLib Speaker |  |  |
| TROLLS | own: nothing visible |  |  |  |
| TSTDRIV | own: SB |  |  |  |
| TSTDRIV3 | CMS | SB AdLib MT-32 Tandy CMS |  |  |
| TSTDRIVO | Miles MSS 3 | SB MT-32 GUS PAS Speaker Tandy | GUS |  |
| TUBULARW | own: SB + AdLib |  |  |  |
| TUNNELB1 | HMI SOS (on its disc) |  |  |  |
| TWINSEN | Miles MSS 3, DiamondWare | SB AdLib MT-32 GUS PAS Speaker Tandy | Smacker video, GUS |  |
| TYRIAN | Loudness SS | SB AdLib GM GUS |  | yes |
| TYRIAN20 | Loudness SS | SB AdLib GUS |  |  |
| UBODYBLO | own: nothing visible |  |  |  |
| UGH! | own: AdLib |  |  |  |
| ULTDOOM | DMX | SB AdLib GUS PAS Speaker | GUS |  |
| VETTE! | own: SB + AdLib |  |  |  |
| VINYLGOD | own: AdLib | AdLib |  |  |
| WACKYWHE | own: SB + AdLib | SB AdLib GM GUS PAS Speaker Covox | GUS |  |
| WALTDISN | own: SB + AdLib | SB AdLib GUS Covox |  |  |
| WC | own: SB + AdLib | SB AdLib MT-32 Speaker Tandy | Origin | no card traffic |
| WC2DLX | own: SB + AdLib | SB AdLib MT-32 Speaker Tandy | Origin | no card traffic |
| WC3HOTT | Miles, HMI SOS, DMX (on its disc) |  |  |  |
| WC4POF | Miles, HMI SOS | SB AdLib GUS PAS Covox | Origin, GUS |  |
| WCACAD | Miles AIL 2 | SB AdLib MT-32 | Origin |  |
| WCPRIV | Miles | SB AdLib MT-32 GM PAS | Origin |  |
| WDREAMS | own: AdLib | AdLib Tandy |  |  |
| WETLANDS | Miles MSS 3 | SB MT-32 GUS PAS Speaker | GUS |  |
| WHIPLASH | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy CMS Covox | GUS |  |
| WINGCOMM | Miles AIL 2 | SB AdLib MT-32 GM | Origin | no card traffic |
| WINGNUTS | Miles |  |  |  |
| WINGSOFF | own: speaker |  |  |  |
| WIPEOUT | own: runs from its disc |  |  |  |
| WITCHAV2 | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| WITCHAVE | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| WIZBALL | own: speaker |  |  |  |
| WOLF3D | own: AdLib | AdLib |  |  |
| WORLDRAL | own: SB |  |  |  |
| XARGON | Creative drv | SB |  | yes |
| XCAREXPE | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| XENON | own: nothing visible | Tandy |  |  |
| XENON2ME | own: speaker | Tandy |  |  |
| XIYOUJI | own: speaker |  |  |  |
| XMENCHI | Miles MSS 3 | SB MT-32 GUS PAS Speaker Tandy | GUS |  |
| YO!JOE!B | own: SB | SB Covox |  |  |
| ZONE66 | own: SB + AdLib | SB AdLib GUS |  |  |
| ZOOL2 | own: nothing visible |  |  |  |
| ZOOL93 | own: nothing visible |  |  |  |

## Thinking library (DOS_THNK)

| Game folder | Engine | Names | Also | Traced |
|---|---|---|---|---|
| 1869 | own: nothing visible |  |  |  |
| 4CRYSTR | Sound Images | MT-32 Tandy |  |  |
| 7THGUEST | Miles AIL 2, DigPak/MidPak | SB AdLib MT-32 GUS PAS Tandy Covox | GUS | yes |
| A-PAC | Allegro | SB AdLib GUS | GUS | yes |
| A-TRAIN | own: SB + AdLib | SB AdLib MT-32 Speaker Tandy Covox |  |  |
| ADOM | own: speaker |  |  |  |
| AEGO | own: speaker |  |  |  |
| AFAB1985 | own: speaker |  |  |  |
| AFRAID | own: runs from its disc |  |  |  |
| ALBION | Miles MSS 3 | SB AdLib MT-32 GM GUS PAS Speaker Tandy | GUS | yes |
| ALIELOGI | own: SB + AdLib | SB AdLib GUS | GUS |  |
| ALIENLEG | Miles MSS 3 | SB AdLib MT-32 GM GUS PAS | GUS |  |
| ALQADIM | Miles | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS | yes |
| ALTREAL | own: speaker |  |  |  |
| AMBRSTAR | own: AdLib |  |  |  |
| AMBSORI | DigPak/MidPak | SB AdLib Speaker |  |  |
| AMONRA | Sierra SCI | SB AdLib MT-32 GM PAS Speaker Tandy CMS Covox |  |  |
| AMULARM | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| ANVLDAWN | HMI SOS | SB AdLib MT-32 GM GUS PAS Speaker Tandy Covox | GUS |  |
| ARCHIPEL | own: SB |  |  |  |
| ARTHURQE | own: speaker |  |  |  |
| ASCENDY | Miles MSS 3 | SB MT-32 GUS PAS | GUS |  |
| ASHEMPI | own: SB + AdLib | SB AdLib MT-32 Speaker |  |  |
| BALAOPOW | own: SB + AdLib | AdLib |  |  |
| BALL | own: nothing visible |  |  |  |
| BANDKING | own: nothing visible |  |  |  |
| BARDTAL1 | own: speaker | Tandy |  |  |
| BARDTAL2 | own: speaker | Tandy |  |  |
| BARDTAL3 | own: AdLib | AdLib MT-32 Tandy |  |  |
| BASS | own: nothing visible |  |  |  |
| BAT | own: SB |  |  |  |
| BATLBUGS | own: SB + AdLib | SB AdLib PAS Speaker Tandy Covox |  |  |
| BATLTEC2 | AdLib driver, CMS, Tandy | SB AdLib MT-32 Speaker Tandy CMS Covox |  |  |
| BATLTECH | own: SB | Tandy |  |  |
| BATSPIRE | Miles MSS 3 | SB MT-32 GUS PAS Speaker Tandy | Smacker video, GUS |  |
| BEAMISH | Sierra SCI | SB AdLib MT-32 PAS Speaker Tandy CMS |  |  |
| BEYZORK | own: SB | SB Tandy |  |  |
| BGORGON | own: SB + AdLib | SB PAS CMS |  |  |
| BISLE | own: SB + AdLib | AdLib CMS |  |  |
| BISLE2 | Miles AIL 2 | SB AdLib MT-32 GM PAS Speaker Tandy |  |  |
| BLDWYCH | own: SB + AdLib | AdLib MT-32 Tandy |  |  |
| BLSTDWAR | DigPak/MidPak | SB AdLib Speaker |  |  |
| BOMBERMA | own: SB | SB |  |  |
| BOP1990 | own: SB + AdLib | AdLib |  |  |
| BOPPIN | Apogee SS | SB AdLib GM GUS PAS Tandy Covox | GUS | yes |
| BRCDOOM | own: AdLib | AdLib Speaker Tandy |  |  |
| BRIX93 | Creative drv | SB |  |  |
| BRMATRIX | own: SB + AdLib | SB AdLib MT-32 Speaker Tandy |  |  |
| BSWORD1 | Miles MSS 3 | SB MT-32 GUS PAS Speaker | Smacker video, GUS |  |
| BUBBBRI | Miles MSS 3 | SB AdLib MT-32 GM GUS PAS Speaker Tandy | GUS |  |
| BUREAUC | own: speaker | Tandy |  |  |
| BURNTIME | Creative drv | SB |  |  |
| BUSTMOV2 | Miles MSS 3 | SB MT-32 GUS PAS Speaker Tandy CMS | GUS |  |
| CADAVER | Sound Images | SB AdLib MT-32 |  | yes |
| CADAVPAY | Sound Images | SB AdLib MT-32 Tandy |  |  |
| CAESAR | Miles MSS 3, DigPak/MidPak, Creative drv | SB AdLib Speaker |  | yes |
| CAESAR2 | Miles MSS 3 | SB AdLib MT-32 GM GUS PAS Speaker Tandy | GUS |  |
| CAMELOT | Sierra SCI | SB AdLib MT-32 Speaker Tandy CMS |  |  |
| CANNFOD | Miles, HMI SOS (on its disc) |  |  |  |
| CANNFOD2 | own: SB |  |  |  |
| CAPBLUD | own: speaker |  |  |  |
| CAPTIVER | own: SB + AdLib | SB AdLib MT-32 |  |  |
| CAPTLSM | Miles AIL 2, DigPak/MidPak | SB AdLib MT-32 GM GUS PAS Speaker Tandy Covox |  | yes |
| CAPTLSMP | Miles AIL 2, DigPak/MidPak | SB AdLib MT-32 GM GUS PAS Speaker Tandy Covox |  |  |
| CARICOMM | own: speaker |  |  |  |
| CASTLES2 | Miles AIL 2 | SB AdLib MT-32 GM PAS Speaker Tandy |  | yes |
| CBLOOD | HMI SOS (on its disc) |  |  |  |
| CCORPSE | own: speaker |  |  |  |
| CELTTALE | AdLib driver | SB AdLib MT-32 |  |  |
| CENTDOR | own: SB + AdLib | AdLib MT-32 Tandy |  |  |
| CEO | own: SB | SB MT-32 |  |  |
| CHIPCHAL | own: SB + AdLib |  |  |  |
| CKRYNN | own: AdLib | AdLib MT-32 Tandy CMS |  |  |
| COMCON | HMI SOS | SB AdLib GUS PAS Speaker Tandy Covox | Westwood, GUS | yes |
| COMCONRA | HMI SOS | SB AdLib GUS PAS Speaker Tandy Covox | Westwood, GUS |  |
| CONQESTN | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| CONSTRUC | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| CONTZACK | Miles AIL 2, DigPak/MidPak | SB AdLib MT-32 Speaker Tandy Covox |  |  |
| COUNTDWN | own: SB + AdLib | SB AdLib Covox |  |  |
| CREEPRS | own: speaker |  |  |  |
| CRYARBOR | own: SB + AdLib | SB AdLib Speaker |  |  |
| CURSE | own: SB | Tandy |  |  |
| DARKLAND | MicroProse | SB AdLib MT-32 PAS Covox |  | yes |
| DARKNESS | own: SB + AdLib | SB AdLib |  |  |
| DARKSEED | Creative drv | SB AdLib Speaker |  | yes |
| DEADLINE | own: SB | SB Tandy |  |  |
| DEATH | Miles MSS 3 | SB AdLib MT-32 GM GUS PAS Tandy | GUS |  |
| DETROIT | Miles AIL 2, DigPak/MidPak | SB AdLib MT-32 PAS Speaker Tandy Covox |  | yes |
| DEUS | own: SB + AdLib | SB |  |  |
| DGENER | own: AdLib | AdLib |  |  |
| DIG | HMI SOS, iMUSE (on its disc) |  |  |  |
| DKKRYNN | own: AdLib | AdLib Tandy CMS |  |  |
| DOTT | Creative drv | AdLib MT-32 |  |  |
| DRAGONLO | own: AdLib | AdLib Tandy |  |  |
| DRAGONST | own: speaker | Tandy |  |  |
| DRFLAME | own: speaker | Tandy |  |  |
| DRKHRTUU | own: nothing visible | Tandy |  |  |
| DRKQUEEN | own: SB + AdLib | SB AdLib MT-32 Speaker Tandy |  |  |
| DRUGLORD | own: speaker |  |  |  |
| DSUN | own: SB + AdLib | SB AdLib MT-32 GUS | GUS |  |
| DUMAST1 | own: nothing visible | Tandy |  |  |
| DUMAST2 | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| DUNE | own: AdLib | MT-32 |  |  |
| DUNE2 | own: SB + AdLib | SB AdLib MT-32 Speaker Tandy CMS | Westwood | yes |
| DUNGKEEP | Miles MSS 3 | SB AdLib MT-32 GUS PAS Speaker Tandy | Smacker video, GUS | yes |
| DW1 | Miles MSS 3 | SB AdLib MT-32 GM GUS PAS Speaker Tandy | GUS |  |
| DW2 | Miles MSS 3 | SB MT-32 GM GUS PAS Speaker | GUS |  |
| ELITE | own: speaker |  |  |  |
| ELITEP | own: AdLib | AdLib MT-32 Speaker |  |  |
| ELVIRA1 | own: SB + AdLib | SB AdLib MT-32 Speaker Tandy CMS |  |  |
| ELVIRA2 | own: SB + AdLib | SB AdLib MT-32 Speaker Tandy |  |  |
| ENCHA | own: SB | SB Tandy |  |  |
| EOB1 | own: SB + AdLib | SB AdLib Tandy |  |  |
| EOB2 | own: SB + AdLib | SB AdLib Tandy |  |  |
| EOB3 | Miles AIL 2, DigPak/MidPak | SB AdLib MT-32 Speaker |  | yes |
| ERICUN | own: SB + AdLib | SB AdLib MT-32 Speaker |  |  |
| ESARENA | Miles AIL 2 | SB AdLib MT-32 GM GUS PAS | GUS |  |
| ESDAGGER | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy CMS Covox | GUS |  |
| ETERNAM | own: SB + AdLib | SB AdLib Tandy Covox |  |  |
| EXTASE | own: AdLib | AdLib Tandy |  |  |
| FALLOUT1 | HMI SOS | SB AdLib GM GUS PAS Speaker Tandy Covox | GUS |  |
| FANTEMPI | Miles AIL 2 | SB AdLib MT-32 GM GUS PAS Speaker Tandy Covox |  | yes |
| FANTGEN | Miles MSS 3 | SB MT-32 GUS PAS Speaker CMS | GUS |  |
| FLAMFREE | own: SB + AdLib | AdLib MT-32 |  |  |
| FOUNDREA | own: speaker |  |  |  |
| FQUEEN | own: runs from its disc |  |  |  |
| FREDDY | Sierra SCI | SB AdLib MT-32 GM PAS Speaker Tandy CMS Covox |  |  |
| FRONTIER | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| FRONTIR2 | own: AdLib | AdLib |  |  |
| FULLT | own: SB + AdLib | SB AdLib GUS | GUS |  |
| FWARS | own: SB |  |  |  |
| GATESF | DigPak/MidPak | SB AdLib Speaker Tandy |  |  |
| GATEWAY | own: nothing visible |  |  |  |
| GATEWAY2 | own: SB + AdLib | SB AdLib MT-32 |  |  |
| GEMFIRE | AdLib driver | MT-32 |  |  |
| GHENKHN | own: nothing visible |  |  |  |
| GHENKHN2 | AdLib driver |  |  |  |
| GK1 | Sierra SCI | SB AdLib MT-32 GM PAS Speaker CMS |  | yes |
| GK2 | own: SB + AdLib | SB AdLib MT-32 GM PAS CMS |  |  |
| GOB1 | own: AdLib | AdLib |  |  |
| GOB2 | own: AdLib |  |  |  |
| GOB3 | own: SB + AdLib | SB |  |  |
| GODTHUND | own: SB + AdLib | SB CMS |  |  |
| GUILD | Allegro |  |  | no card traffic |
| HAMMGOD | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| HANNIBAL | own: SB |  |  |  |
| HEIMDAL2 | own: AdLib | AdLib |  |  |
| HEIMDALL | own: SB + AdLib | SB AdLib MT-32 |  |  |
| HEROLANC | own: speaker | Tandy |  |  |
| HEROMM | Miles MSS 3 | SB MT-32 GUS PAS Speaker | GUS |  |
| HEROMM2D | Miles MSS 3 | SB AdLib MT-32 GM GUS PAS Speaker Tandy | Smacker video, GUS | yes |
| HEROQUES | Sierra SCI | AdLib MT-32 Tandy |  |  |
| HGG | own: SB | SB Tandy |  |  |
| HHIJINX | own: SB | SB Tandy |  |  |
| HIREDGUN | Creative drv | SB MT-32 GUS | GUS |  |
| HIST1914 | own: AdLib |  |  |  |
| HOBOKEN | own: SB + AdLib | SB AdLib MT-32 Speaker |  |  |
| HOC | own: SB + AdLib | SB AdLib MT-32 Tandy |  |  |
| HOLILEMM | own: AdLib | AdLib Tandy |  |  |
| HUMANS | own: speaker |  |  |  |
| IGOR | own: SB + AdLib | SB AdLib |  |  |
| IHNMAIMS | Miles MSS 3 | SB AdLib MT-32 GM GUS PAS Speaker Tandy | GUS |  |
| IMPERIG | own: SB + AdLib | SB AdLib GUS | GUS |  |
| INDY4 | Creative drv, iMUSE (on its disc) |  |  |  |
| INDYCRU | own: SB + AdLib | SB AdLib Speaker Tandy CMS |  |  |
| ISHAR1 | own: SB + AdLib | SB AdLib Speaker |  |  |
| ISHAR2 | own: SB + AdLib | SB AdLib Speaker |  |  |
| ISHAR3 | own: runs from its disc |  |  |  |
| JAGGALL | Miles MSS 3 | SB AdLib MT-32 GM GUS PAS Speaker Tandy | GUS | yes |
| JAGGALLD | Miles MSS 3 | SB AdLib MT-32 GM GUS PAS Speaker Tandy | GUS |  |
| JETPACK | own: SB + AdLib | SB AdLib Speaker |  |  |
| JOURQB | own: SB | SB Tandy |  |  |
| JRRTF1 | Miles AIL 2 | SB AdLib MT-32 PAS Speaker Tandy CMS Covox |  |  |
| KEYSMARA | own: speaker |  |  |  |
| KINGBOUN | own: speaker | Tandy |  |  |
| KKND | HMI SOS, Apogee SS | SB AdLib MT-32 GUS PAS Speaker Tandy CMS Covox | GUS | no card traffic |
| KMOON | HMI SOS | SB AdLib MT-32 GM GUS PAS Speaker Tandy Covox | GUS |  |
| KQ1 | Sierra SCI |  |  |  |
| KQ1VGA | Sierra SCI | SB AdLib MT-32 Speaker Tandy CMS |  |  |
| KQ2 | Sierra SCI |  |  |  |
| KQ3 | Sierra SCI |  |  |  |
| KQ4 | Sierra SCI | SB AdLib MT-32 GUS Speaker Tandy CMS | GUS | no card traffic |
| KQ5 | Sierra SCI | SB AdLib MT-32 PAS Speaker Tandy CMS Covox |  | yes |
| KQ6CD | Miles AIL 2, DigPak/MidPak, Sierra SCI | SB AdLib MT-32 GM GUS PAS Speaker Tandy CMS Covox | GUS | yes |
| KQ7 | Sierra SCI | SB AdLib MT-32 GM PAS CMS |  |  |
| KRONDOR | Sierra SCI | SB AdLib MT-32 GM Speaker Tandy CMS |  |  |
| KYRA1 | own: SB + AdLib | SB AdLib MT-32 Tandy | Westwood | yes |
| KYRA2 | own: SB + AdLib | SB AdLib Tandy | Westwood | yes |
| KYRA3 | HMI SOS | SB AdLib GUS PAS Speaker Tandy Covox | Westwood, GUS |  |
| LANDD1 | own: speaker |  |  |  |
| LANDD2 | own: AdLib |  | Origin |  |
| LBOW1 | Sierra SCI | SB AdLib MT-32 Speaker Tandy CMS |  |  |
| LEATHERG | Tandy | SB AdLib MT-32 PAS Speaker Tandy Covox |  |  |
| LEMM2 | Miles AIL 2 | SB AdLib MT-32 Speaker Tandy CMS |  | no card traffic |
| LEMM3 | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| LEMM3D | own: SB | SB MT-32 GM GUS | GUS |  |
| LEMMI3D | own: SB | SB MT-32 GM GUS | GUS |  |
| LEMMINGS | own: SB | Tandy |  |  |
| LEMMOHNO | own: SB |  |  |  |
| LEXPRESS | own: SB | SB |  |  |
| LLTOC | own: SB + AdLib | SB AdLib Tandy | Westwood |  |
| LODERU83 | own: speaker |  |  |  |
| LOGICAL | own: SB + AdLib | AdLib |  |  |
| LONGBOW | Sierra SCI | SB AdLib MT-32 GM PAS Speaker Tandy CMS Covox |  |  |
| LOOM | own: SB + AdLib | SB AdLib Speaker Tandy CMS |  |  |
| LORDOFRM | Miles AIL 2, DigPak/MidPak | SB AdLib MT-32 GM GUS PAS Speaker |  |  |
| LORDORM2 | Miles MSS 3 | SB AdLib MT-32 GM GUS PAS Speaker Tandy | Smacker video, GUS |  |
| LOSTEDEN | HMI SOS, DMX, DSMI (on its disc) |  |  |  |
| LSL1VGA | Sierra SCI | SB AdLib MT-32 GM PAS Speaker Tandy CMS |  |  |
| LSL2 | Sierra SCI | SB AdLib MT-32 Speaker Tandy CMS |  | yes |
| LSL3 | Sierra SCI | SB AdLib MT-32 Speaker Tandy CMS |  |  |
| LSL5 | Sierra SCI | SB AdLib MT-32 GM PAS Speaker Tandy CMS |  |  |
| LSL6CD | Sierra SCI | SB AdLib MT-32 GM GUS PAS Speaker Tandy CMS Covox |  | yes |
| LSL7DOS | Sierra SCI | SB AdLib PAS Speaker CMS |  |  |
| LURKINGH | own: SB | SB Tandy |  |  |
| MADTV | own: runs from its disc |  |  |  |
| MAGCAND1 | Sierra SCI |  | Origin |  |
| MAGCAND2 | Creative drv | SB AdLib MT-32 Speaker Tandy |  |  |
| MAGCAND3 | Creative drv | SB AdLib MT-32 Speaker Tandy |  |  |
| MANSIOND | own: speaker | Tandy |  |  |
| MARBMAST | Miles MSS 3 | SB AdLib MT-32 GUS PAS Speaker Tandy | GUS |  |
| MARTIANM | own: SB + AdLib | SB AdLib MT-32 |  |  |
| MASTMAGI | Miles | SB MT-32 |  |  |
| MASTORI | Miles | SB AdLib MT-32 GM PAS |  |  |
| MASTORI2 | Miles MSS 3 | SB AdLib MT-32 GM GUS PAS Speaker Tandy | Smacker video, GUS |  |
| MAX | HMI SOS | SB AdLib MT-32 GM GUS PAS Speaker Tandy Covox | GUS |  |
| MCRITIC | Miles MSS 3 | SB AdLib MT-32 GM GUS PAS Speaker | GUS |  |
| MEGALOMA | own: SB + AdLib | SB AdLib MT-32 |  |  |
| MI1 | Creative drv | SB AdLib MT-32 Speaker Tandy CMS |  | yes |
| MI2 | own: SB + AdLib | SB AdLib MT-32 Speaker |  |  |
| MIDWINTE | own: AdLib | AdLib MT-32 Tandy |  |  |
| MINDVOY | own: SB | SB Tandy |  |  |
| MM1 | own: SB | SB Tandy |  |  |
| MM2 | own: SB | SB Tandy |  |  |
| MM3 | own: speaker |  |  |  |
| MM4 | own: nothing visible |  |  |  |
| MM5 | own: SB |  |  |  |
| MM6 | own: SB |  |  |  |
| MOONAHDK | Creative drv | SB AdLib MT-32 Tandy |  |  |
| MOTORCIT | own: AdLib |  |  |  |
| MSTREETS | own: speaker | Tandy |  |  |
| NETHACK | own: AdLib | AdLib |  |  |
| NEURO | own: speaker | Tandy |  |  |
| NORMAL | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy CMS Covox | GUS |  |
| NORSEBYN | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| ODDWORLD | Miles MSS 3 | SB AdLib MT-32 GM GUS PAS Speaker Tandy | GUS |  |
| OVERLORD | own: SB + AdLib | AdLib MT-32 Speaker Tandy CMS |  |  |
| PANDORA | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| PERFECTG | Miles AIL 2, DigPak/MidPak | SB AdLib MT-32 GM GUS PAS |  |  |
| PERFGEN | Sierra SCI | SB AdLib Speaker Covox | Origin |  |
| PHEARTS | own: SB | SB Tandy |  |  |
| PHOBOS1 | own: nothing visible | Tandy |  |  |
| PIPEDREA | own: speaker |  |  |  |
| PIRATES | MicroProse | MT-32 |  | yes |
| PIZZATYC | DigPak/MidPak, Creative drv | SB AdLib PAS |  | yes |
| PLANEDGE | own: SB + AdLib | SB AdLib MT-32 Tandy |  |  |
| PLANETF | own: SB | SB Tandy |  |  |
| PNITE | own: speaker | Tandy |  |  |
| POOLDARK | DigPak/MidPak | SB AdLib Speaker Tandy CMS Covox |  |  |
| POOLRAD | own: SB |  |  |  |
| POPULOUS | own: nothing visible |  |  |  |
| POPULS2 | own: SB + AdLib | AdLib |  |  |
| POWERMON | Miles | AdLib MT-32 Tandy |  |  |
| PQ1 | Sierra SCI |  |  |  |
| PQ1_VGA | Sierra SCI | SB AdLib MT-32 GM PAS Speaker CMS Covox |  |  |
| PQ2 | Sierra SCI | SB AdLib MT-32 Speaker Tandy CMS |  |  |
| PQ3 | Sierra SCI | SB AdLib MT-32 PAS Speaker Tandy CMS |  | yes |
| PQ4 | Sierra SCI | SB AdLib MT-32 GM PAS Speaker CMS | Smacker video |  |
| PUSHOVER | own: nothing visible |  |  |  |
| PUYO2 | own: SB | SB |  |  |
| QG1NEW | Sierra SCI | SB AdLib MT-32 GM PAS Speaker Tandy CMS Covox |  |  |
| QG1OLD | Sierra SCI | SB AdLib MT-32 Speaker Tandy CMS |  |  |
| QG2 | Sierra SCI | SB AdLib MT-32 Speaker Tandy CMS |  |  |
| QG3E | Sierra SCI | SB AdLib MT-32 GM PAS Speaker Tandy CMS Covox |  |  |
| QG4CD | Sierra SCI | SB AdLib MT-32 GM PAS Speaker CMS |  |  |
| RAMPART | own: AdLib | AdLib |  |  |
| RARKANI1 | Miles AIL 2 | SB AdLib MT-32 PAS Speaker Tandy |  |  |
| RARKANI3 | HMI SOS | SB AdLib GUS PAS Speaker Tandy Covox | GUS |  |
| RAVAGER | Miles AIL 2 | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| RAVENLO2 | Miles | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| RAVENLOF | Miles | SB AdLib MT-32 GM GUS PAS Speaker Tandy Covox | GUS |  |
| RDRAGON | own: SB + AdLib | SB AdLib MT-32 Speaker Tandy |  |  |
| REDGUARD | Miles MSS 3 | SB AdLib MT-32 GM GUS PAS Speaker Tandy | Smacker video, GUS |  |
| REUNION | own: runs from its disc |  |  |  |
| RIDDLE | HMI SOS | SB AdLib MT-32 GM GUS PAS Speaker Tandy Covox | GUS |  |
| ROBINSON | own: runs from its disc |  |  |  |
| ROCKRANG | own: speaker |  |  |  |
| ROM3K3 | AdLib driver |  |  |  |
| RULEENG1 | Creative drv | SB MT-32 Tandy |  |  |
| SAMNMAX | HMI SOS (on its disc) |  |  |  |
| SCOMET | own: nothing visible |  |  |  |
| SCORCHED | AdLib driver | AdLib |  | no card traffic |
| SECSILBL | own: AdLib | AdLib Speaker Tandy |  |  |
| SENTW1FM | own: SB | SB |  |  |
| SERFCITY | Miles AIL 2 | SB AdLib MT-32 GM GUS PAS Speaker Tandy | GUS | yes |
| SETTLR2G | Miles MSS 3 | SB AdLib MT-32 GM GUS PAS Speaker Tandy | GUS |  |
| SHADLAND | own: SB + AdLib | SB AdLib MT-32 |  |  |
| SHADWORL | Creative drv (on its disc) |  |  |  |
| SHCRT | Miles MSS 3, DiamondWare | SB AdLib MT-32 GM GUS PAS | GUS | no card traffic |
| SHCSS | own: SB + AdLib | SB AdLib MT-32 Tandy Covox |  |  |
| SHRCJ | own: SB | SB Tandy |  |  |
| SIDALS | Sierra SCI | SB AdLib MT-32 GM PAS Speaker Tandy CMS |  |  |
| SIDMP! | own: nothing visible |  |  |  |
| SIEGE92 | Creative drv | SB AdLib MT-32 Speaker |  |  |
| SIMANT | own: SB + AdLib | Tandy Covox |  |  |
| SIMCITY | own: speaker | Speaker Tandy Covox |  |  |
| SIMCITY2 | Miles | SB AdLib MT-32 PAS Speaker | Smacker video |  |
| SIMCITYE | Miles AIL 2 | SB AdLib PAS |  | yes |
| SIMFARM | Miles AIL 2 | SB AdLib MT-32 PAS Speaker Tandy |  | yes |
| SIMISLE | Miles MSS 3 | SB MT-32 GUS PAS | GUS |  |
| SIMLIFE | own: SB + AdLib | SB AdLib MT-32 Tandy Covox |  |  |
| SIMON1 | Miles, DigPak/MidPak | SB AdLib MT-32 GUS PAS Tandy Covox |  | yes |
| SIMON2 | Miles AIL 2, DigPak/MidPak | SB AdLib MT-32 GM GUS PAS Tandy Covox |  | no card traffic |
| SMCIVILI | own: SB + AdLib | SB AdLib MT-32 GM PAS Tandy |  |  |
| SMCOLONI | own: SB |  |  |  |
| SMRAILT | MicroProse | AdLib MT-32 Tandy |  |  |
| SMRAILTD | own: SB + AdLib | SB AdLib MT-32 PAS Covox |  |  |
| SOFTPORN | own: nothing visible |  |  |  |
| SOKOBAN | own: speaker | Tandy |  |  |
| SORC | own: SB | SB Tandy |  |  |
| SORCERIA | Sierra SCI | SB AdLib MT-32 Speaker CMS |  |  |
| SPACEMAX | own: AdLib | AdLib |  |  |
| SPECIALF | own: SB + AdLib | SB AdLib MT-32 |  |  |
| SPELBREK | own: SB | SB Tandy |  |  |
| SPIREXC | own: SB |  |  |  |
| SPYCRAFT | Miles, HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| SQ1 | Sierra SCI |  |  |  |
| SQ1VGA | Sierra SCI | SB AdLib MT-32 GM PAS Speaker Tandy CMS |  |  |
| SQ2 | Sierra SCI |  |  |  |
| SQ3 | Sierra SCI | SB AdLib MT-32 Speaker Tandy CMS |  |  |
| SQ4 | Sierra SCI | SB AdLib MT-32 GM PAS Speaker Tandy CMS Covox |  |  |
| SQ5 | Sierra SCI | SB AdLib MT-32 GM PAS Speaker Tandy CMS Covox |  |  |
| SQ6 | Sierra SCI | SB AdLib MT-32 GM PAS Speaker CMS |  |  |
| ST25 | own: SB + AdLib | SB AdLib MT-32 PAS Speaker Tandy |  |  |
| STAR | Miles AIL 2 | SB AdLib MT-32 GM GUS PAS Speaker Tandy | GUS | no card traffic |
| STARCOMM | Miles MSS 3 | SB MT-32 GUS PAS Speaker Tandy | GUS |  |
| STARCON | own: SB + AdLib | AdLib MT-32 Tandy CMS |  |  |
| STARCON2 | own: SB + AdLib | SB AdLib GUS Covox | GUS |  |
| STARCON3 | Miles MSS 3 | SB AdLib MT-32 GM GUS PAS Speaker | GUS |  |
| STARFLY | own: speaker |  |  |  |
| STARFLY2 | own: SB | SB Tandy |  |  |
| STARGENE | Miles MSS 3 | SB AdLib MT-32 GUS PAS Speaker Tandy | GUS |  |
| STATFALL | own: SB | SB Tandy |  |  |
| STJUDGE | own: SB + AdLib | SB AdLib MT-32 GM PAS Speaker Tandy |  |  |
| STONKEEP | HMI SOS | SB AdLib MT-32 GM GUS PAS |  |  |
| STORMMAS | own: nothing visible |  |  |  |
| STREETRO | own: AdLib | AdLib Tandy |  |  |
| STRIFE | DMX | SB AdLib MT-32 GM GUS PAS Speaker | GUS | yes |
| STRONGHO | Miles, DigPak/MidPak | SB AdLib MT-32 PAS Speaker |  |  |
| STRTRODS | own: speaker | Tandy |  |  |
| STUNITY | HMI SOS | SB AdLib GUS PAS Speaker Tandy Covox | GUS |  |
| SUBTRADE | own: SB + AdLib | SB AdLib |  |  |
| SUPAPLEX | own: SB + AdLib | SB AdLib MT-32 |  |  |
| SUSPECT | own: SB | SB Tandy |  |  |
| SWORDOFA | own: SB | MT-32 |  |  |
| SWORDOFT | MicroProse | AdLib MT-32 Tandy |  |  |
| SYNDICAT | own: nothing visible |  |  |  |
| SYNDWARS | Miles MSS 3 | SB AdLib MT-32 GM GUS PAS Speaker Tandy | GUS |  |
| TERRANOV | Miles MSS 3 | SB AdLib MT-32 GM GUS PAS Speaker Tandy | GUS |  |
| TETRIS87 | own: speaker | Tandy |  |  |
| THECLUE | Creative drv | SB |  |  |
| THEEVENM | Sierra SCI | SB AdLib MT-32 GM PAS Speaker Tandy CMS Covox |  |  |
| THEHORDE | own: SB | GUS | GUS |  |
| THELOSTV | own: SB + AdLib | SB AdLib MT-32 GM PAS Speaker |  |  |
| THEMHOSP | Miles MSS 3, DigPak/MidPak | SB AdLib MT-32 GM GUS PAS Speaker Tandy | Smacker video, GUS | yes |
| THEMPARK | Miles, HMI SOS (on its disc) |  |  |  |
| THEPATRI | Creative drv | SB AdLib |  |  |
| TIMECOMM | Miles MSS 3 | SB AdLib MT-32 GM GUS PAS Speaker Tandy | GUS | yes |
| TIMELORE | own: AdLib | AdLib Tandy | Origin |  |
| TINCM1 | own: SB + AdLib | SB AdLib MT-32 GM PAS Speaker Tandy CMS |  |  |
| TINCM2 | Sierra SCI | SB AdLib MT-32 GM PAS Speaker Tandy CMS |  |  |
| TOONSTRK | HMI SOS | SB AdLib GUS PAS Speaker Tandy Covox | Smacker video, GUS |  |
| TQUEST | own: SB + AdLib | SB AdLib MT-32 |  |  |
| TRANSPOR | DigPak/MidPak | SB AdLib |  | no card traffic |
| TRANTDLX | DigPak/MidPak | SB AdLib MT-32 |  |  |
| TREASSAV | DigPak/MidPak | SB AdLib Speaker Tandy |  |  |
| TRINITY | own: SB | SB Tandy |  |  |
| TUNNTROL | own: speaker |  |  |  |
| ULTIDOMA | own: SB + AdLib | SB |  |  |
| ULTIMA0 | own: SB + AdLib | SB AdLib GUS |  |  |
| ULTIMA1 | own: SB | SB Tandy | Origin |  |
| ULTIMA2 | DigPak/MidPak, Sierra SCI | AdLib |  |  |
| ULTIMA3 | Miles AIL 2, DigPak/MidPak | SB AdLib MT-32 GM GUS PAS Speaker Tandy |  |  |
| ULTIMA4 | Miles AIL 2, DigPak/MidPak | SB AdLib MT-32 GM GUS PAS Speaker Tandy | Origin |  |
| ULTIMA5 | Miles AIL 2, DigPak/MidPak | SB AdLib MT-32 GM GUS PAS Speaker Tandy | Origin |  |
| ULTIMA6 | CMS | AdLib MT-32 Speaker Tandy CMS Covox |  | no card traffic |
| ULTIMA71 | Miles AIL 2 | SB AdLib MT-32 | Origin | no card traffic |
| ULTIMA72 | Miles AIL 2, HMI SOS | SB AdLib MT-32 | Origin |  |
| ULTIMA8 | Miles | SB AdLib MT-32 GM | Origin | no card traffic |
| ULTIMAU1 | own: SB + AdLib | SB AdLib MT-32 PAS Speaker Tandy |  |  |
| ULTIMAU2 | Miles AIL 2 | SB AdLib MT-32 PAS Speaker |  |  |
| UTOPTCON | Sierra SCI | AdLib MT-32 |  |  |
| VEILDARK | own: SB + AdLib | SB AdLib MT-32 Speaker Tandy CMS |  |  |
| WARCRAFD | Miles MSS 3 | SB AdLib MT-32 GM GUS PAS Speaker | GUS |  |
| WARCRAFT | Miles MSS 3 | SB AdLib MT-32 GM GUS PAS | GUS | yes |
| WASTLAND | own: speaker | Tandy |  |  |
| WELLTRIS | own: speaker | Tandy |  |  |
| WHALVOY1 | Creative drv | SB |  |  |
| WHALVOY2 | Creative drv | SB GUS |  |  |
| WISHBRIN | own: SB | SB Tandy |  |  |
| WIZAR1 | own: speaker |  |  |  |
| WIZAR3 | own: speaker |  |  |  |
| WIZAR5 | own: speaker |  |  |  |
| WIZAR6 | own: SB + AdLib | SB AdLib Speaker Tandy Covox |  |  |
| WIZAR7 | own: SB + AdLib | SB AdLib MT-32 Speaker Tandy Covox |  |  |
| WLAND | Allegro | AdLib MT-32 Tandy |  | no card traffic |
| WLSONEMP | Sound Images | AdLib MT-32 |  |  |
| WORMSRE | own: SB | SB GUS | GUS |  |
| WULTIMA | own: SB + AdLib | SB AdLib MT-32 Speaker Tandy | Origin |  |
| WULTIMA2 | own: SB + AdLib | SB AdLib MT-32 Speaker Tandy | Origin |  |
| XANTH | own: SB + AdLib | SB AdLib MT-32 Speaker Covox |  |  |
| XCOMAP | HMI SOS | SB AdLib MT-32 GUS PAS Speaker Tandy Covox | GUS |  |
| XCOMTE | DigPak/MidPak | SB AdLib MT-32 GM GUS PAS CMS |  | yes |
| XCOMUF | DigPak/MidPak | SB AdLib MT-32 GM GUS PAS CMS |  | yes |
| YVANOME | own: speaker |  |  |  |
| ZAK | own: speaker | Tandy |  |  |
| ZELIARD | Sierra SCI | SB AdLib MT-32 Speaker Tandy |  |  |
| ZNEMESIS | Miles MSS 3 | SB AdLib MT-32 GM GUS PAS Speaker Tandy | GUS |  |
| ZORK1 | own: SB | SB Tandy |  |  |

