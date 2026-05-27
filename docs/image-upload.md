# Image Uploads

## Mutable images

The development images are uploaded from CI. To test the upload step you can set
the necessary variables on the command line. Make sure to push to your repos default
branch as otherwise the upload will be skipped.

## Testing the CI Upload

To test if the upload part of the CI job would pick things up correctly one can use:

```sh
git push -f -o ci.variable=PHOSH_IMAGE_UPLOAD=1 -o ci.variable="PHOSH_IMAGE_HOST=doesnotexist" -o ci.variable="PHOSH_IMAGE_BRANCH=test-upload" <your-remote> test-upload
```

## Immutable images

### Staging

The immutable images are uploaded to a S3 bucket for staging via `helpers/pack.sh`. A hash of the
metadata is created to address each build. Later CI stages can use that to hash to download
artifacts (like the qcow2 image) for testing.

- Upload via pack.sh
- Input for e.g. OpenQA
- Deleted after 3 days
- Not consumed via `systemd-sysupdate`
