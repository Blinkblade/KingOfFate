"""Verify mixed body/effect palettes through the actual sffpack CLI."""
import csv
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from kofassets import sff, sffwrite

work = Path(sys.argv[1])
work.mkdir(parents=True, exist_ok=True)
palettes = [[(0, 0, 0, 0), (240, 30, 20, 255)],
            [(0, 0, 0, 0), (20, 190, 250, 255)]]
sprites = [dict(group=0, number=i, width=1, height=1, axis_x=0, axis_y=0,
                pal_index=1, format=0, payload=b'\x01') for i in range(3)]
source = work / 'source.sff'
source.write_bytes(sffwrite.build_sff_v2(sprites, palettes))
mapping = work / 'mapping.csv'
output = work / 'output.sff'

def run(values, expected, duplicate=False, extra=()):
    with mapping.open('w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(['target_group', 'target_image', 'source_group',
                         'source_image', 'action', 'notes', 'palette_index'])
        for i, value in enumerate(values):
            writer.writerow([10, 0 if duplicate else i, 0, i, '', 'body/effect fixture', value])
    result = subprocess.run([sys.executable, str(ROOT / 'tools/sffpack/sffpack.py'),
                             'transcode', str(source), '--out', str(output),
                             '--remap', str(mapping), '--force-palette', '0', *extra],
                            capture_output=True, text=True)
    assert result.returncode == expected, (result.returncode, result.stdout, result.stderr)
    return result.stdout

run(['', 'source', '1'], 0)
packed = sff.Sff.load(str(output))
assert packed.rgba(packed.sprite(10, 0))[0] == bytes(palettes[0][1])
assert packed.rgba(packed.sprite(10, 1))[0] == bytes(palettes[1][1])
assert packed.rgba(packed.sprite(10, 2))[0] == bytes(palettes[1][1])
assert 'palette_index' in run(['-1'], 2)
run(['missing'], 2)
assert 'palette' in run(['9'], 1)
assert 'duplicate target' in run(['', 'source'], 2, duplicate=True)
act = work / 'selectable.act'
act_colours = [(0, 0, 0), (25, 80, 220)] + [(0, 0, 0)] * 254
act.write_bytes(b''.join(bytes(colour) for colour in reversed(act_colours)))
run(['', 'source'], 0, extra=['--selection-palette', str(act)])
packed = sff.Sff.load(str(output))
assert packed.rgba(packed.sprite(10, 0), 0)[0] == bytes(palettes[0][1])
assert packed.rgba(packed.sprite(10, 0), 1)[0] == bytes((25, 80, 220, 255))
assert packed.sprite(10, 1).pal_index >= 2
assert packed.rgba(packed.sprite(10, 1))[0] == bytes(palettes[1][1])
act.write_bytes(b'broken ACT')
assert '768' in run([''], 2, extra=['--selection-palette', str(act)])
print('palette remap: forced body, native effects, selectable ACT banks and 5 failure cases PASS')
