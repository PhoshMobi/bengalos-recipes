# Image Uploads

The development images are uploaded from CI. To test the upload step you can set
the necessary variables on the command line. Make sure to push to your repos default
branch as otherwise the upload will be skipped.

## Testing the CI Upload

To test if the upload part of the CI job would pick things up correctly one can use:

```sh
git push -f -o ci.variable=PHOSH_IMAGE_UPLOAD=1 -o ci.variable="PHOSH_IMAGE_HOST=doesnotexist" -o ci.variable="PHOSH_IMAGE_BRANCH=test-upload" <your-remote> test-upload
```
