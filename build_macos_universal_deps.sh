SDL_VERSION="release-2.0.18"
SDL_MIXER_VERSION="64120a41f62310a8be9bb97116e15a95a892e39d"
FFMPEG_VERSION="3.4.9"

SCRIPT_PATH="${BASH_SOURCE[0]}"
PYTHON=python3

# follow any symbolic links
if [ -h "${SCRIPT_PATH}" ]; then
    while [ -h "${SCRIPT_PATH}" ]; do
        SCRIPT_PATH=$(readlink "${SCRIPT_PATH}")
    done
fi

SCRIPT_PATH=$(python3 -c "import os; print(os.path.realpath(os.path.dirname('$SCRIPT_PATH')))")

echo "-- Clean previous build (if any) and create build folder structure"
rm -rf deps_build
mkdir deps_build
# mkdir deps_build/frameworks
mkdir deps_build/dylib
mkdir deps_build/includes

echo "-- Entering build folder"
pushd deps_build

echo "-- Download and unpack needed files"
curl -L -O "https://github.com/libsdl-org/SDL/archive/refs/tags/${SDL_VERSION}.tar.gz"
# curl -L -O "https://github.com/libsdl-org/SDL_mixer/archive/${SDL_MIXER_VERSION}.tar.gz"
curl -L -O "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.gz"

tar -xvf "${SDL_VERSION}.tar.gz"
mv "SDL-${SDL_VERSION}" "SDL"

#tar -xvf "${SDL_MIXER_VERSION}.tar.gz"
#mv "SDL_mixer-${SDL_MIXER_VERSION}" "SDL_mixer"

tar -xvf "ffmpeg-${FFMPEG_VERSION}.tar.gz"
cp -r "ffmpeg-${FFMPEG_VERSION}" "ffmpeg_x86_64"
mv "ffmpeg-${FFMPEG_VERSION}" "ffmpeg_arm64"

echo "-- Build SDL2 (Universal)"
pushd "SDL"
xcodebuild ONLY_ACTIVE_ARCH=NO -project Xcode/SDL/SDL.xcodeproj -target "Shared Library" -configuration Release
popd

echo "-- Copy SDL2.framework to deps_build/frameworks"
cp -r SDL/Xcode/SDL/build/Release/libSDL2.dylib dylib

#echo "-- Build SDL2_mixer (Universal)"
#pushd "SDL_mixer"
#xcodebuild ONLY_ACTIVE_ARCH=NO \
#        "HEADER_SEARCH_PATHS=\$HEADER_SEARCH_PATHS ${SCRIPT_PATH}/sdl2_build/SDL/Xcode/SDL/build/Release/SDL2.framework/Headers" \
#        "FRAMEWORK_SEARCH_PATHS=\$FRAMEWORK_SEARCH_PATHS ${SCRIPT_PATH}/sdl2_build/SDL/Xcode/SDL/build/Release" \
#        -project Xcode/SDL_mixer.xcodeproj -target Framework -configuration Release
#popd

#echo "-- Copy SDL2_mixer.framework to deps_build/frameworks"
#cp -r SDL_mixer/Xcode/build/Release/SDL2_mixer.framework frameworks

echo "-- Build ffmpeg (x86_64)"
pushd ffmpeg_x86_64
./configure --cc=/usr/bin/clang\
            --arch=x86_64\
            --target-os=darwin\
            --enable-cross-compile\
            --extra-cflags="-arch x86_64 -fno-stack-check"\
            --extra-cxxflags="-arch x86_64"\
            --extra-objcflags="-arch x86_64"\
            --extra-ldflags="-arch x86_64"\
            --disable-x86asm\
            --enable-shared\
            --disable-static\
            --disable-debug\
            --disable-programs\
            --disable-doc
make
popd


echo "-- Build ffmpeg (arm64)"
pushd ffmpeg_arm64
./configure --cc=/usr/bin/clang\
            --arch=arm64\
            --target-os=darwin\
            --enable-cross-compile\
            --extra-cflags="-arch arm64 -fno-stack-check"\
            --extra-cxxflags="-arch arm64"\
            --extra-objcflags="-arch arm64"\
            --extra-ldflags="-arch arm64"\
            --enable-shared\
            --disable-static\
            --disable-debug\
            --disable-programs\
            --disable-doc
make
popd

echo "Lipo-ize ffmpeg static libs"
lipo "ffmpeg_x86_64/libavcodec/libavcodec.57.dylib" "ffmpeg_arm64/libavcodec/libavcodec.57.dylib" -create -output "dylib/libavcodec.57.dylib"
lipo "ffmpeg_x86_64/libavdevice/libavdevice.57.dylib" "ffmpeg_arm64/libavdevice/libavdevice.57.dylib" -create -output "dylib/libavdevice.57.dylib"
lipo "ffmpeg_x86_64/libavfilter/libavfilter.6.dylib" "ffmpeg_arm64/libavfilter/libavfilter.6.dylib" -create -output "dylib/libavfilter.6.dylib"
lipo "ffmpeg_x86_64/libavformat/libavformat.57.dylib" "ffmpeg_arm64/libavformat/libavformat.57.dylib" -create -output "dylib/libavformat.57.dylib"
lipo "ffmpeg_x86_64/libavutil/libavutil.55.dylib" "ffmpeg_arm64/libavutil/libavutil.55.dylib" -create -output "dylib/libavutil.55.dylib"
lipo "ffmpeg_x86_64/libswresample/libswresample.2.dylib" "ffmpeg_arm64/libswresample/libswresample.2.dylib" -create -output "dylib/libswresample.2.dylib"
lipo "ffmpeg_x86_64/libswscale/libswscale.4.dylib" "ffmpeg_arm64/libswscale/libswscale.4.dylib" -create -output "dylib/libswscale.4.dylib"
cp dylib/libavcodec.57.dylib dylib/libavcodec.dylib
cp dylib/libavdevice.57.dylib dylib/libavdevice.dylib
cp dylib/libavfilter.6.dylib dylib/libavfilter.dylib
cp dylib/libavformat.57.dylib dylib/libavformat.dylib
cp dylib/libavutil.55.dylib dylib/libavutil.dylib
cp dylib/libswresample.2.dylib dylib/libswresample.dylib
cp dylib/libswscale.4.dylib dylib/libswscale.dylib


popd


echo "-- Done !"