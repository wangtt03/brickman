#!/bin/sh

set -e

script_dir=$(dirname -f "$0")

build_dir="$1"
if [ ! -n "$build_dir" ]; then
    echo "Error: Must specify build directory"
    exit 1
fi

case $2 in
    armel|armhf)
        arch=$2
        ;;
    *)
        echo "Error: Must specify 'armel' or 'armhf'"
        exit 1
        ;;
esac

if ! which docker >/dev/null; then
    echo "Error: Docker is not installed"
    exit 1
fi

image_name="brickman-$arch"
container_name="brickman_$arch"

docker build \
    --tag $image_name \
    --no-cache \
    --file "$script_dir/$arch.dockerfile" \
    "$script_dir/"
mkdir -p $build_dir

docker rm --force $container_name >/dev/null 2>&1 || true
docker run \
    --volume "$build_dir:/build" \
    --volume "$(pwd):/src" \
    --workdir /build \
    --name $container_name \
    --env "TERM=$TERM" \
    --env "DESTDIR=/build/dist" \
    --tty \
    --detach \
    $image_name tail

docker exec --tty $container_name cmake /src -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_TOOLCHAIN_FILE=/opt/gcc-linaro-arm-linux-gnueabihf-4.8-2014.04_linux/toolchain.cmake

echo "Done. You can now compile by running 'docker exec --tty $container_name make'"
