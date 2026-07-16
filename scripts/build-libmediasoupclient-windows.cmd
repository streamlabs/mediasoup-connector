@echo off

set Z7_PATH="C:\Program Files\7-Zip"
set ORIGINAL_WORK_DIR=%CD%
set WEBRTC_FOLDER=%1
set GIT_TAG=3.5.0
set GIT_FOLDER_NAME=libmediasoupclient
set GIT_FOLDER_PATH=%ORIGINAL_WORK_DIR%\%GIT_FOLDER_NAME%
set BUILD_FOLDER_NAME=build
set BUILD_FOLDER_PATH=%GIT_FOLDER_PATH%\build
set PACKAGE_FOLDER_NAME=libmediasoupclient_dist
set PACKAGE_FOLDER_PATH=%ORIGINAL_WORK_DIR%\%PACKAGE_FOLDER_NAME%

if [%WEBRTC_FOLDER%] == [] (
	echo The combined include and lib webrtc folder path is missed. Use: build-libmediasoupclient-windows.cmd COMBINED_WEBRTC_FOLDER_PATH
	goto end
)

if exist %GIT_FOLDER_PATH%\ goto skip_checkout

echo ### Cloning ...

call git clone --recurse-submodules https://github.com/versatica/libmediasoupclient.git

echo f | xcopy libmediasoupclient.patch "%GIT_FOLDER_NAME%\libmediasoupclient.patch" /yf

cd %GIT_FOLDER_NAME%

echo ### Checkout %GIT_TAG% ...
call git checkout -b %GIT_TAG%-build %GIT_TAG%

echo ### Patching ...
call git apply --ignore-whitespace libmediasoupclient.patch

if %errorlevel% neq 0 goto end

:skip_checkout

cd %GIT_FOLDER_PATH%

if exist %BUILD_FOLDER_NAME%\ goto skip_build

echo ### Configuring for build ...
cmake . -B%BUILD_FOLDER_NAME% -DLIBWEBRTC_INCLUDE_PATH=%WEBRTC_FOLDER% -DLIBWEBRTC_BINARY_PATH=%WEBRTC_FOLDER%

echo ### Building ...
cmake --build %BUILD_FOLDER_NAME% --config RelWithDebInfo

if %errorlevel% neq 0 goto end

:skip_build

cd %ORIGINAL_WORK_DIR%

if exist %PACKAGE_FOLDER_PATH%\ goto skip_copy

echo ### Copying files for the package ...

mkdir %PACKAGE_FOLDER_PATH%\include\mediasoupclient %PACKAGE_FOLDER_PATH%\include\sdptransform %PACKAGE_FOLDER_PATH%\lib

xcopy "%GIT_FOLDER_PATH%\include\*.hpp" "%PACKAGE_FOLDER_PATH%\include\mediasoupclient" /sy
xcopy "%BUILD_FOLDER_PATH%\_deps\libsdptransform-src\include\*.hpp" "%PACKAGE_FOLDER_PATH%\include\sdptransform" /sy

echo f | xcopy "%BUILD_FOLDER_PATH%\RelWithDebInfo\mediasoupclient.lib" "%PACKAGE_FOLDER_PATH%\lib\mediasoupclient.lib" /yf
echo f | xcopy "%BUILD_FOLDER_PATH%\RelWithDebInfo\mediasoupclient.pdb" "%PACKAGE_FOLDER_PATH%\lib\mediasoupclient.pdb" /yf
echo f | xcopy "%BUILD_FOLDER_PATH%\_deps\libsdptransform-build\RelWithDebInfo\sdptransform.lib" "%PACKAGE_FOLDER_PATH%\lib\sdptransform.lib" /yf
echo f | xcopy "%BUILD_FOLDER_PATH%\_deps\libsdptransform-build\RelWithDebInfo\sdptransform.pdb" "%PACKAGE_FOLDER_PATH%\lib\sdptransform.pdb" /yf

echo f | xcopy "%BUILD_FOLDER_PATH%\_deps\libsdptransform-build\RelWithDebInfo\sdptransform.pdb" "%PACKAGE_FOLDER_PATH%\lib\sdptransform.pdb" /yf

:skip_copy

echo "### 7z-ing..."

set PACKAGE_FILE=libmediasoupclient-%GIT_TAG%-win-x64.7z
%Z7_PATH%\7z.exe a %PACKAGE_FILE% %PACKAGE_FOLDER_NAME%

:end

cd %ORIGINAL_WORK_DIR%
