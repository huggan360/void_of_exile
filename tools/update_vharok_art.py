#!/usr/bin/env python3
"""Regenerate only Vharok and his two additional projectile assets. No preview."""
import json
import redesign_pixel_bosses as art

art.demon()
art.vharok_shots()
manifest_path = art.OUT / 'boss_projectiles/manifest.json'
existing = json.loads(manifest_path.read_text())
new_ids = {entry['id'] for entry in art.PROJECTILES}
manifest_path.write_text(json.dumps([entry for entry in existing if entry['id'] not in new_ids] + art.PROJECTILES, indent=2) + '\n')
(art.OUT / 'realm_boss_manifest.json').write_text(json.dumps(art.MANIFEST, indent=2) + '\n')
