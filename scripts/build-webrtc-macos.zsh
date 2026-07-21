#!/bin/zsh

# 1. Put the script to an empty folder
# 2. ./build-webrtc-macos.zsh --architecture=arm64
# 3. ./build-webrtc-macos.zsh --architecture=x86_64

install_depot_tools() {
    # mkdir depot_tools
    # cd depot_tools
    # git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
    # export PATH=$PWD:$PATH
    # cd ..

    # Check if the folder exists
    if [ -d "depot_tools" ]
    then
        echo "### The 'depot_tools' folder exists. Please delete it or install 'depot_tools' manually and add to the PATH, then start the script again."
        exit 1
    fi
    # Clone
    echo "### git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git"
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git depot_tools
    # Check if failed
    if [ $? -ne 0 ]
    then
        echo "### Could not install 'depot_tools'. Please install it manually and add to the PATH, then start the script again."
        exit 1
    fi
    # Add to PATH
    export PATH=${PWD}/depot_tools:$PATH
}

download_webrtc() {
    # mkdir webrtc
    # cd webrtc
    # fetch --nohooks webrtc
    # gclient sync
    # cd src
    # git checkout -b m140 refs/remotes/branch-heads/7339
    # gclient sync

    if [ -d "${SRC_PARENT_FOLDER}" ]
    then
        echo "### The sources will not be downloaded because '${SRC_PARENT_FOLDER}' exists. Remove it manually if you want to re-download the sources!"
        if [ ! -d "${GIT_FOLDER}" ]
        then
            echo "### '${GIT_FOLDER}' does not exist. The sources are broken. Remove '${SRC_PARENT_FOLDER}' and restart the script."
            exit 1
        fi
        return
    fi

    # Create the source parent folder
    mkdir "${SRC_PARENT_FOLDER}"
    cd "${SRC_PARENT_FOLDER}"

    # Fetch the source code
    echo "### fetch --nohooks webrtc"
    fetch --nohooks webrtc
    if [ $? -ne 0 ]
    then
        echo "### Could not fetch the webrtc source code."
        cd "${INITIAL_WORKING_FOLDER}"
        exit 1
    fi

    # Check if the source folder name is correct and the folder exists
    if [ ! -d "${GIT_FOLDER}" ]
    then
        echo "### The source folder '${GIT_FOLDER}' could not be found. Probably the 'fetch' command failed. Please check manually"
        cd "${INITIAL_WORKING_FOLDER}"
        exit 1
    fi

    # Sync
    echo "### gclient sync"
    gclient sync
    if [ $? -ne 0 ]
    then
        echo "Could not sync the webrtc source code."
        cd "${INITIAL_WORKING_FOLDER}"
        exit 1
    fi

    # Get the appropriate version
    cd "${GIT_FOLDER}"
    echo "### git checkout -b ${GIT_BRANCH_NAME} ${GIT_REFS}"
    git checkout -b ${VERSION_NAME} ${GIT_REFS}
    if [ $? -ne 0 ]
    then
        echo "### Could not checkout the appropriate webrtc version."
        cd "${INITIAL_WORKING_FOLDER}"
        exit 1
    fi

    # Sync
    echo "### gclient sync -D"
    gclient sync -D
    if [ $? -ne 0 ]
    then
        echo "### Could not sync the webrtc source code."
        cd "${INITIAL_WORKING_FOLDER}"
        exit 1
    fi
}

build_webrtc() {
    # cd src
    # gn gen out/m94-arm64 --args='target_os="mac" target_cpu="arm64" mac_deployment_target="11.0" mac_min_system_version="11.0" mac_sdk_min="11.0" is_debug=false is_component_build=false is_clang=true rtc_include_tests=true use_rtti=true use_custom_libcxx=false treat_warnings_as_errors=false' --ide=xcode
    # ninja -C out/m94-arm64
    # gn gen out/m94-x86_64 --args='target_os="mac" target_cpu="x64" mac_deployment_target="11.0" mac_min_system_version="11.0" mac_sdk_min="11.0" is_debug=false is_component_build=false is_clang=true rtc_include_tests=true use_rtti=true use_custom_libcxx=false treat_warnings_as_errors=false' --ide=xcode
    # ninja -C out/m94-x86_64

    # Prepare build parameters
    case "${ARCHITECTURE}" in
        arm64)    
            PARAMS="target_os=\"mac\" target_cpu=\"arm64\" mac_deployment_target=\"11.0\" mac_min_system_version=\"11.0\" mac_sdk_min=\"11.0\""
            ;;
        x86_64)
            PARAMS="target_os=\"mac\" target_cpu=\"x64\" mac_deployment_target=\"11.0\" mac_min_system_version=\"11.0\" mac_sdk_min=\"11.0\""
            ;;
        *)
            echo "Unknown architecture! Only 'arm64' or 'x86_64' is supported."
            exit 1
            ;;
    esac

    cd "${GIT_FOLDER}"

    # Check if the folder exists
    if [ -d "${BUILD_FOLDER_REL}" ]
    then
        echo "### The build folder '${BUILD_FOLDER}' exits. It will not be reconfigured. Remove it manually if you want to configure it from scratch."
    else
        # Configure
        echo "### gn gen ${BUILD_FOLDER_REL} ..."
        gn gen ${BUILD_FOLDER_REL} --args="${PARAMS} is_debug=false is_component_build=false is_clang=true rtc_include_tests=true use_rtti=true use_custom_libcxx=false treat_warnings_as_errors=false" --ide=xcode
        if [ $? -ne 0 ]
        then
            echo "### Could not configure to build for ${ARCHITECTURE}"
            cd "${INITIAL_WORKING_FOLDER}"
            exit 1
        fi    
    fi

    # Build
    echo "### ninja -C ${BUILD_FOLDER_REL} ..."
    ninja -C ${BUILD_FOLDER_REL}
    if [ $? -ne 0 ]
    then
        echo "### Could not build for ${ARCHITECTURE}"
        cd "${INITIAL_WORKING_FOLDER}"
        exit 1
    fi

    cd "${INITIAL_WORKING_FOLDER}"
}

package_webrtc() {
    PACKAGE_FOLDER_NAME=webrtc-${VERSION_NAME}-osx-${ARCHITECTURE}
    PACKAGE_FOLDER=${INITIAL_WORKING_FOLDER}/${PACKAGE_FOLDER_NAME}
    if [ -d "$PACKAGE_FOLDER" ]
    then
        echo "### Package folder ${PACKAGE_FOLDER} exists. Remove it manually and start the script again."
        exit 1    
    fi
    if [ -e "$PACKAGE_FOLDER.zip" ]
    then
        echo "### The package ${PACKAGE_FOLDER}.zip exists. Remove it manually and start the script again."
        exit 1    
    fi   
    echo "### Creating the package folder: ${PACKAGE_FOLDER}"

    # Create the package root folder
    mkdir -p "${PACKAGE_FOLDER}"

    # Copy libs
    echo "### Collecting object files from thin archives ..."
    THIN_LIBS=(
        "${BUILD_FOLDER}/obj/api/video_codecs/libbuiltin_video_decoder_factory.a"
        "${BUILD_FOLDER}/obj/api/video_codecs/libbuiltin_video_encoder_factory.a"
        "${BUILD_FOLDER}/obj/media/librtc_internal_video_codecs.a"
        "${BUILD_FOLDER}/obj/media/librtc_simulcast_encoder_adapter.a"
        "${BUILD_FOLDER}/obj/api/libfield_trials.a"
        "${BUILD_FOLDER}/obj/api/video_codecs/librtc_software_fallback_wrappers.a"
    )
    EXTRA_OBJS=()
    for LIB in "${THIN_LIBS[@]}"; do
        if [ ! -f "${LIB}" ]
        then
            echo "### Missing required library: ${LIB}"
            exit 1
        fi
        LIB_OBJS=()
        while IFS= read -r OBJ; do
            [[ -n "${OBJ}" ]] && LIB_OBJS+=("${OBJ}")
        done < <(python3 "${SCRIPT_PATH%/*}/thin_archive_objs.py" "${LIB}")
        if [ ${#LIB_OBJS[@]} -eq 0 ]
        then
            EXTRA_OBJS+=("${LIB}")
        else
            EXTRA_OBJS+=("${LIB_OBJS[@]}")
        fi
    done

    echo "### Copying libraries ..."
    libtool -static -o "${PACKAGE_FOLDER}/libwebrtc.a" \
        "${BUILD_FOLDER}/obj/libwebrtc.a" \
        "${EXTRA_OBJS[@]}"

    # Copy includes
    echo "### Copying includes ..."
    cd "${GIT_FOLDER}"
    find . \( -name '*.h' -o -name '*.inc' \) -not -path "./out/*" -not -path "./third_party/depot_tools/*" | cpio -pdm "${PACKAGE_FOLDER}"

    # Copy some sources
    echo "### Copying some sources ..."
    cp "${GIT_FOLDER}/api/test/create_frame_generator.cc" "${PACKAGE_FOLDER}/api/test/create_frame_generator.cc"
    cp "${GIT_FOLDER}/media/base/fake_frame_source.cc" "${PACKAGE_FOLDER}/media/base/fake_frame_source.cc"
    cp "${GIT_FOLDER}/pc/test/fake_audio_capture_module.cc" "${PACKAGE_FOLDER}/pc/test/fake_audio_capture_module.cc"
    cp "${GIT_FOLDER}/rtc_base/task_queue_for_test.cc" "${PACKAGE_FOLDER}/rtc_base/task_queue_for_test.cc"
    cp "${GIT_FOLDER}/test/frame_generator.cc" "${PACKAGE_FOLDER}/test/frame_generator.cc"
    cp "${GIT_FOLDER}/test/frame_generator_capturer.cc" "${PACKAGE_FOLDER}/test/frame_generator_capturer.cc"
    cp "${GIT_FOLDER}/test/frame_utils.cc" "${PACKAGE_FOLDER}/test/frame_utils.cc"
    cp "${GIT_FOLDER}/test/test_video_capturer.cc" "${PACKAGE_FOLDER}/test/test_video_capturer.cc"
    cp "${GIT_FOLDER}/test/testsupport/file_utils.cc" "${PACKAGE_FOLDER}/test/testsupport/file_utils.cc"
    cp "${GIT_FOLDER}/test/testsupport/file_utils_override.cc" "${PACKAGE_FOLDER}/test/testsupport/file_utils_override.cc"
    cp "${GIT_FOLDER}/test/testsupport/ivf_video_frame_generator.cc" "${PACKAGE_FOLDER}/test/testsupport/ivf_video_frame_generator.cc"
    cp "${GIT_FOLDER}/test/vcm_capturer.cc" "${PACKAGE_FOLDER}/test/vcm_capturer.cc"

    # Copy the script
    cp "${SCRIPT_PATH}" "${PACKAGE_FOLDER}"
    
    cd ${INITIAL_WORKING_FOLDER}

    # Zip everything
    echo "### Compressing ..."
    zip --quiet --recurse-paths ${PACKAGE_FOLDER_NAME}.zip ${PACKAGE_FOLDER_NAME}

    # SHA256
    shasum -a 256 ${PACKAGE_FOLDER_NAME}.zip | tr '/a-z/' '/A-Z/'
}

ARCHITECTURE=$(uname -m)

while [ $# -gt 0 ]; do
    case "$1" in
        --architecture=*)
            ARCHITECTURE="${1#*=}"
            ;;
        *)
            echo "Error: Invalid command line parameter. Please use --architecture=\"arm64\" or --architecture=\"x86_64\"."
            exit 1
    esac
    shift
done

INITIAL_WORKING_FOLDER=${PWD}
SCRIPT_PATH=$(realpath $0)
SRC_PARENT_FOLDER_NAME=webrtc-checkout
SRC_PARENT_FOLDER=${PWD}/${SRC_PARENT_FOLDER_NAME}
GIT_FOLDER_NAME=src
GIT_FOLDER=${SRC_PARENT_FOLDER}/${GIT_FOLDER_NAME}
GIT_REFS=refs/remotes/branch-heads/7339
VERSION_NAME=m140
BUILD_FOLDER_NAME=${VERSION_NAME}-${ARCHITECTURE}
BUILD_FOLDER_REL=out/${BUILD_FOLDER_NAME}
BUILD_FOLDER=${GIT_FOLDER}/${BUILD_FOLDER_REL}

# Check if git is available
if ! command -v git &> /dev/null
then
    echo "'git' could not be found. Please install 'git' and start the script again."
    exit 1
fi

# Check if depot_tools are available
if ! command -v gclient &> /dev/null
then
    # Check the subfolder
    export PATH=${PWD}/depot_tools:$PATH
    if ! command -v gclient &> /dev/null
    then
        echo "Could not find 'depot_tools'. Installing..."
        install_depot_tools
    fi
fi

# Downlaod the source code if it is necessary
download_webrtc

# Build 
build_webrtc

# Package
package_webrtc