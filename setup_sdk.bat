@echo off
set "JAVA_HOME=D:\Android\jdk-17.0.12+7"
set "ANDROID_HOME=D:\Android\Sdk"
set "ANDROID_SDK_ROOT=D:\Android\Sdk"
set "PATH=D:\Android\jdk-17.0.12+7\bin;D:\Android\Sdk\platform-tools;D:\Android\Sdk\cmdline-tools\latest\bin;%PATH%"

echo Checking Java version:
java -version

if not exist "D:\Android\Sdk\licenses" mkdir "D:\Android\Sdk\licenses"

(
echo 24333f8a63b1d99d309e567605d6e173254f1d0de
echo 89337d1250775148b168f4930774708a5fffe4f8
echo d56f5187479451eabf01fb78af6dfcb131a6481e
) > "D:\Android\Sdk\licenses\android-sdk-license"

echo 859f317696f67ef3d7f30a50a5560e7834b433fb > "D:\Android\Sdk\licenses\android-sdk-arm-dbt-license"
echo 601085b94cd77f0b54ff86406957099fed7926dd > "D:\Android\Sdk\licenses\android-googletv-license"
echo 33b6a2b64607f11b759f320e80179f43f321d10e > "D:\Android\Sdk\licenses\google-gdk-license"
echo e9acab5b5fbb560a72cfa4f46c0b907b9468f2d0 > "D:\Android\Sdk\licenses\mips-android-sysimage-license"

echo Installing Android Platform 34 and Build-Tools...
call "D:\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat" --sdk_root="D:\Android\Sdk" "platforms;android-34" "build-tools;34.0.0"

echo Android SDK setup complete!
