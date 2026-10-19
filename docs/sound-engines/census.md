# Driver census

Every sound driver file in DOS_ACT and DOS_THNK, grouped by its exact content (an MD5
hash, first 8 digits). Two games with the same file run the same driver code, so a
trace of one stands for all of them; a version with no traced game is a gap. Engines
built into the game (DMX, the Apogee Sound System, MIDAS, DSMI, own code) have no
separate file and are not here. [file]

"Traced" names games carrying that version that have a port trace (86Box through uCDD,
or DOSBox-X; see [README](README.md#how-these-notes-were-made)). The trace ran the driver
the game's configuration chose: for an SB16-configured game that is its SB16 file, so
its SBPRO.DIG or SBLASTER.DIG version was carried, not run. "Covered" counts the games
whose version of the file has a traced carrier, in that sense.

## Miles MSS 3, digital

### SB16.DIG: 70 games, 8 versions, 69 games covered by a traced version

| Version | Games | Traced | Games carrying it |
|---|---|---|---|
| b24e361b | 23 | TIMECOMM | ALIENODY ALIENTRI BSWORD1 BUBBBRI DARKLIGH DW2 FANTGEN FIROKLAW HEROMM IHNMAIMS JAGGALLD MASSDEST MCRITIC MEGARAC2 PRIV2SE SETTLR2G and 7 more |
| d8214374 | 17 | JAGGALL | ABZERO ALIENLEG ASCENDY BIGREDRA CAESAR2 DEATH DEDERBY DW1 JAGGALL MASTORI2 MECHW2 MECHW2M MEGAMANX MK PRIMALRA SIMISLE and 1 more |
| 63bfd531 | 10 | GTA, HEROMM2D | BATSPIRE DEDERBY2 EXTREMEA GTA HEROMM2D LORDORM2 MARBMAST SHCRT STARCOMM STARCON3 |
| 29dcf6c8 | 9 | DUNGKEEP, HEROMM2D, MKTRIL | BUSTMOV2 DUNGKEEP HEROMM2D MKTRIL MOTORMA ODDWORLD REDGUARD TSTDRIVO TWINSEN |
| 14ff00f5 | 6 | THEMHOSP | ANIMAL ARCHIMED BLASTER! STARGENE THEMHOSP XMENCHI |
| 24e07b30 | 2 | ALBION | ALBION MAGCARP2 |
| 324d6bdd | 2 | SYSTEMSH, WARCRAFT | SYSTEMSH WARCRAFT |
| 0c12adc1 | 1 | **none** | FADETOBL |

### SBPRO.DIG: 69 games, 5 versions, 69 games covered by a traced version

| Version | Games | Traced | Games carrying it |
|---|---|---|---|
| b0fe50da | 43 | ALBION, JAGGALL, TIMECOMM | ABZERO ALBION ALIENLEG ALIENODY ALIENTRI ASCENDY BIGREDRA BSWORD1 BUBBBRI CAESAR2 DARKLIGH DEATH DEDERBY DW1 DW2 FADETOBL and 27 more |
| 1acc7ff5 | 10 | GTA, HEROMM2D | BATSPIRE DEDERBY2 EXTREMEA GTA HEROMM2D LORDORM2 MARBMAST SHCRT STARCOMM STARCON3 |
| 6d1b1119 | 8 | DUNGKEEP, HEROMM2D, MKTRIL | BUSTMOV2 DUNGKEEP HEROMM2D MKTRIL MOTORMA ODDWORLD REDGUARD TWINSEN |
| f5307d21 | 6 | THEMHOSP | ANIMAL ARCHIMED BLASTER! STARGENE THEMHOSP XMENCHI |
| 73b104c1 | 2 | SYSTEMSH, WARCRAFT | SYSTEMSH WARCRAFT |

### SBLASTER.DIG: 70 games, 7 versions, 61 games covered by a traced version

| Version | Games | Traced | Games carrying it |
|---|---|---|---|
| fafa23a9 | 18 | JAGGALL | ABZERO ALIENLEG ASCENDY BIGREDRA CAESAR2 DEATH DEDERBY DW1 FADETOBL JAGGALL MASTORI2 MECHW2 MECHW2M MEGAMANX MK PRIMALRA and 2 more |
| b456d638 | 16 | ALBION, TIMECOMM | ALBION ALIENTRI BSWORD1 DARKLIGH DW2 FANTGEN FIROKLAW JAGGALLD MASSDEST SETTLR2G STDS9HAR SWIV3D TERRANOV TIMECOMM WARCRAFD ZNEMESIS |
| 6117ea24 | 10 | GTA, HEROMM2D | BATSPIRE DEDERBY2 EXTREMEA GTA HEROMM2D LORDORM2 MARBMAST SHCRT STARCOMM STARCON3 |
| 05c4b525 | 9 | **none** | ALIENODY BUBBBRI HEROMM IHNMAIMS MAGCARP2 MCRITIC MEGARAC2 PRIV2SE SYNDWARS |
| 31ae9295 | 9 | DUNGKEEP, HEROMM2D, MKTRIL | BUSTMOV2 DUNGKEEP HEROMM2D MKTRIL MOTORMA ODDWORLD REDGUARD TSTDRIVO TWINSEN |
| f6f10593 | 6 | THEMHOSP | ANIMAL ARCHIMED BLASTER! STARGENE THEMHOSP XMENCHI |
| e631c3e0 | 2 | SYSTEMSH, WARCRAFT | SYSTEMSH WARCRAFT |

## Miles MSS 3, music

### OPL3.MDI: 36 games, 5 versions, 36 games covered by a traced version

| Version | Games | Traced | Games carrying it |
|---|---|---|---|
| 84ce740a | 25 | ALBION, JAGGALL, TIMECOMM | ABZERO ALBION ALIENLEG ALIENODY BUBBBRI CAESAR2 DEATH DW1 FADETOBL FIROKLAW IHNMAIMS JAGGALL JAGGALLD MAGCARP2 MASTORI2 MCRITIC and 9 more |
| 9e47860c | 5 | HEROMM2D | EXTREMEA HEROMM2D LORDORM2 SHCRT STARCON3 |
| 5d97fa7d | 4 | HEROMM2D, MKTRIL | HEROMM2D MKTRIL ODDWORLD REDGUARD |
| d9ae1ec6 | 1 | SYSTEMSH | SYSTEMSH |
| 9ff93102 | 1 | THEMHOSP | THEMHOSP |

### SBPRO2.MDI: 37 games, 5 versions, 37 games covered by a traced version

| Version | Games | Traced | Games carrying it |
|---|---|---|---|
| 8879265b | 25 | ALBION, JAGGALL, TIMECOMM | ALBION ALIENLEG ALIENODY BUBBBRI CAESAR2 DEATH DW1 FADETOBL FIROKLAW IHNMAIMS JAGGALL JAGGALLD MAGCARP2 MASTORI2 MCRITIC MECHW2 and 9 more |
| 9e63f09c | 5 | HEROMM2D | EXTREMEA HEROMM2D LORDORM2 SHCRT STARCON3 |
| d99c03c1 | 4 | HEROMM2D, MKTRIL | HEROMM2D MKTRIL ODDWORLD REDGUARD |
| 46a1c543 | 2 | SYSTEMSH, WARCRAFT | SYSTEMSH WARCRAFT |
| e65fff3a | 1 | THEMHOSP | THEMHOSP |

### SBPRO1.MDI: 37 games, 5 versions, 37 games covered by a traced version

| Version | Games | Traced | Games carrying it |
|---|---|---|---|
| 998eced7 | 25 | ALBION, JAGGALL, TIMECOMM | ALBION ALIENLEG ALIENODY BUBBBRI CAESAR2 DEATH DW1 FADETOBL FIROKLAW IHNMAIMS JAGGALL JAGGALLD MAGCARP2 MASTORI2 MCRITIC MECHW2 and 9 more |
| d39130ab | 5 | HEROMM2D | EXTREMEA HEROMM2D LORDORM2 SHCRT STARCON3 |
| ae82c156 | 4 | HEROMM2D, MKTRIL | HEROMM2D MKTRIL ODDWORLD REDGUARD |
| 2d0c8b34 | 2 | SYSTEMSH, WARCRAFT | SYSTEMSH WARCRAFT |
| c49a03da | 1 | THEMHOSP | THEMHOSP |

### SBLASTER.MDI: 37 games, 5 versions, 37 games covered by a traced version

| Version | Games | Traced | Games carrying it |
|---|---|---|---|
| 20fc92cf | 25 | ALBION, JAGGALL | ABZERO ALBION ALIENLEG ALIENODY BUBBBRI CAESAR2 DEATH DW1 FADETOBL FIROKLAW IHNMAIMS JAGGALL JAGGALLD MAGCARP2 MASTORI2 MCRITIC and 9 more |
| 5e06233f | 5 | HEROMM2D | EXTREMEA HEROMM2D LORDORM2 SHCRT STARCON3 |
| 2d47b47a | 4 | HEROMM2D, MKTRIL | HEROMM2D MKTRIL ODDWORLD REDGUARD |
| e31772d5 | 2 | SYSTEMSH, WARCRAFT | SYSTEMSH WARCRAFT |
| 1808ca99 | 1 | THEMHOSP | THEMHOSP |

### MPU401.MDI: 38 games, 8 versions, 27 games covered by a traced version

| Version | Games | Traced | Games carrying it |
|---|---|---|---|
| 965a57d1 | 10 | **none** | ALIENODY BUBBBRI FADETOBL IHNMAIMS MAGCARP2 MCRITIC MECHW2 SYNDWARS TERRANOV WARCRAFD |
| d7397b29 | 9 | JAGGALL | ABZERO ALIENLEG CAESAR2 DEATH DW1 JAGGALL MASTORI2 MEGAMANX PRIMALRA |
| 0e641bcd | 6 | ALBION, TIMECOMM | ALBION FIROKLAW JAGGALLD SETTLR2G TIMECOMM ZNEMESIS |
| aed780f6 | 5 | HEROMM2D | EXTREMEA HEROMM2D LORDORM2 SHCRT STARCON3 |
| 3628cbb8 | 4 | HEROMM2D, MKTRIL | HEROMM2D MKTRIL ODDWORLD REDGUARD |
| b4ea3c26 | 2 | SYSTEMSH, WARCRAFT | SYSTEMSH WARCRAFT |
| cec4fc1e | 1 | **none** | PRIV2SE |
| c69e47cf | 1 | THEMHOSP | THEMHOSP |

### MT32MPU.MDI: 33 games, 6 versions, 31 games covered by a traced version

| Version | Games | Traced | Games carrying it |
|---|---|---|---|
| 609666cb | 20 | ALBION, JAGGALL | ABZERO ALBION ALIENODY BUBBBRI CAESAR2 DEATH DW1 FADETOBL FIROKLAW IHNMAIMS JAGGALL JAGGALLD MASTORI2 MCRITIC MECHW2 MEGAMANX and 4 more |
| cc7dab16 | 6 | HEROMM2D, THEMHOSP | EXTREMEA HEROMM2D LORDORM2 SHCRT STARCON3 THEMHOSP |
| 7f854aa8 | 4 | HEROMM2D, MKTRIL | HEROMM2D MKTRIL ODDWORLD REDGUARD |
| 965a57d1 | 1 | **none** | MAGCARP2 |
| a8e4c559 | 1 | SYSTEMSH | SYSTEMSH |
| bc533418 | 1 | **none** | SYNDWARS |

### SBAWE32.MDI: 39 games, 5 versions, 38 games covered by a traced version

| Version | Games | Traced | Games carrying it |
|---|---|---|---|
| a66e04b5 | 25 | ALBION, JAGGALL, SYSTEMSH | ABZERO ALBION ALIENLEG ALIENODY BUBBBRI CAESAR2 DEATH DW1 FADETOBL FIROKLAW IHNMAIMS JAGGALL JAGGALLD MASTORI2 MCRITIC MECHW2 and 9 more |
| 3e44584c | 5 | HEROMM2D | EXTREMEA HEROMM2D LORDORM2 SHCRT STARCON3 |
| 7c157048 | 5 | HEROMM2D, MKTRIL, THEMHOSP | HEROMM2D MKTRIL ODDWORLD REDGUARD THEMHOSP |
| aaf6d9cb | 3 | DUNGKEEP | DUNGKEEP MAGCARP2 SYNDWARS |
| b0d9c141 | 1 | **none** | TERRANOV |

## Miles AIL 2

### SBDIG.ADV: 21 games, 8 versions, 15 games covered by a traced version

| Version | Games | Traced | Games carrying it |
|---|---|---|---|
| 8d614686 | 11 | CAESAR, CASTLES2, DETROIT | CAESAR CASTLES2 DETROIT ESARENA FANTEMPI JRRTF1 LORDOFRM RARKANI1 RAVAGER SIMCITYE SIMFARM |
| de617841 | 2 | **none** | SEALTEAM WCACAD |
| 6d06916c | 2 | **none** | BISLE2 STAR |
| 1f468bb1 | 2 | **none** | ULTIMA71 ULTIMA72 |
| 9fb1d790 | 1 | 7THGUEST | 7THGUEST |
| 200c07bf | 1 | DRKQUEEN | DRKQUEEN |
| 9611d829 | 1 | EOB3 | EOB3 |
| a1de8a13 | 1 | ULTIMAU1 | ULTIMAU1 |

### SBPDIG.ADV: 16 games, 6 versions, 12 games covered by a traced version

| Version | Games | Traced | Games carrying it |
|---|---|---|---|
| 295b502e | 10 | CASTLES2, DETROIT, FANTEMPI | CASTLES2 DETROIT ESARENA FANTEMPI JRRTF1 LORDOFRM RARKANI1 RAVAGER SIMCITYE SIMFARM |
| f3b4cbcd | 2 | **none** | BISLE2 STAR |
| 2f316239 | 1 | **none** | SEALTEAM |
| 8117fe7e | 1 | 7THGUEST | 7THGUEST |
| 29924918 | 1 | **none** | ULTIMA72 |
| 25353fb2 | 1 | ULTIMAU1 | ULTIMAU1 |

### SBFM.ADV: 22 games, 5 versions, 22 games covered by a traced version

| Version | Games | Traced | Games carrying it |
|---|---|---|---|
| 0ad686a9 | 11 | 7THGUEST, CAESAR, DETROIT | 7THGUEST BISLE2 CAESAR DETROIT ESARENA FANTEMPI LORDOFRM RARKANI1 RAVAGER SIMFARM STAR |
| b84c3f6e | 8 | CAPTLSM | CAPTLSM CAPTLSMP PERFECTG SEALTEAM SIMON2 ULTIMA3 ULTIMA4 ULTIMA5 |
| 526dbc09 | 1 | BRMATRIX | BRMATRIX |
| d9143b9e | 1 | CASTLES2 | CASTLES2 |
| 04f42907 | 1 | ULTIMAU1 | ULTIMAU1 |

### ADLIB.ADV: 28 games, 8 versions, 25 games covered by a traced version

| Version | Games | Traced | Games carrying it |
|---|---|---|---|
| ee12a7f9 | 11 | 7THGUEST, CAESAR, DETROIT | 7THGUEST BISLE2 CAESAR DETROIT EOB3 FANTEMPI LORDOFRM RARKANI1 RAVAGER SIMFARM STAR |
| d649a80d | 10 | CAPTLSM | CAPTLSM CAPTLSMP LEMM2 PERFECTG SAVAGEWA SEALTEAM SIMON2 ULTIMA3 ULTIMA4 ULTIMA5 |
| e606c74b | 2 | **none** | ULTIMA71 ULTIMA72 |
| b43a0870 | 1 | **none** | WCACAD |
| c5651b80 | 1 | BRMATRIX | BRMATRIX |
| 1ca1373b | 1 | CASTLES2 | CASTLES2 |
| 6a16c177 | 1 | DRKQUEEN | DRKQUEEN |
| da40181f | 1 | ULTIMAU1 | ULTIMAU1 |

### MT32MPU.ADV: 27 games, 9 versions, 22 games covered by a traced version

| Version | Games | Traced | Games carrying it |
|---|---|---|---|
| 0efb9fdf | 11 | 7THGUEST, DETROIT, EOB3 | 7THGUEST BISLE2 DETROIT EOB3 ESARENA FANTEMPI LORDOFRM RARKANI1 RAVAGER SIMFARM STAR |
| 831cbca7 | 7 | CAPTLSM | CAPTLSM CAPTLSMP SEALTEAM SIMON2 ULTIMA3 ULTIMA4 ULTIMA5 |
| 8d434bc8 | 2 | **none** | LEMM2 SAVAGEWA |
| 326a39d9 | 2 | **none** | ULTIMA71 ULTIMA72 |
| bbf9b609 | 1 | **none** | WCACAD |
| c2993dcd | 1 | BRMATRIX | BRMATRIX |
| 2667f087 | 1 | CASTLES2 | CASTLES2 |
| 2672b260 | 1 | DRKQUEEN | DRKQUEEN |
| e21feeb2 | 1 | ULTIMAU1 | ULTIMAU1 |

## HMI SOS

### HMIDRV.386: 67 games, 17 versions, 44 games covered by a traced version

| Version | Games | Traced | Games carrying it |
|---|---|---|---|
| 2de5f490 | 25 | ABUSE, AMULARM, ANVLDAWN | ABUSE AMULARM ANVLDAWN BATTLEAR CONSTRUC CYBERMAG DUMAST2 ESDAGGER KKND MAX NORMAL NORSEBYN PANDORA REDRAMRA SCREAMER SCREAMR2 and 9 more |
| bd16499c | 12 | COMCON, RAYMAN | COMCON COMCONRA CONQESTN FALLOUT1 FRONTIER RAYMAN RAYMANF SLIPSTRE SSF2T WITCHAV2 WITCHAVE XCOMAP |
| 23eb6a30 | 6 | MDK, XCAREXPE | CARMAGED MDK SCREAMR2 SCRMRAL TOONSTRK XCAREXPE |
| 992ba590 | 5 | **none** | ADVTIN LUCKYLUK RIDDLE THESMURF TINTININ |
| 8f3ce462 | 4 | **none** | CYCLONES JUNGLEST METLTECB METLTECE |
| 02643fe4 | 3 | **none** | BCRACERS TRACKATT XCOMAP |
| ea68c622 | 2 | **none** | HAMMGOD KMOON |
| 8fcaea19 | 1 | DESCENT | DESCENT |
| e337a2dd | 1 | **none** | DESCNT2V |
| 430290ad | 1 | **none** | MAGCARP |
| 33e44a78 | 1 | **none** | QUARANT |
| d730de4f | 1 | **none** | ROTH |
| eab18a9f | 1 | **none** | SHATTERE |
| c9f65906 | 1 | **none** | WC4POF |
| 0b2a574d | 1 | **none** | RARKANI3 |
| c00a72ad | 1 | **none** | SPYCRAFT |
| ed4d3d5c | 1 | **none** | STUNITY |

### HMIMDRV.386: 48 games, 13 versions, 28 games covered by a traced version

| Version | Games | Traced | Games carrying it |
|---|---|---|---|
| 642245e7 | 21 | ABUSE, AMULARM, ANVLDAWN | ABUSE AMULARM ANVLDAWN CONSTRUC CYBERMAG ESDAGGER MAX NORMAL REDRAMRA SCREAMER SCREAMR2 SCRMRAL SHATTERE SHELLSHO SKYNET SPYCRAFT and 5 more |
| 6149f9eb | 7 | **none** | ADVTIN CYCLONES LUCKYLUK METLTECE RIDDLE THESMURF TINTININ |
| 12baf215 | 4 | XCAREXPE | CARMAGED SCREAMR2 SCRMRAL XCAREXPE |
| 9cb79e2d | 4 | **none** | FRONTIER WITCHAV2 WITCHAVE XCOMAP |
| 593ddf8c | 2 | DESCENT | DESCENT DESCNT2V |
| ddfac2fe | 2 | **none** | ROTH SSF2T |
| c8702beb | 2 | **none** | DUMAST2 SLIPSTRE |
| 252028f4 | 1 | BATTLEAR | BATTLEAR |
| b29ba128 | 1 | **none** | MAGCARP |
| 5f05ca8f | 1 | **none** | METLTECB |
| 668ba5c1 | 1 | **none** | HAMMGOD |
| 9abf8a92 | 1 | **none** | KMOON |
| f6e37f72 | 1 | **none** | PANDORA |

### HMIDET.386: 60 games, 14 versions, 43 games covered by a traced version

| Version | Games | Traced | Games carrying it |
|---|---|---|---|
| b6656f8a | 23 | ABUSE, AMULARM, ANVLDAWN | ABUSE AMULARM ANVLDAWN BATTLEAR CONSTRUC CYBERMAG DUMAST2 ESDAGGER KKND MAX NORMAL NORSEBYN REDRAMRA SCREAMER SHATTERE SHELLSHO and 7 more |
| 59b3f813 | 8 | RAYMAN | CONQESTN FALLOUT1 FRONTIER RAYMAN RAYMANF ROTH SSF2T XCOMAP |
| 4014e70d | 6 | MDK, XCAREXPE | CARMAGED MDK SCREAMR2 SCRMRAL TOONSTRK XCAREXPE |
| 4262f607 | 5 | **none** | BCRACERS TRACKATT WITCHAV2 WITCHAVE XCOMAP |
| b688842b | 5 | COMCON | COMCON COMCONRA SCREAMR2 SCRMRAL WC4POF |
| 1e4adbaa | 3 | **none** | CYCLONES METLTECB METLTECE |
| d7a6d865 | 2 | **none** | HAMMGOD KMOON |
| 71e77b82 | 2 | **none** | PANDORA RARKANI3 |
| 70ddabb1 | 1 | DESCENT | DESCENT |
| 7edc1dc9 | 1 | **none** | DESCNT2V |
| 49f310ee | 1 | **none** | MAGCARP |
| 494228a5 | 1 | **none** | QUARANT |
| 17d5dbaf | 1 | **none** | RIDDLE |
| be42c424 | 1 | **none** | SPYCRAFT |

## DigPak / MidPak

### SOUNDRV.COM: 14 games, 11 versions, 7 games covered by a traced version

| Version | Games | Traced | Games carrying it |
|---|---|---|---|
| 26d27868 | 2 | **none** | CAPTLSMP PERFECTG |
| 17eb5a74 | 2 | PIZZATYC, XCOMUF | PIZZATYC XCOMUF |
| 55e09abc | 2 | **none** | TRANSPOR TRANTDLX |
| 8ec2080b | 1 | **none** | INFERNO |
| cee6984b | 1 | **none** | TERMVEL |
| d4100210 | 1 | 7THGUEST | 7THGUEST |
| 6fd64689 | 1 | CAPTLSM | CAPTLSM |
| 9be34da6 | 1 | PIZZATYC | PIZZATYC |
| ff887aac | 1 | SIMON1 | SIMON1 |
| f7d94b0a | 1 | **none** | SIMON2 |
| 050abb72 | 1 | XCOMTE | XCOMTE |

### MIDPAK.COM: 7 games, 4 versions, 4 games covered by a traced version

| Version | Games | Traced | Games carrying it |
|---|---|---|---|
| 70cd2a5e | 4 | CAPTLSM | CAPTLSM ULTIMA3 ULTIMA4 ULTIMA5 |
| 872558d8 | 1 | **none** | CONTZACK |
| 259cd1b6 | 1 | **none** | PERFECTG |
| 10eb1acb | 1 | **none** | SIMON2 |

## Sierra SCI

### AUDBLAST.DRV: 21 games, 14 versions, 14 games covered by a traced version

| Version | Games | Traced | Games carrying it |
|---|---|---|---|
| 8c3c9db0 | 4 | KQ6CD, SQ4 | AMONRA KQ6CD SQ4 SQ5 |
| 3bc9b7b3 | 4 | SIDALS | QG1NEW SIDALS THEEVENM TINCM2 |
| 4c2bdfa8 | 2 | KQ6CD | KQ6CD QG3E |
| 1904089e | 1 | **none** | SILPHEED |
| 11a24451 | 1 | **none** | AMONRA |
| 786c446d | 1 | **none** | FREDDY |
| a3b3c502 | 1 | **none** | FREDDY |
| 8988cd85 | 1 | **none** | FREDDY |
| 290b80a1 | 1 | KQ5 | KQ5 |
| 5c0d83ea | 1 | **none** | LONGBOW |
| a4962e91 | 1 | LSL6CD | LSL6CD |
| d7987cb3 | 1 | LSL6CD | LSL6CD |
| 8fcb3e16 | 1 | **none** | PQ1_VGA |
| a4b3ba5d | 1 | SQ4 | SQ4 |

### SNDBLAST.DRV: 22 games, 13 versions, 13 games covered by a traced version

| Version | Games | Traced | Games carrying it |
|---|---|---|---|
| bcd5c334 | 6 | LSL2, PQ2 | CAMELOT KQ1VGA LSL2 LSL3 PQ2 QG1OLD |
| 33fd2158 | 2 | **none** | BEAMISH KRONDOR |
| 7ed06259 | 2 | KQ5 | KQ5 QG2 |
| fb3b6de8 | 2 | PQ3 | LSL5 PQ3 |
| 32266149 | 2 | PQ3 | PQ3 SQ1VGA |
| 4bc01518 | 1 | **none** | FIREHAWK |
| fe49f459 | 1 | **none** | LBOW1 |
| 129de13b | 1 | **none** | LSL1VGA |
| 472ffd5a | 1 | **none** | LSL1VGA |
| 6d68c102 | 1 | **none** | LSL5 |
| 68c6991c | 1 | **none** | SQ1VGA |
| b6cfca20 | 1 | **none** | SQ3 |
| 1a4b2c2e | 1 | SQ4 | SQ4 |

### ADL.DRV: 44 games, 19 versions, 31 games covered by a traced version

| Version | Games | Traced | Games carrying it |
|---|---|---|---|
| 5b3b9313 | 7 | KQ6CD, LSL6CD, SIDALS | FREDDY KQ6CD LSL6CD QG3E SIDALS THEEVENM TINCM2 |
| b7901ed6 | 7 | GK1, LSL6CD, SQ6 | GK1 GK2 KQ7 LSL6CD PQ4 QG4CD SQ6 |
| a793e4a9 | 6 | KQ5, PQ3 | KQ5 LONGBOW LSL1VGA LSL5 PQ3 SQ1VGA |
| e022fac0 | 3 | **none** | CAMELOT KQ1VGA SORCERIA |
| 6b5da0ad | 3 | SQ4 | PQ1_VGA QG1NEW SQ4 |
| b2b4afb4 | 2 | **none** | KQ4 LSL3 |
| eeca1310 | 2 | KQ5 | KQ5 QG2 |
| e7bad0ea | 2 | **none** | LBOW1 QG1OLD |
| d403b96d | 2 | PQ2 | PQ2 SQ3 |
| f664ce85 | 1 | **none** | FIREHAWK |
| 0af199c0 | 1 | **none** | SILPHEED |
| 74df836f | 1 | **none** | AMONRA |
| c73ae56e | 1 | **none** | KQ4 |
| 5b221925 | 1 | KQ6CD | KQ6CD |
| e156febd | 1 | **none** | KRONDOR |
| 21f64bc7 | 1 | LSL2 | LSL2 |
| d1ea2431 | 1 | SQ4 | SQ4 |
| a0a58517 | 1 | SQ4 | SQ4 |
| b15541c9 | 1 | **none** | SQ5 |

### GENMIDI.DRV: 28 games, 14 versions, 22 games covered by a traced version

| Version | Games | Traced | Games carrying it |
|---|---|---|---|
| 19fa55eb | 5 | SQ4 | LONGBOW LSL1VGA LSL5 SQ1VGA SQ4 |
| c20aac86 | 4 | SQ4 | AMONRA PQ1_VGA QG1NEW SQ4 |
| 136f2e33 | 4 | KQ6CD, SIDALS | KQ6CD SIDALS THEEVENM TINCM2 |
| 22aa1539 | 3 | LSL6CD | AMONRA FREDDY LSL6CD |
| c07662eb | 3 | SQ6 | GK2 KQ7 SQ6 |
| 8cba8ac7 | 1 | **none** | FREDDY |
| e2260f91 | 1 | GK1 | GK1 |
| 9d5362f2 | 1 | KQ6CD | KQ6CD |
| b8525cf2 | 1 | **none** | KRONDOR |
| ec714213 | 1 | LSL6CD | LSL6CD |
| 473654d1 | 1 | **none** | PQ4 |
| 81f4586d | 1 | **none** | QG3E |
| d7760675 | 1 | **none** | QG4CD |
| 145546b3 | 1 | **none** | SQ5 |

### MT32.DRV: 47 games, 24 versions, 31 games covered by a traced version

| Version | Games | Traced | Games carrying it |
|---|---|---|---|
| e2bcbb34 | 7 | KQ6CD, LSL6CD, SIDALS | FREDDY KQ6CD LSL6CD SIDALS SQ5 THEEVENM TINCM2 |
| ff31a3a4 | 6 | KQ5, PQ3 | KQ5 LONGBOW LSL1VGA LSL5 PQ3 SQ1VGA |
| b4cf2b9f | 4 | SQ4 | AMONRA PQ1_VGA QG1NEW SQ4 |
| f1851865 | 4 | SQ6 | GK2 KQ7 QG4CD SQ6 |
| 93a2d75b | 2 | **none** | TEMPEST2 UTOPTCON |
| c465a944 | 2 | **none** | CAMELOT SORCERIA |
| 1216bb30 | 2 | KQ5 | KQ5 QG2 |
| 9afec3d0 | 2 | KQ6CD | KQ6CD QG3E |
| b2896eda | 2 | **none** | LBOW1 QG1OLD |
| 38755038 | 2 | LSL6CD | LSL6CD PQ4 |
| f02d98fd | 1 | **none** | FIREHAWK |
| a0eb6e3f | 1 | **none** | SILPHEED |
| b3c987ca | 1 | GK1 | GK1 |
| 44641fff | 1 | **none** | HEROQUES |
| 672de4b9 | 1 | **none** | KQ1VGA |
| 5b54768a | 1 | **none** | KQ4 |
| 7220927b | 1 | **none** | KQ4 |
| a1e032df | 1 | **none** | KRONDOR |
| 7a2d5464 | 1 | LSL2 | LSL2 |
| 07664f7d | 1 | **none** | LSL3 |
| 51a3ce88 | 1 | PQ2 | PQ2 |
| 507fdad4 | 1 | **none** | SORCERIA |
| ca41366b | 1 | **none** | SQ3 |
| 1d7fc068 | 1 | SQ4 | SQ4 |

## Creative

### CT-VOICE.DRV: 4 games, 4 versions, 2 games covered by a traced version

| Version | Games | Traced | Games carrying it |
|---|---|---|---|
| b87abc0d | 1 | PREHISTO | PREHISTO |
| 2a3cd085 | 1 | **none** | BURNTIME |
| b832b265 | 1 | CAESAR | CAESAR |
| 1dc76c30 | 1 | **none** | MOONAHDK |

### SBFMDRV.COM: 4 games, 2 versions, 4 games covered by a traced version

| Version | Games | Traced | Games carrying it |
|---|---|---|---|
| e6dae339 | 3 | JILLJUNG | JILLGU JILLJUNG JILLSTP |
| 50d326fb | 1 | XARGON | XARGON |

