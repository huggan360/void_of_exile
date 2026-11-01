#!/usr/bin/env python3
"""Run an isolated account-free ENet server and two actual clients on localhost."""
from pathlib import Path
import os, subprocess, time, sys
root = Path(__file__).resolve().parents[2]
folder = Path('/home/hugo/tmp/voidrealm_status_network')
folder.mkdir(parents=True, exist_ok=True)
for path in folder.iterdir():
    if path.is_file(): path.unlink()
command = ['/home/hugo/Godot/godot_voxel_editor', '--headless', '--path', str(root)]
env = dict(os.environ, XDG_DATA_HOME=str(folder/'userdata'))
processes, handles = [], []
try:
    for kind, role in [('server', 0), ('client', 1), ('client', 2)]:
        if role == 1:
            deadline = time.monotonic()+8
            while not (folder/'ready').exists() and time.monotonic()<deadline: time.sleep(.05)
        handle = (folder/f'{kind}{role}.log').open('w')
        handles.append(handle)
        args = command+[f'res://tools/net/status_{kind}_check.tscn']
        if role: args += ['--', f'--role={role}']
        processes.append(subprocess.Popen(args, env=env, stdout=handle, stderr=subprocess.STDOUT))
    deadline = time.monotonic()+32
    while time.monotonic()<deadline and any(p.poll() is None for p in processes): time.sleep(.1)
finally:
    for process in processes:
        if process.poll() is None: process.terminate(); process.wait(timeout=5)
    for handle in handles: handle.close()
failed = any(p.returncode != 0 for p in processes)
for path in sorted(folder.glob('*.log')):
    log = path.read_text()
    failed |= 'SCRIPT ERROR:' in log or 'ERROR:' in log
    print(path.name+'\n'+log)
sys.exit(1 if failed else 0)
