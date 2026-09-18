"""Undo the reorganisation: moves every file back to where it was (run from any folder)."""
import csv, os
os.chdir('C:/Users/NFuru/Desktop/MASTER/TFM/BASE DE DATOS VOX')
rows = list(csv.DictReader(open('archive/restructure_manifest.csv', encoding='utf-8')))
for r in reversed(rows):
    os.makedirs(os.path.dirname(r['original_path']) or '.', exist_ok=True)
    os.rename(r['new_path'], r['original_path'])
print('restored', len(rows), 'entries')
