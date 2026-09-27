; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; Texts and tables with initial values.

usage_message db 'Use UCDDPLAY [<drive>] to play CD-Audio from a CD drive.',13,10
    db 'For a physical disc, set the virtual card to SB16 in UCDDSET.',13,10
    db 'Push F1 in UCDDPLAY to show the keys.',13,10
    db 'Use UCDDPLAY /? to show this information.',13,10,'$'
no_drives_message db 'No CD drive is available.',13,10,'$'
drive_error_message db 'The selected drive is not a CD drive.',13,10,'$'
vga_message db 'UCDDPLAY needs a VGA display.',13,10,'$'
memory_message db 'There is not sufficient memory.',13,10,'$'

message_mounted db 'THE IMAGE IS MOUNTED.',0
message_unmounted db 'THE IMAGE IS UNMOUNTED.',0
message_empty db 'NO IMAGE IS MOUNTED ON THE DRIVE.',0
message_bad_source db 'USE AN IMAGE ON A LOCAL HARD DISK.',0
message_bad_image db 'THE IMAGE CANNOT BE OPENED|OR IS NOT VALID.',0
message_bad_mdm db 'THE DISC LIST CANNOT BE MOUNTED.|CHECK ITS IMAGES AND XMS MEMORY.',0
message_in_use db 'THE DRIVE IS LOCKED OR IN USE.|TRY AGAIN.',0
message_refresh db 'THE IMAGE CHANGED. THE DRIVE|CACHE UPDATE FAILED.',0
message_play_error db 'THE DRIVE CANNOT PLAY THIS TRACK.',0
message_data_track db 'THIS IS A DATA TRACK.',0
message_no_disc db 'NO DISC. PUSH O TO SELECT A DISC.',0
message_physical_output db 'SET THE UCDD VIRTUAL CARD TO SB16.|CHECK BLASTER AND THE AUDIO SETUP.',0
message_physical_memory db 'THERE IS NOT SUFFICIENT MEMORY|FOR THE AUDIO BUFFER.',0
message_physical_read db 'THE DRIVE CANNOT READ CD AUDIO.|CHECK THE DISC AND CD DRIVER.',0
message_physical_slow db 'THE DRIVE OR CPU IS TOO SLOW.|PLAYBACK HAS STOPPED.',0
message_physical_stalled db 'THE AUDIO OUTPUT HAS STOPPED.|CHECK BLASTER AND THE AUDIO SETUP.',0
message_mount_drive db 'INSTALL UCDD TO MOUNT AN IMAGE.',0
message_eject_error db 'THE DRIVE CANNOT EJECT THE DISC.',0
message_no_hard_disk db 'NO LOCAL HARD DISK IS AVAILABLE.',0
message_slow db 'THE CPU IS TOO SLOW FOR|THE EQUALIZER. IT STAYS OFF.',0
message_no_audio db 'INSTALL UCDD WITH AUDIO SUPPORT.|CHECK THE DRIVER INSTALLATION.',0
message_no_filter db 'THE EQUALIZER AND THE ANALYZER|NEED A NEWER UCDD.EXE.',0

scroll_text db 'uCDD PLAY ... A CD PLAYER FOR IMAGES AND CD DRIVES ... '
    db 'PUSH O TO SELECT A DISC ... PUSH SPACE TO PLAY OR PAUSE ... '
    db 'PUSH F1 TO SEE ALL THE KEYS ... PUSH ESC TO STOP AND EXIT ... '
scroll_end:
scroll_length dw scroll_end-scroll_text

text_no_disc db 'NO DISC',0
text_tracks db 'TRK',0
text_play db 'PLAY',0
text_pause db 'PAUSE',0
text_stop db 'STOP',0
text_shuffle db 'SHUF',0
text_repeat db 'RPT',0
text_one db '1',0
text_all db 'ALL',0
text_dir db 'DIR',0
text_up db 'UP',0
text_user db 'USER',0
text_mount db 'OPEN',0
text_cd db 'CD',0
text_drive db 'DRIVE',0
text_cancel db 'CANCEL',0
text_request_keys db 'ENTER OPEN  BACKSPACE UP  TAB DRIVE  ESC CANCEL',0
drive_text db '?:',0
browse_title db 'OPEN A DISC',0
browse_title_drive db '?:',0
text_help_title db 'uCDD PLAY KEYS',0

help_lines:
    db 'SPACE',0,'PLAY OR PAUSE',0
    db 'ENTER',0,'PLAY THE SELECTED TRACK',0
    db 'S',0,'STOP',0
    db 'LEFT RIGHT',0,'SELECT THE PREVIOUS OR NEXT TRACK',0
    db '1 TO 0',0,'PLAY TRACK 1 TO 10',0
    db '< >',0,'MOVE BACK OR FORWARD 10 SECONDS',0
    db 'UP DOWN',0,'INCREASE OR DECREASE THE CD VOLUME',0
    db 'H',0,'SHUFFLE ON OR OFF',0
    db 'R',0,'REPEAT: OFF, ONE TRACK, OR ALL TRACKS',0
    db 'O',0,'OPEN AN IMAGE OR SELECT A CD DRIVE',0
    db 'E',0,'EJECT THE DISC',0
    db 'D',0,'SELECT THE NEXT CD DRIVE',0
    db 'TAB',0,'SELECT AN EQUALIZER SLIDER',0
    db '+ -',0,'INCREASE OR DECREASE THE SLIDER',0
    db 'Q',0,'EQUALIZER ON OR OFF',0
    db 'P',0,'SELECT THE NEXT EQUALIZER PRESET',0
    db 'V',0,'SELECT THE NEXT BOTTOM DISPLAY',0
    db 'F1',0,'SHOW THIS HELP',0
    db 'ESC',0,'STOP AND EXIT',0
    db ' ',0,'PUSH A KEY TO CLOSE THE HELP.',0
    db 0

key_table:
    db 27
    dw key_quit
    db ' '
    dw key_play
    db 13
    dw key_enter
    db 's'
    dw key_stop
    db 'S'
    dw key_stop
    db 'h'
    dw key_shuffle
    db 'H'
    dw key_shuffle
    db 'r'
    dw key_repeat
    db 'R'
    dw key_repeat
    db 'o'
    dw key_open
    db 'O'
    dw key_open
    db 'e'
    dw key_eject
    db 'E'
    dw key_eject
    db 'd'
    dw key_drive
    db 'D'
    dw key_drive
    db 'q'
    dw key_equalizer
    db 'Q'
    dw key_equalizer
    db 'p'
    dw key_preset
    db 'P'
    dw key_preset
    db 'v'
    dw key_visual
    db 'V'
    dw key_visual
    db '+'
    dw key_up_gain
    db '='
    dw key_up_gain
    db '-'
    dw key_down_gain
    db '_'
    dw key_down_gain
    db 9
    dw key_band
    db ','
    dw key_back
    db '<'
    dw key_back
    db '.'
    dw key_forward
    db '>'
    dw key_forward
    db '?'
    dw key_help
    db 0

scan_table:
    db 4bh
    dw key_previous
    db 4dh
    dw key_next
    db 49h
    dw key_previous
    db 51h
    dw key_next
    db 48h
    dw key_volume_up
    db 50h
    dw key_volume_down
    db 0fh
    dw key_band_back
    db 3bh
    dw key_help
    db 0

button_actions dw key_previous, key_play, key_stop, key_next, key_shuffle, key_repeat, key_open, key_eject
button_table:
    BUTTON_TABLE
digit_x:
    DIGIT_TABLE

click_regions:
    dw SLIDER_X0-8, SLIDER_TOP-4, SLIDER_X0+SLIDER_STEP*(SLIDERS-1)+8, SLIDER_BOTTOM+4, click_slider
    dw KNOB_X-12, KNOB_Y-11, KNOB_X+12, KNOB_Y+11, click_volume
    dw 10, 136, 29, 146, key_equalizer
    dw 30, 136, 58, 146, key_preset
    dw CALENDAR_X-2, CALENDAR_Y-1, CALENDAR_X+139, CALENDAR_Y+10, click_calendar
    dw PROGRESS_X, PROGRESS_Y-2, PROGRESS_X+PROGRESS_CELLS*4-1, PROGRESS_Y+3, click_progress
    dw 118, 55, 157, 76, key_drive
    dw SCROLL_X0, SCROLL_Y0, SCROLL_X1, SCROLL_Y1, key_visual
    dw LOGO_X0, LOGO_Y0, LOGO_X1, LOGO_Y1, key_help
    dw -1

request_buttons:
    dw REQ_X0+12, 50, browser_enter, text_mount
    dw REQ_X0+72, 50, browser_drive, text_drive
    dw REQ_X0+132, 32, browser_up, text_up
    dw REQ_X0+174, 60, browser_close, text_cancel
    dw 0

visual_table dw draw_warp, draw_scope, draw_waterfall, draw_fire, draw_bubbles, draw_plasma
visual_names dw name_warp, name_spectra, name_firebars, name_lavaflow, name_bubbles, name_plasma, name_random
name_warp db 'WARP SPEED',0
name_spectra db 'SPECTRA',0
name_firebars db 'FIREBARS',0
name_lavaflow db 'LAVAFLOW',0
name_bubbles db 'BUBBLES',0
name_plasma db 'PLASMA',0
name_random db 'RANDOM',0
bayer db 0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5
bubble_table:
    BUBBLE_TABLE

; Preamp, then 31 Hz to 16 kHz, then the name.
presets:
    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'FLAT',0,0,0,0
    db -2, 5, 4, 2, -1, -3, -1, 2, 4, 5, 5, 'ROCK',0,0,0,0
    db -1, -1, 1, 3, 4, 3, 0, -1, -1, 0, 0, 'POP',0,0,0,0,0
    db 0, 3, 2, 1, 2, -1, -1, 0, 1, 2, 3, 'JAZZ',0,0,0,0
    db 0, 4, 3, 2, 1, -1, -1, 0, 2, 3, 4, 'CLASSIC',0
    db -4, 7, 6, 5, 3, 1, 0, 0, 0, 0, 0, 'BASS',0,0,0,0
    db -4, 0, 0, 0, 0, 0, 1, 3, 5, 6, 7, 'TREBLE',0,0
    db -1, -2, -2, -1, 1, 3, 4, 3, 1, 0, -1, 'VOCAL',0,0,0
    db -4, 6, 4, 0, 0, -2, 0, -1, 0, 4, 6, 'LOUD',0,0,0,0
presets_end:

copper_profile db 16, 30, 44, 56, 64, 56, 44, 30, 16
frame_rings db C_GOLD_HI, C_GOLD_LO, C_GOLD, C_GOLD_LO, C_GOLD_LO, C_GOLD_LO
    db C_BLACK, C_BLACK, C_KNOB+1, C_KNOB+1, C_KNOB+3, C_KNOB+3
burgundy_rows db C_BURG0, C_BURG0, C_BURG0, C_BURG0, C_BURG1, C_BURG1
    db C_BURG1, C_BURG1, C_BURG2, C_BURG2, C_BURG2, C_BURG2
button_rows db C_KNOB, C_KNOB, C_KNOB+1, C_KNOB+1, C_KNOB+1, C_KNOB+2, C_KNOB+3
    db C_KNOB+2, C_KNOB+4, C_KNOB+4, C_KNOB+1, C_KNOB+1, C_KNOB+2
select_rows db C_SEL0, C_SEL0, C_SEL1, C_SEL1, C_SEL2, C_SEL2, C_SEL3, C_SEL3, C_SEL3
curl_points db 1,0, 1,1, 1,2, 0,2, -1,2, -2,2, -3,1, -4,0, -4,-1, -4,-2, -3,-3, -2,-4
    db -1,-4, 0,-4, 1,-4, 2,-4
curl_points_end:

preset_name dw presets+11
disc_timer db 1
poll_timer db 1
eq_on db 1
eq_band db 1
volume db 255
vis_choice db VIS_RANDOM
