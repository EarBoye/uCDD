#!/usr/bin/env python3
"""Before a game is run: what the notes already know about its sound engine.

    game.py FOLDER [FOLDER ...]

For each game folder it finds the sound driver files the census knows by
name, hashes each as the census does (the first 8 digits of the MD5), and
looks up the game in inventory.md, each version in census.md and each
family in matrix.toml, with the findings its family page names. It exits 1
when the notes lack something, and says what to add before the run: a row
in the inventory, a row in the census, a trace of a version nobody traced,
or for an engine with no family yet, a page and a [families] entry.

Engines built into the game have no driver file: for those the inventory
row is the only record, and a game missing from it is scanned by hand for
the engine's signature strings. A game that runs from its disc image keeps
its drivers there; scan the image by hand. Run it from a uCDD worktree, so
the library branch can be read.
"""

from pathlib import Path
import hashlib
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'matrix'))
import plan  # noqa: E402

FINDING = re.compile(r'\bF\d{1,2}\b')


def census_index(text):
    """(file, version) -> (section, traced games), and every driver file name."""
    index, section, driver = {}, None, None
    for line in text.splitlines():
        if line.startswith('## '):
            section = line[3:].strip()
        elif line.startswith('### '):
            driver = line[4:].split(':')[0].strip()
        elif line.startswith('| ') and driver:
            cells = [cell.strip() for cell in line.strip().strip('|').split('|')]
            if len(cells) == 4 and re.fullmatch(r'[0-9a-f]{8}', cells[0]):
                traced = [] if 'none' in cells[2] else [game.strip() for game in cells[2].split(',')]
                index[(driver, cells[0])] = (section, traced)
    return index, {driver for driver, _ in index}


def inventory_index(text):
    """Game -> (engine, traced)."""
    rows = {}
    for line in text.splitlines():
        cells = [cell.strip() for cell in line.strip().strip('|').split('|')]
        if len(cells) >= 5 and re.fullmatch(r'[A-Z0-9!_-]+', cells[0]):
            rows[cells[0]] = (cells[1], cells[4])
    return rows


def families_of(matrix, section=None, engine=None):
    """The families a census section or an inventory Engine cell belongs to."""
    engines = {name.replace('(on its disc)', '').strip() for name in (engine or '').split(',')}
    return [slug for slug, family in matrix.data.get('families', {}).items()
            if section in family.get('census', []) or engines & set(family.get('inventory', []))]


def drivers_in(folder, names):
    found = []
    for path in sorted(Path(folder).rglob('*')):
        if path.is_file() and path.name.upper() in names:
            found.append((path.name.upper(), hashlib.md5(path.read_bytes()).hexdigest()[:8], path))
    return found


def look(matrix, folder, census, drivers, inventory, pages):
    game = Path(folder).resolve().name.upper()
    out, missing, families = [f'{game} ({folder})'], [], set()
    row = inventory.get(game)
    if row:
        engine, traced = row
        out.append(f'  inventory: {engine}; traced: {traced or "no"}')
        found = families_of(matrix, engine=engine)
        families.update(found)
        if not found and not engine.startswith('own'):
            missing.append(f'engine "{engine}" has no family: write its page in the library and '
                           'give it a [families] entry in matrix.toml')
    else:
        missing.append(f'{game} is not in inventory.md: scan its files for the engines\' signatures '
                       'and add its row')
    for name, version, path in drivers_in(folder, drivers):
        known = census.get((name, version))
        if not known:
            section = next((section for (driver, _), (section, _) in census.items() if driver == name), None)
            families.update(families_of(matrix, section=section))
            out.append(f'  {name} {version}: NEW version ({path})')
            missing.append(f'{name} {version} is not in census.md: add its row under {section}, and trace '
                           'it before its family\'s survey can cover it')
            continue
        section, traced = known
        families.update(families_of(matrix, section=section))
        out.append(f'  {name} {version}: known ({section}), '
                   + (f'traced by {", ".join(traced)}' if traced else 'NOT TRACED'))
        if not traced:
            missing.append(f'{name} {version} has no trace: trace this game before the family is covered')
    for slug in sorted(families):
        page = matrix.data['families'][slug]['page']
        findings = sorted(set(FINDING.findall(pages.get(page, ''))), key=lambda f: int(f[1:]))
        out.append(f'  family: {slug} ({page}); findings on its page: {", ".join(findings) or "none"}')
    out += [f'  add: {item}' for item in missing] or ['  the notes know this game and its drivers']
    return out, bool(missing)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    matrix = plan.load()
    census, drivers = census_index(plan.library_text(matrix, 'census.md'))
    inventory = inventory_index(plan.library_text(matrix, 'inventory.md'))
    pages = {}
    for family in matrix.data.get('families', {}).values():
        try:
            pages[family['page']] = plan.library_text(matrix, family['page'])
        except SystemExit:
            pages[family['page']] = ''
    lacking = False
    for folder in sys.argv[1:]:
        lines, missing = look(matrix, folder, census, drivers, inventory, pages)
        print('\n'.join(lines))
        lacking |= missing
    return 1 if lacking else 0


if __name__ == '__main__':
    sys.exit(main())
