# cf-test-app
CF-deployable app to test S3-compatible blobstore using both fog and aws-s3 gems

## Deploying
* `cf push -m 256M --no-start cf-test-app`
* `cf create-service p-riakcs developer cf-riakcs-test`
* `cf bind-service cf-test-app cf-riakcs-test`
* `cf start cf-test-app`


## Endpoints

### GET /service/blobstore/awss3client/test/:service_name
Creates, reads, and deletes a value from a file IO stream in blobstore using aws-s3 gem.  Example:

    $ curl cf-test-app.my-cloud-foundry.com/service/blobstore/awss3client/test/cf-riakcs-test

### GET /service/blobstore/fogclient/test/:service_name
Creates, reads, and deletes a value in blobstore using fog gem.  Example:

    $ curl cf-test-app.my-cloud-foundry.com/service/blobstore/fogclient/test/cf-riakcs-test
