access_key_id = ENV.fetch('AWS_ACCESS_KEY_ID', 'minioadmin')
secret_access_key = ENV.fetch('AWS_SECRET_ACCESS_KEY', 'minioadmin')
bucket_name = ENV.fetch('S3_BUCKET_NAME', 'glowfic-dev')
config = {
  region: 'us-east-1',
  credentials: Aws::Credentials.new(access_key_id, secret_access_key),
}

if ENV.key?('MINIO_ENDPOINT')
  config[:endpoint] = ENV['MINIO_ENDPOINT']
  config[:force_path_style] = true
  Aws.config.update(config)

  client = Aws::S3::Client.new
  begin
    client.head_bucket(bucket: bucket_name)
  rescue StandardError => e
    puts "creating bucket #{bucket_name}..."
    public_read_policy = {
      Version: "2012-10-17",
      Statement: [{
        Effect: "Allow",
        Principal: "*",
        Action: "s3:GetObject",
        Resource: "arn:aws:s3:::#{bucket_name}/*"
      }]
    }.to_json

    client.create_bucket(bucket: bucket_name)
    client.put_bucket_policy(bucket: bucket_name, policy: public_read_policy)
  end
else
  Aws.config.update(config)
end

S3_BUCKET = Aws::S3::Resource.new.bucket(bucket_name)

Aws::Rails.add_action_mailer_delivery_method(:aws_ses)
