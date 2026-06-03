#!/bin/bash
set -e

IMAGE=${OUTPUTDIR}/${IMAGE_ID}_${IMAGE_VERSION}.raw

echo "Generating bmap for $IMAGE"

bmaptool create "$IMAGE" > "${IMAGE}.bmap.tmp"
mv "${IMAGE}.bmap.tmp" "${IMAGE}.bmap"

