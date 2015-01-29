require 'json'
require 'uri'
require 'bundler'
require 'fog'
require 'aws/s3'

# Monkey-patch AWS gem to work with RiakCS
module AWS
  module S3
    class Authentication
      class CanonicalString < String
        def initialize(request, options = {})
          super()
          @request = request
          @headers = {}
          @options = options
          # "For non-authenticated or anonymous requests. A NotImplemented error result code will be returned if
          # an authenticated (signed) request specifies a Host: header other than 's3.amazonaws.com'"
          # (from http://docs.amazonwebservices.com/AmazonS3/2006-03-01/VirtualHosting.html)
          # request['Host'] = DEFAULT_HOST # <<< Here's the monkey patch, this incorrectly overrides a custom host passed in options from attachment fu
          build
        end
      end
    end
  end
end

Bundler.require

Excon.defaults[:ssl_verify_peer] = false
class ServiceUnavailableError < StandardError;
end

after do
  headers['Services-Nyet-App'] = 'true'
  headers['App-Signature'] = ENV.fetch('APP_SIGNATURE', "")
end

get '/env' do
  ENV['VCAP_SERVICES']
end

get '/rack/env' do
  ENV['RACK_ENV']
end

get '/timeout/:time_in_sec' do
  t = params['time_in_sec'].to_f
  sleep t
  "waited #{t} sec, should have timed out but maybe your environment has a longer timeout"
end

error ServiceUnavailableError do
  status 503
  headers['Retry-After'] = '5'
  body env['sinatra.error'].message
end

error do
  <<-ERROR
Error: #{env['sinatra.error']}

Backtrace: #{env['sinatra.error'].backtrace.join("\n")}
  ERROR
end

# Using fog client

get '/service/blobstore/fogclient/test/:service_name' do
  random = Random.rand(1..9999999).to_s
  key = "smoke_test_key_#{random}"
  value = "smoke_test_value_#{random}"
  results = {}
  results[:create] = do_create(key, value)
  results[:read] = do_read(key)
  unless results[:create] == results[:read]
    raise "Value read was not the same as value created: #{results.inspect}"
  end
  results[:delete] = do_delete(key)
  results.to_s
end

post '/service/blobstore/fogclient/:service_name/:key' do
  key = params['key']
  value = request.env["rack.input"].read
  do_create(key, value)
end

get '/service/blobstore/fogclient/:service_name/:key' do
  do_read
end

delete '/service/blobstore/fogclient/:service_name' do
  do_delete
end

# Using aws-s3 client

get '/service/blobstore/awss3client/test/:service_name' do
  random = Random.rand(1..9999999).to_s
  value = "smoke_test_value_#{random}"
  tmpfile = Tempfile.new('dummy-attachment.txt')
  tmpfile << value
  tmpfile.close
  key = "smoke_test_key#{tmpfile.path}"

  raise "unable to create tempfile" unless key


  uri = URI(service.fetch('uri'))
  access_key = service.fetch('access_key_id')
  secret = service.fetch('secret_access_key')

  aws_s3_options = {
      server: uri.host,
      port: uri.port,
      access_key_id: access_key,
      secret_access_key: secret,
      use_ssl: ('https' == uri.scheme),
      persistent: false
  }

  AWS::S3::Base.establish_connection!(aws_s3_options)

  AWS::S3::S3Object.store(
      key,
      File.open(tmpfile.path),
      bucket_name,
      :content_type => 'text/plain',
  )

  read_value = AWS::S3::S3Object.find(key, bucket_name).value
  unless read_value == value
    raise "Value read was not the same as value created: #{read_value}, #{value}"
  end

  AWS::S3::S3Object.delete key, bucket_name

  "successful test for setting #{key} to #{value}"
end


private

def do_create(key, value)
  bucket = client.directories.get(bucket_name)

  bucket.files.create(
  key: key,
  body: value,
  public: true
  )

  value
end

def do_read(key = nil)
  key ||= params.fetch('key')
  bucket = client.directories.get(bucket_name)
  bucket.files.get(key).body
end

def do_delete(key = nil)
  key ||= params.fetch('key')
  file = client.directories.get(bucket_name).files.get(key)
  file.destroy
  "successfully_deleted #{file.to_s}"
end

def service_name
  params.fetch('service_name')
end

def bucket_name
  return @bucket_name if @bucket_name
  uri = URI(service.fetch('uri'))
  @bucket_name = uri.path.chomp("/").reverse.chomp("/").reverse
end

def service
  return @service if @service
  services = JSON.parse(ENV.fetch('VCAP_SERVICES'))
  services.values.each do |v|
    v.each do |s|
      if s["name"] == service_name
        return @service = s["credentials"]
      end
    end
  end
  raise "service with name #{service_name} not found in bound services"
end

def client
  return @client if @client
  uri = URI(service.fetch('uri'))
  access_key = service.fetch('access_key_id')
  secret = service.fetch('secret_access_key')

  fog_options = {
      provider: 'AWS',
      path_style: true,
      host: uri.host,
      port: uri.port,
      scheme: uri.scheme,
      aws_access_key_id: access_key,
      aws_secret_access_key: secret
  }

  @client = Fog::Storage.new(fog_options)
end
