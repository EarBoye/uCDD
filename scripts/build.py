# SPDX-FileCopyrightText: 2026 vorvek
# SPDX-License-Identifier: GPL-3.0-only

"""Build the DOS programs with NASM."""

from pathlib import Path
import argparse
import shutil
import struct
import subprocess

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / 'build'


def assemble(source, name, defines=(), exe=False, listing=False):
    BUILD.mkdir(exist_ok=True)
    nasm = shutil.which('nasm')
    if not nasm:
        raise SystemExit('NASM is required.')
    output = BUILD / name
    subprocess.run([nasm, '-f', 'bin', '-I', str(ROOT / 'src') + '/',
                    *(['-l', str(output.with_suffix('.lst'))] if listing else []),
                    *['-D' + value for value in defines], str(ROOT / source),
                    '-o', str(output)], check=True)
    if exe:
        payload = output.read_bytes()
        stack_segment = (len(payload) + 15) // 16
        if len(payload) > 65536:
            raise ValueError('The program exceeds one DOS segment.')
        size = 32 + len(payload)
        header = struct.pack('<14H', 0x5a4d, size % 512, (size + 511) // 512,
                             0, 2, 64, 64, stack_segment, 1024, 0, 0, 0, 28, 0)
        output.write_bytes(header.ljust(32, b'\0') + payload)
    print(f'{name}: {output.stat().st_size} bytes')


def main():
    global BUILD
    parser = argparse.ArgumentParser()
    parser.add_argument('--resident-audio', '--own-host', action='store_true',
                        help='Build resident audio with the internal DPMI host.')
    parser.add_argument('--profile-host', action='store_true',
                        help='Build host counters in build/profile. Use with --resident-audio.')
    parser.add_argument('--flat-sink', action='store_true',
                        help='Reflect flat segments to real mode as segment A000, not 0.')
    parser.add_argument('--inject-register', action='store_true',
                        help='Recognise PUSHF, POP reg, CLI and mark the flags image in the register.')
    parser.add_argument('--audio-period-frames', type=int, choices=(32, 64, 128, 256),
                        default=32, help='Set the resident audio output period for testing.')
    args = parser.parse_args()
    if args.audio_period_frames != 32 and not args.resident_audio:
        parser.error('--audio-period-frames requires --resident-audio.')
    if args.profile_host:
        if not args.resident_audio:
            parser.error('--profile-host requires --resident-audio.')
        BUILD = BUILD / 'profile'
        BUILD.mkdir(parents=True, exist_ok=True)
    for source, name in [('src/ucdd.asm', 'UCDD.EXE'),
                         ('src/setup.asm', 'UCDDSET.EXE')]:
        if args.resident_audio and name == 'UCDD.EXE':
            defines = [f'OUTPUT_SHIFT={args.audio_period_frames.bit_length()-1}']
            if args.flat_sink:
                defines.append('FLAT_SINK=1')
            if args.inject_register:
                defines.append('INJECT_REG=1')
            assemble_resident_host(tuple(defines),
                                   profile=args.profile_host)
        else:
            assemble(source, name, exe=True)
    assemble_player()
    (BUILD / 'UCDDRV.EXE').unlink(missing_ok=True)
    if (ROOT / 'tests' / 'probe.asm').is_file():
        assemble('tests/probe.asm', 'PROBE.COM')
        assemble('tests/packets.asm', 'PACKETS.COM')
        assemble('tests/cue_packets.asm', 'CUEPACK.COM')
        assemble('tests/audio_cd_state.asm', 'CDSTATE.COM')
        assemble('tests/audio_background.asm', 'CDBG.COM')
        assemble('tests/file_crc.asm', 'FILECRC.COM')
        assemble('tests/exit.asm', 'PASS.COM')
        assemble('tests/exit.asm', 'FAIL.COM', ('EXIT_CODE=1',))


def assemble_resident_host(defines=(), profile=False):
    assemble('src/host/resident.asm', 'UCDDHOST.BIN',
             (*defines, *(('HOST_PROFILE=1',) if profile else ())), listing=True)
    host = (BUILD / 'UCDDHOST.BIN').read_bytes()
    if len(host) > 65535:
        raise ValueError('The host exceeds one segment.')
    resident_defines = ('RESIDENT_AUDIO=1', 'OWN_HOST=1', f'OWN_HOST_SIZE={len(host)}', *defines)
    assemble('src/ucdd.asm', 'UCDD.EXE', (*resident_defines, 'OWN_HOST_OFFSET=65536'), exe=True, listing=True)
    program = (BUILD / 'UCDD.EXE').read_bytes()
    if len(program) > 65536:
        raise ValueError('The driver overlaps its host overlay.')
    (BUILD / 'UCDD.EXE').write_bytes(program.ljust(65536, b'\0') + host)
    print(f'UCDD.EXE with internal host: {65536 + len(host)} bytes')


def assemble_player():
    assemble('src/play.asm', 'UCDDPLAY.BIN', listing=True)
    program = (BUILD / 'UCDDPLAY.BIN').read_bytes()
    (BUILD / 'UCDDPLAY.BIN').unlink()
    if len(program) > 65534:
        raise ValueError('UCDDPLAY exceeds one segment.')
    # The word at offset 3 is the start of the zero data, which is not stored.
    zero = struct.unpack_from('<H', program, 3)[0]
    if any(program[zero:]):
        raise ValueError('UCDDPLAY has data in its zero area.')
    assets = (ROOT / 'src' / 'play' / 'assets.bin').read_bytes()
    assets += bytes(-len(assets) % 16)
    code = len(assets) // 16
    image = assets + program[:zero]
    size = 32 + len(image)
    extra = (len(program) - zero + 15) // 16
    header = struct.pack('<14H', 0x5a4d, size % 512, (size + 511) // 512, 0, 2, extra, extra,
                         code, len(program) & 0xfffe, 0, 0, code, 28, 0)
    (BUILD / 'UCDDPLAY.EXE').write_bytes(header.ljust(32, b'\0') + image)
    print(f'UCDDPLAY.EXE: {size} bytes')


if __name__ == '__main__':
    main()
