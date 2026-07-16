@echo off

REM MSVC toolset below = installed version on this host (was 14.36.32532, not present); used by lib.exe combine.
set MSVC_TOOL_PATH="C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64"
set Z7_PATH="C:\Program Files\7-Zip"
set ORIGINAL_WORK_DIR=%CD%
set PATH=%ORIGINAL_WORK_DIR%\%DEPOT_TOOLS%\;%PATH%
set DEPOT_TOOLS_WIN_TOOLCHAIN=0
set CHECKOUT_FOLDER_NAME=webrtc-checkout
set CHECKOUT_FOLDER_PATH=%ORIGINAL_WORK_DIR%\%CHECKOUT_FOLDER_NAME%
set SRC_FOLDER_NAME=src
set SRC_FOLDER_PATH=%CHECKOUT_FOLDER_PATH%\%SRC_FOLDER_NAME%
set WEBRTC_BRANCH=m140
set WEBRTC_BRANCH_PATH=refs/remotes/branch-heads/7339
set BUILD_FOLDER_PATH=%SRC_FOLDER_PATH%\out\%WEBRTC_BRANCH%
REM set PACKAGE_FOLDER_NAME=webrtc-%WEBRTC_BRANCH%-windows-x64
set PACKAGE_FOLDER_NAME=webrtc_dist
set PACKAGE_FOLDER_PATH=%ORIGINAL_WORK_DIR%\%PACKAGE_FOLDER_NAME%

echo ##################################################################################
echo Only run from a separate folder which does not have a parent with a .git subfolder
echo ##################################################################################

timeout 5

set DEPOT_TOOLS=depot_tools
if exist %DEPOT_TOOLS%\ goto skip_depot_install

echo ### Download depot tools...

set DEPOT_TOOLS_URL=https://storage.googleapis.com/chrome-infra/%DEPOT_TOOLS%.zip
if exist %DEPOT_TOOLS%.zip (curl -kLO %DEPOT_TOOLS_URL% -f --retry 5 -z %DEPOT_TOOLS%.zip) else (curl -kLO %DEPOT_TOOLS_URL% -f --retry 5 -C -)

if %errorlevel% neq 0 goto end

powershell -command "Expand-Archive -Force '%~dp0%DEPOT_TOOLS%.zip' '%DEPOT_TOOLS%'"

if %errorlevel% neq 0 goto end

:skip_depot_install

if exist %CHECKOUT_FOLDER_NAME%\ goto skip_webrtc_checkout 

echo ### Webrtc checkout...

mkdir %CHECKOUT_FOLDER_NAME%
cd %CHECKOUT_FOLDER_NAME%
call fetch --nohooks webrtc
call gclient sync

if %errorlevel% neq 0 goto end

cd %SRC_FOLDER_PATH%

call git checkout -b %WEBRTC_BRANCH% %WEBRTC_BRANCH_PATH%
call gclient sync -D

:skip_webrtc_checkout

cd %SRC_FOLDER_PATH%

if exist %BUILD_FOLDER_PATH%\ goto skip_webrtc_build 

echo ### Webrtc building...

REM VERIFY @ M140: confirm gn still accepts every arg below (e.g. enable_iterator_debugging) at branch-heads/7339.
call gn gen out\%WEBRTC_BRANCH% --args="is_debug=false is_component_build=false is_clang=true rtc_include_tests=true use_rtti=true rtc_build_examples=false use_custom_libcxx=false enable_iterator_debugging=false libcxx_is_shared=false rtc_build_tools=false use_lld=false treat_warnings_as_errors=false  use_custom_libcxx_for_host=false target_os=\"win\" target_cpu=\"x64\""
if %errorlevel% neq 0 goto end

REM M140: build only the libs we package (deps pulled in automatically). Avoids compiling unneeded
REM test code such as net_test_helpers, which fails under the newer MSVC STL (missing transitive <memory>).
call ninja -j6 -C out\%WEBRTC_BRANCH% obj/webrtc.lib obj/api/video_codecs/builtin_video_encoder_factory.lib obj/api/video_codecs/builtin_video_decoder_factory.lib obj/media/rtc_internal_video_codecs.lib obj/media/rtc_simulcast_encoder_adapter.lib
if %errorlevel% neq 0 goto end

:skip_webrtc_build

cd %ORIGINAL_WORK_DIR%

if exist %PACKAGE_FOLDER_PATH%\ goto skip_copying 

echo ### Copying package files...

del /f excluded.txt
echo \.git\ >> excluded.txt
echo \third_party\depot_tools\ >> excluded.txt

mkdir %PACKAGE_FOLDER_PATH%
xcopy "%SRC_FOLDER_PATH%\*.h" "%PACKAGE_FOLDER_PATH%" /sy /exclude:excluded.txt
REM M140: abseil/webrtc headers also #include non-.h files (.inc etc.); ship them or downstream compiles fail (C1083).
xcopy "%SRC_FOLDER_PATH%\*.inc" "%PACKAGE_FOLDER_PATH%" /sy /exclude:excluded.txt
xcopy "%SRC_FOLDER_PATH%\*.hpp" "%PACKAGE_FOLDER_PATH%" /sy /exclude:excluded.txt
xcopy "%SRC_FOLDER_PATH%\*.ipp" "%PACKAGE_FOLDER_PATH%" /sy /exclude:excluded.txt
xcopy "%SRC_FOLDER_PATH%\*.def" "%PACKAGE_FOLDER_PATH%" /sy /exclude:excluded.txt

REM VERIFY @ M140: these 12 test .cc paths must still exist and stay in sync with CMake webrtc-test_SOURCES.
echo f | xcopy "%SRC_FOLDER_PATH%\api\test\create_frame_generator.cc" "%PACKAGE_FOLDER_PATH%\api\test\create_frame_generator.cc" /yf
echo f | xcopy "%SRC_FOLDER_PATH%\media\base\fake_frame_source.cc" "%PACKAGE_FOLDER_PATH%\media\base\fake_frame_source.cc" /yf
echo f | xcopy "%SRC_FOLDER_PATH%\pc\test\fake_audio_capture_module.cc" "%PACKAGE_FOLDER_PATH%\pc\test\fake_audio_capture_module.cc" /yf
echo f | xcopy "%SRC_FOLDER_PATH%\rtc_base\task_queue_for_test.cc" "%PACKAGE_FOLDER_PATH%\rtc_base\task_queue_for_test.cc" /yf
echo f | xcopy "%SRC_FOLDER_PATH%\test\frame_generator.cc" "%PACKAGE_FOLDER_PATH%\test\frame_generator.cc" /yf
echo f | xcopy "%SRC_FOLDER_PATH%\test\frame_generator_capturer.cc" "%PACKAGE_FOLDER_PATH%\test\frame_generator_capturer.cc" /yf
echo f | xcopy "%SRC_FOLDER_PATH%\test\frame_utils.cc" "%PACKAGE_FOLDER_PATH%\test\frame_utils.cc" /yf
echo f | xcopy "%SRC_FOLDER_PATH%\test\test_video_capturer.cc" "%PACKAGE_FOLDER_PATH%\test\test_video_capturer.cc" /yf
echo f | xcopy "%SRC_FOLDER_PATH%\test\testsupport\file_utils.cc" "%PACKAGE_FOLDER_PATH%\test\testsupport\file_utils.cc" /yf
echo f | xcopy "%SRC_FOLDER_PATH%\test\testsupport\file_utils_override.cc" "%PACKAGE_FOLDER_PATH%\test\testsupport\file_utils_override.cc" /yf
echo f | xcopy "%SRC_FOLDER_PATH%\test\testsupport\ivf_video_frame_generator.cc" "%PACKAGE_FOLDER_PATH%\test\testsupport\ivf_video_frame_generator.cc" /yf
echo f | xcopy "%SRC_FOLDER_PATH%\test\vcm_capturer.cc" "%PACKAGE_FOLDER_PATH%\test\vcm_capturer.cc" /yf

REM VERIFY @ M140: these obj\*.lib targets must exist (GN targets drift between milestones).
REM field_trials + rtc_software_fallback_wrappers added for M140/libmediasoupclient 3.5.0 (link deps).
%MSVC_TOOL_PATH%\lib.exe /out:"%PACKAGE_FOLDER_PATH%\webrtc.lib" ^
  "%BUILD_FOLDER_PATH%\obj\webrtc.lib" ^
  "%BUILD_FOLDER_PATH%\obj\api\video_codecs\builtin_video_encoder_factory.lib" ^
  "%BUILD_FOLDER_PATH%\obj\api\video_codecs\builtin_video_decoder_factory.lib" ^
  "%BUILD_FOLDER_PATH%\obj\media\rtc_internal_video_codecs.lib" ^
  "%BUILD_FOLDER_PATH%\obj\media\rtc_simulcast_encoder_adapter.lib" ^
  "%BUILD_FOLDER_PATH%\obj\api\field_trials.lib" ^
  "%BUILD_FOLDER_PATH%\obj\api\video_codecs\rtc_software_fallback_wrappers.lib"

:skip_copying

cd %ORIGINAL_WORK_DIR%

echo ### 7z-ing...

set PACKAGE_FILE=webrtc-%WEBRTC_BRANCH%-win-x64.7z
%Z7_PATH%\7z.exe a %PACKAGE_FILE% %PACKAGE_FOLDER_NAME%

:end

cd %ORIGINAL_WORK_DIR%