#!/bin/bash

WD="admin_1s"
IMAGE_NAME="admin_1s"
IMAGE_TAG="${2:-1}"
basic_image="basic_1s:${3:-1}"

file_distr="$1"
newver=$(basename "$file_distr" | sed -n 's/^server64_with_all_clients_\([0-9]\{1,\}_[0-9]\{1,\}_[0-9]\{1,\}_[0-9]\{1,\}\)\.zip$/\1/p' | tr '_' '.')      #"

if [ -z "$newver" ] || [ ! -f "$file_distr" ] ; then
    echo "Usage:"
    echo "  $0 <1S-DISTRIB-FILE> [IMAGE_TAG] [PARENT_TAG]"
    echo "Example:"
    echo "  $0 ./server64_with_all_clients_8_3_27_1989.zip"
    echo "  $0 ./server64_with_all_clients_8_3_27_1989.zip 1 1"
    echo
    exit 1
fi

VERSION_1S="$newver"
IMAGE_TAG="${newver}_${IMAGE_TAG}"


docker build -t "$IMAGE_NAME:$IMAGE_TAG"  \
    --build-arg WD="$WD" \
    --build-arg FILE_DISTR="$file_distr" \
    --build-arg IMAGE_PARENT="$basic_image" \
    --build-arg IMAGE_NAME="$IMAGE_NAME" \
    --build-arg IMAGE_TAG="$IMAGE_TAG" \
    --build-arg VERSION_1S="$VERSION_1S" \
    -f "$WD/Dockerfile" \
    . \
&& \
docker save "$IMAGE_NAME:$IMAGE_TAG" -o ../images_backup/"${IMAGE_NAME}:${IMAGE_TAG}:$(date '+%y%m%d%H%M%S')".tar

