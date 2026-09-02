@echo off
set "JAVA_HOME=D:\Android\jdk-17.0.12+7"
set "ANDROID_HOME=D:\Android\Sdk"
set "ANDROID_SDK_ROOT=D:\Android\Sdk"
set "GRADLE_USER_HOME=D:\Android\.gradle"
set "ANDROID_USER_HOME=D:\Android\.android"
set "PATH=D:\Android\jdk-17.0.12+7\bin;D:\Android\Sdk\platform-tools;D:\Android\Sdk\cmdline-tools\latest\bin;%PATH%"

cd /d "D:\vel\in_gokul_app"
flutter run -d 10475eff
