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

#### Lifecycle policy

Staging bucket lifecycle policy is set via

```sh
aws s3api put-bucket-lifecycle-configuration --bucket bengalos-staging --lifecycle-configuration  file://helpers/staging-lifecycle.json
```

Inspect via

```sh
aws s3api get-bucket-lifecycle-configuration --bucket bengalos-staging
```

These commands need `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`,
`AWS_DEFAULT_REGION`, `AWS_ENDPOINT_URL` set in the environment.

### Publish

To bless an image and make it publically available the metadata hash is passed to `helpers/bless.sh`.
This transfers the metadata and images to public S3 bucket (`bengalos-images`).

- Contains blessed images only
- Consumed by via `systemd-sysupate`
- Currently no automatic cleanup

### Adding a new device

To add a new device:

- Add the necessary `mkosi.conf.d/mkosi.profiles/device-<device>/` configuration
- Add a `build-<device>-immutable` target to the `Makefile`
- Add flashing information in [docs/](./)
- Add a bug label to <https://salsa.debian.org/BengalOS-team/bengalos-recipes/-/labels>
- Add a build job by adding it to the `build:immutable:nightly:` matrix job in
  [.gitlab-ci.yml][gitlab-ci].

Once things build and work as expected

- Add a publish `publish:immutable:nightly:<device>:` job to [.gitlab-ci.yml][gitlab-ci].
- Add a cleanup job by adding it to the `cleanup-blessed:` matrix job in
  [.gitlab-ci.yml][gitlab-ci].
- Add the device to <https://codeberg.org/Phosh/bengalos-site>

[gitlab-ci]: ../.gitlab-ci.yml
