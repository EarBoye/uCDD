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
DRIVER_ENTRY_IP = 32


def assemble(source, name, defines=(), exe=False, listing=False):
    BUILD.mkdir(exist_ok=True)
    nasm = shutil.which('nasm')
    if not nasm:
        raise SystemExit('NASM is required.')
    output = BUILD / name
    entry_ip = 0
    driver = (ROOT / source).resolve() == (ROOT / 'src/ucdd.asm').resolve()
    symbols = output.with_suffix('.map')
    if driver:
        entry_ip = DRIVER_ENTRY_IP
        defines = (*defines, f'UCDD_ENTRY_IP={entry_ip}')
        symbols.with_suffix('.inc').write_text(f'[map symbols {symbols.as_posix()}]\n')
    subprocess.run([nasm, '-f', 'bin', '-I', str(ROOT / 'src') + '/',
                    *(['-P', str(symbols.with_suffix('.inc'))] if driver else []),
                    *(['-l', str(output.with_suffix('.lst'))] if listing else []),
                    *['-D' + value for value in defines], str(ROOT / source),
                    '-o', str(output)], check=True)
    if exe:
        payload = output.read_bytes()
        stack_segment = (len(payload) + 15) // 16
        extra = 64
        main_size = len(payload)
        if driver:
            # The stack is the 1 KB gap between the main segment and the helper.
            symbols.with_suffix('.inc').unlink()
            table = dict(line.split()[2:0:-1] for line in symbols.read_text().splitlines()
                         if len(line.split()) == 3 and line.split()[0] != 'Real')
            symbols.unlink()
            stack_segment = int(table['program_end'], 16) // 16
            main_size = stack_segment * 16 + 1024
            extra = 1
            if len(payload) - main_size > 65536:
                raise ValueError('The command helper exceeds one DOS segment.')
        if main_size > 65536:
            raise ValueError('The program exceeds one DOS segment.')
        size = 32 + len(payload)
        header = struct.pack('<14H', 0x5a4d, size % 512, (size + 511) // 512,
                             0, 2, extra, extra, stack_segment, 1024, 0, entry_ip, 0, 28, 0)
        output.write_bytes(header.ljust(32, b'\0') + payload)
    print(f'{name}: {output.stat().st_size} bytes')


def main():
    global BUILD
    parser = argparse.ArgumentParser()
    parser.add_argument('--resident-audio', '--own-host', action='store_true',
                        help='Build resident audio with the internal DPMI host.')
    parser.add_argument('--profile-host', action='store_true',
                        help='Build host counters in build/profile. Use with --resident-audio.')
    parser.add_argument('--profile-driver', action='store_true',
                        help='Build driver cycle counters (RDTSC, Pentium or later) in build/profile. Use with --resident-audio.')
    parser.add_argument('--no-refill-hint', action='store_true',
                        help='Test build: ignore the retrace hint for deferred CD refills.')
    # The disk IRQ handling is always built: UCDDSET finds the IRQs at
    # installation. The option is kept so that older build commands still work.
    parser.add_argument('--disk-irq-direct', action='store_true',
                        help=argparse.SUPPRESS)
    # These fixes are on by default. The --no- options build without one, to
    # test it on its own.
    parser.add_argument('--split-word-io', action='store_true', help=argparse.SUPPRESS)
    parser.add_argument('--no-split-word-io', dest='split_word_io_off', action='store_true',
                        help='Reject a word port access to the virtual card, as 0.9.3 does.')
    parser.add_argument('--flat-sink', action='store_true', help=argparse.SUPPRESS)
    parser.add_argument('--no-flat-sink', dest='flat_sink_off', action='store_true',
                        help='Reflect flat segments to real mode as segment 0, as 0.9.3 does.')
    parser.add_argument('--inject-register', action='store_true', help=argparse.SUPPRESS)
    parser.add_argument('--no-inject-register', dest='inject_register_off', action='store_true',
                        help='Do not recognise the flags image in a register (PUSHF, POP reg, CLI).')
    parser.add_argument('--virtual-ess', action='store_true',
                        help='Include the virtual ESS AudioDrive (virtual model 4). Left out by '
                             'default for now: the Sound Blasters take its room in the segment.')
    parser.add_argument('--audio-period-frames', type=int, choices=(32, 64, 128, 256),
                        default=128, help='Set the resident audio output period for testing.')
    parser.add_argument('--audio-ring-periods', type=int, choices=(2, 3, 4),
                        default=3, help='Set the number of output periods in the DMA ring for testing.')
    args = parser.parse_args()
    if (args.audio_period_frames != 128 or args.audio_ring_periods != 3) and not args.resident_audio:
        parser.error('--audio-period-frames and --audio-ring-periods require --resident-audio.')
    if args.profile_host or args.profile_driver:
        if not args.resident_audio:
            parser.error('--profile-host and --profile-driver require --resident-audio.')
        BUILD = BUILD / 'profile'
        BUILD.mkdir(parents=True, exist_ok=True)
    for source, name in [('src/ucdd.asm', 'UCDD.EXE'),
                         ('src/setup.asm', 'UCDDSET.EXE')]:
        if args.resident_audio and name == 'UCDD.EXE':
            defines = [f'OUTPUT_SHIFT={args.audio_period_frames.bit_length()-1}',
                       f'RING_PERIODS={args.audio_ring_periods}']
            if args.no_refill_hint:
                defines.append('NO_REFILL_HINT=1')
            if not args.split_word_io_off:
                defines.append('SPLIT_WORD_IO=1')
            if not args.flat_sink_off:
                defines.append('FLAT_SINK=1')
            if not args.inject_register_off:
                defines.append('INJECT_REG=1')
            if args.virtual_ess:
                defines.append('VIRTUAL_ESS=1')
            if args.profile_driver:
                defines.append('DRIVER_PROFILE=1')
            import os
            for extra in os.environ.get('UCDD_DEFINES', '').split():
                defines.append(extra)
            assemble_resident_host(tuple(defines),
                                   profile=args.profile_host)
        else:
            assemble(source, name, ('VIRTUAL_ESS=1',) if args.virtual_ess else (), exe=True)
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
    # The loader reads 32 KB, then up to 64 KB less a byte; the install code's
    # own limit is checked in src/host/resident.asm (host_scratch_check).
    if len(host) > 0x8000 + 0xffff:
        raise ValueError('The host exceeds what the loader reads.')
    resident_defines = ('RESIDENT_AUDIO=1', 'OWN_HOST=1', f'OWN_HOST_SIZE={len(host)}', *defines)
    # The host follows the program image in the file.
    offset = 0
    while True:
        assemble('src/ucdd.asm', 'UCDD.EXE', (*resident_defines, f'OWN_HOST_OFFSET={offset}'), exe=True, listing=True)
        program = (BUILD / 'UCDD.EXE').read_bytes()
        if offset == (len(program) + 15) // 16 * 16:
            break
        offset = (len(program) + 15) // 16 * 16
    (BUILD / 'UCDD.EXE').write_bytes(program.ljust(offset, b'\0') + host)
    print(f'UCDD.EXE with internal host: {offset + len(host)} bytes')


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
