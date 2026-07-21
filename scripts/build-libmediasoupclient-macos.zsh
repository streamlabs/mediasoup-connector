#!/bin/zsh

# 1. Precompile the webrtc library for arm64 or/and x84_64
# 2. Place the script to an empty folder
# 3. ./build-libmediasoupclient-macos.zsh --architecture=arm64 --webrtc-folder=THE_COMBINED_WEBRTC_INCLUDE_AND_LIB_FOLDER
# 4. ./build-libmediasoupclient-macos.zsh --architecture=x86_64 --webrtc-folder=THE_COMBINED_WEBRTC_INCLUDE_AND_LIB_FOLDER

download_libmediasoupclient() {
    # Check if the webrtc folder exists
    if [ -d "${GIT_FOLDER}" ]
    then
        echo "### The '${GIT_FOLDER}' folder exists. It will be reused. Remove it if you want to clone the git repositoty again."
        return
    fi

    # Clone
    git clone --recurse-submodules https://github.com/versatica/libmediasoupclient.git ${GIT_FOLDER}
    if [ $? -ne 0 ]
    then
        echo "### ould not clone libmediasoupclient."
        exit 1
    fi

    # Check if the source folder name is correct and the folder exists
    if [ ! -d "${GIT_FOLDER}" ]
    then
        echo "### The source folder '${GIT_FOLDER}' could not be found. Probably the 'git clone' command failed. Please check manually"
        exit 1
    fi

    # Checkout the necessary version
    cd "${GIT_FOLDER}"
    git checkout -b ${GIT_TAG}-build ${GIT_TAG}
    if [ $? -ne 0 ]
    then
        echo "### git checkout ${GIT_TAG} failed"
        cd "${INITIAL_WORKING_FOLDER}"
        exit 1
    fi
}

build_libmediasoupclient() {
    cd "${GIT_FOLDER}"

    # Prepare build parameters
    case "${ARCHITECTURE}" in
        arm64)
            MIN_MACOS_VERSION=11.0
            ;;
        x86_64)
            MIN_MACOS_VERSION=11.0
            ;;
        *)
            echo "### Unknown architecture! Only 'arm64' or 'x86_64' is supported."
            exit 1
            ;;
    esac

    # Check if the build folder exists
    if [ -d "${BUILD_FOLDER}" ]
    then
        echo "### The '${BUILD_FOLDER}' folder exists. Configuring will be skiped. Remove the folder if you want to configure from scratch."
    else
        cmake . -B"${BUILD_FOLDER}" -DLIBWEBRTC_INCLUDE_PATH="${WEBRTC_FOLDER}" -DLIBWEBRTC_BINARY_PATH="${WEBRTC_FOLDER}" -DCMAKE_OSX_ARCHITECTURES="${ARCHITECTURE}" -DCMAKE_OSX_DEPLOYMENT_TARGET=${MIN_MACOS_VERSION} -DCMAKE_POLICY_VERSION_MINIMUM=3.5
        if [ $? -ne 0 ]
        then
            echo "### Could not configure to build for ${ARCHITECTURE}"
            cd "${INITIAL_WORKING_FOLDER}"
            exit 1
        fi
    fi

    cmake --build ${BUILD_FOLDER} --config RelWithDebInfo
    if [ $? -ne 0 ]
    then
        echo "### Build failed for ${ARCHITECTURE}"
        cd "${INITIAL_WORKING_FOLDER}"
        exit 1
    fi    
}

package_libmediasoupclient() {
    PACKAGE_FOLDER_NAME=libmediasoupclient-${GIT_TAG}-osx-${ARCHITECTURE}
    PACKAGE_FOLDER=${INITIAL_WORKING_FOLDER}/${PACKAGE_FOLDER_NAME}

    if [ -d "${PACKAGE_FOLDER}" ]; then
        echo "### Package folder ${PACKAGE_FOLDER} exists. Plrease remove it manually and start the script again."
        exit 1    
    fi

    # Create the folder
    echo "### Creating the package folder: ${PACKAGE_FOLDER}"
    mkdir -p "${PACKAGE_FOLDER}/include/mediasoupclient"
    mkdir -p "${PACKAGE_FOLDER}/include/sdptransform"
    mkdir -p "${PACKAGE_FOLDER}/lib"
    
    # Copy libs
    echo "### Copying libraries ..."
    cp "${BUILD_FOLDER}/libmediasoupclient.a" "${PACKAGE_FOLDER}/lib"
    cp "${BUILD_FOLDER}/_deps/libsdptransform-build/libsdptransform.a" "${PACKAGE_FOLDER}/lib"

    # Copy includes    
    echo "### Copying includes ..."
    cp -R "${GIT_FOLDER}/include/." "${PACKAGE_FOLDER}/include/mediasoupclient"
    cp -R "${BUILD_FOLDER}/_deps/libsdptransform-src/include/." "${PACKAGE_FOLDER}/include/sdptransform"

    # Copy the script
    cp "${SCRIPT_PATH}" "${PACKAGE_FOLDER}"

    cd ${INITIAL_WORKING_FOLDER}

    # Zip everything
    echo "### Compressing ..."
    zip --quiet --recurse-paths ${PACKAGE_FOLDER_NAME}.zip ${PACKAGE_FOLDER_NAME}

    # SHA256
    shasum -a 256 ${PACKAGE_FOLDER_NAME}.zip | tr '/a-z/' '/A-Z/'
}

# SCRIPT START

ARCHITECTURE=$(uname -m)

while [ $# -gt 0 ]; do
    case "$1" in
        --architecture=*)
            ARCHITECTURE="${1#*=}"
            ;;
        --webrtc-folder=*)
            WEBRTC_FOLDER="${1#*=}"
            ;;
        *)
            echo "### Error: Invalid command line parameter. Please use --architecture=arm64|x86_64 --webrtc-folder=..."
            exit 1
    esac
    shift
done

if [ -z "${WEBRTC_FOLDER}" ]; then
    echo "### The webrtc include folder is not set. Please specify --webrtc-folder=..."
    exit 1
fi

INITIAL_WORKING_FOLDER=${PWD}
SCRIPT_PATH=$(realpath $0)
GIT_FOLDER_NAME=libmediasoupclient
GIT_FOLDER=${PWD}/${GIT_FOLDER_NAME}
BUILD_FOLDER_NAME=build-${ARCHITECTURE}
BUILD_FOLDER=${GIT_FOLDER}/${BUILD_FOLDER_NAME}
GIT_TAG=3.5.0

# Check if git is available
if ! command -v git &> /dev/null
then
    echo "'git' could not be found. Please install 'git' and start the script again."
    exit 1
fi

# Download the sources
download_libmediasoupclient

# Build
build_libmediasoupclient

# Package
package_libmediasoupclient
