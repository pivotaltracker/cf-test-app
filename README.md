# cf-test-app
CF-deployable app to test service interactions

## Deploying
`cf push -m 256M --no-start cf-test-app`
`cf create-service p-riakcs developer cf-riakcs-test`
`cf bind-service cf-test-app cf-riakcs-test`
`cf start cf-test-app`


### Endpoints

#### GET /crud_test

#### PUT /:key

Stores the key:value pair in the Riak CS bucket. Example:

    $ curl -X POST riaktest.my-cloud-foundry.com/service/blobstore/mybucket/foo -d 'bar'
    success


#### GET /:key

Returns the value stored in the Riak CS bucket for a specified key. Example:

    $ curl -X GET riaktest.my-cloud-foundry.com/service/blobstore/mybucket/foo
    bar

#### DELETE /:key

Deletes the bucket. Example:

    $ curl -X DELETE riaktest.my-cloud-foundry.com/service/blobstore/mybucket
    success

Once you've deleted your bucket, you should unbind and delete the service instance, as these are references in Cloud Foundry to an instance which no longer exists.

    $ cf unbind-service riaktest mybucket
    $ cf delete-service mybucket
    $ cf restart riaktest
