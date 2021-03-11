RSpec.describe DeleteIconFromS3Job do
  before(:each) { ResqueSpec.reset! }

  it "deletes the given key" do
    key = 'arbitrary'
    delete_key = {delete: {objects: [{key: key}]}}
    expect(S3_BUCKET).to receive(:delete_objects).with(delete_key)
    DeleteIconFromS3Job.perform_now(key)
  end
end
