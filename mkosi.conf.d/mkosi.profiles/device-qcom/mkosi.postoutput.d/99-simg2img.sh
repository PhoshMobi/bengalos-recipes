#!/bin/bash

set -e

IMAGE=${OUTPUTDIR}/${IMAGE_ID}_${IMAGE_VERSION}.raw

echo "Processing ${IMAGE}"

img2simg "$IMAGE" "${IMAGE%.raw}.img.tmp"
mv "${IMAGE%.raw}.img.tmp" "${IMAGE%.raw}.img"

