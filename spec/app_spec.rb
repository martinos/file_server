# spec/app_spec.rb
require_relative "./spec_helper"

ENV["PUBLIC_DIR"] = "tmp"
RSpec.describe "File Management API", type: :request do
  before :each do
    @tmp_dir = "tmp"
    FileUtils.rm_rf(@tmp_dir)
    FileUtils.mkdir_p(@tmp_dir)
  end

  describe "POST /files/" do
    context "when uploading a file" do
      let(:tempfile) { Tempfile.new("test") }
      let(:filename) { "test.txt" }

      before do
        tempfile.write("Hello World")
        tempfile.rewind
      end

      after do
        tempfile.close
        tempfile.unlink
      end

      it "uploads a file successfully" do
        post "/files/", "file" => Rack::Test::UploadedFile.new(tempfile.path, "text/plain"), "filename" => filename
        expect(last_response.status).to eq(200)
        expect(JSON.parse(last_response.body)["url"]).to include(filename)
      end
    end
  end

  describe "GET /files/:sha1/:filename" do
    let(:sha1) { "1ba095dc345e2fdee0cea689a680e8dd8cebddbb" }
    let(:filename) { "coco.csv" }

    it "retrieves the file successfully" do
      get "/files/#{sha1}/#{filename}"
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include("File content")
    end

    it "returns an error for non-existing file" do
      get "/files/#{sha1}/non_existing_file.txt"
      expect(last_response.status).to eq(404)
      expect(JSON.parse(last_response.body)["error"]).to eq("File not found")
    end
  end
end