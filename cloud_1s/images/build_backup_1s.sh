#!/bin/bash

WD="backup_1s"
IMAGE_NAME="backup_1s"
IMAGE_TAG="$1"
basic_image="basic_1s:${2:-1}"


if [ -z "$IMAGE_TAG" ] ; then
    echo "Usage:"
    echo "  $0 <IMAGE_TAG> [PARENT_TAG]"
    echo "Example:"
    echo "  $0 1"
    echo "  $0 1 1"
    echo
    exit 1
fi


docker build -t "$IMAGE_NAME:$IMAGE_TAG"  \
    --build-arg WD="$WD" \
    --build-arg IMAGE_PARENT="$basic_image" \
    --build-arg IMAGE_NAME="$IMAGE_NAME" \
    --build-arg IMAGE_TAG="$IMAGE_TAG" \
    -f "$WD/Dockerfile" \
    . \
&& \
docker save "$IMAGE_NAME:$IMAGE_TAG" -o ../images_backup/"${IMAGE_NAME}:${IMAGE_TAG}:$(date '+%y%m%d%H%M%S')".tar

