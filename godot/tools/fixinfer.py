#!/usr/bin/env python3
"""Uruchamia Godota bez okna i automatycznie poprawia błędy „Cannot infer the type” (var x := … -> var x = …)."""
import re, subprocess, sys
GODOT='/Applications/Godot.app/Contents/MacOS/Godot'
for it in range(25):
    out=subprocess.run([GODOT,'--headless','--audio-driver','Dummy','--path','.','--quit-after','3'],capture_output=True,text=True,timeout=300)
    txt=out.stdout+out.stderr
    errs=re.findall(r'Cannot infer the type of "(\w+)" variable.*?\n\s+at: GDScript::reload \(res://([\w/\.]+):(\d+)\)',txt)
    if not errs:
        rest=[l for l in txt.split('\n') if re.search(r'ERROR|Error|at: ',l) and 'leaked' not in l and 'resources still in use' not in l and 'cleanup' not in l and 'clear (core' not in l]
        print('\n'.join(rest[:40]) if rest else 'OK: brak błędów')
        break
    for name,path,line in errs:
        ls=open(path,encoding='utf-8').read().split('\n')
        i=int(line)-1
        new=re.sub(r'\bvar %s :='%re.escape(name),'var %s ='%name,ls[i],1)
        if new==ls[i]:
            print('NIE UMIEM:',path,line,ls[i].strip()); sys.exit(1)
        ls[i]=new
        open(path,'w',encoding='utf-8').write('\n'.join(ls))
        print('fix',path,line,name)
