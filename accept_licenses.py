import os
import subprocess
import time

env = os.environ.copy()
env['JAVA_HOME'] = r'D:\Android\jdk-17.0.12+7'
env['PATH'] = r'D:\Android\jdk-17.0.12+7\bin;' + env.get('PATH', '')

cmd = [r'D:\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat', '--sdk_root=D:\\Android\\Sdk', '--licenses']

proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env)

while True:
    output = proc.stdout.readline()
    if output == '' and proc.poll() is not None:
        break
    if output:
        print(output.strip())
        if '(y/N)?' in output:
            proc.stdin.write('y\n')
            proc.stdin.flush()

rc = proc.poll()
print(f"Finished with return code: {rc}")
