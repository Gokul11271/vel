import os
import subprocess
import sys

env = os.environ.copy()
env['JAVA_HOME'] = r'D:\Android\jdk-17.0.12+7'
env['PATH'] = r'D:\Android\jdk-17.0.12+7\bin;' + env.get('PATH', '')

cmd = [r'D:\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat', '--sdk_root=D:\\Android\\Sdk', 'ndk;28.2.13676358']

proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env)

buffer = ""
while True:
    line = proc.stdout.readline()
    if not line and proc.poll() is not None:
        break
    if line:
        print(line, end='', flush=True)
        if 'Accept? (y/N):' in line or '(y/N)?' in line:
            proc.stdin.write('y\n')
            proc.stdin.flush()
            print("[Auto-Accepted License]", flush=True)

rc = proc.poll()
print(f"\nNDK install finished with code: {rc}")
