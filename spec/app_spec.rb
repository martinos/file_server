# spec/app_spec.rb
require_relative "./spec_helper"
require "digest"
require "pry-nav"

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
        post "/files/", "file" => Rack::Test::UploadedFile.new(tempfile.path, "text/plain", false, original_filename: filename)
        expect(last_response.status).to eq(200)
        expect(last_response.body).to end_with(filename)
      end

      it "keeps the filename provided in the path even if the filename field is provided" do
        post "/files/tata.txt", "file" => Rack::Test::UploadedFile.new(tempfile.path, "text/plain", false, original_filename: filename)
        expect(last_response.status).to eq(200)
        expect(last_response.body).to end_with("tata.txt")
      end

      it "uses anonymous.txt filename if no name is provided in the path or in the filename field" do
        post "/files/", "file" => Rack::Test::UploadedFile.new(tempfile.path, "text/plain", false, original_filename: "-")
        expect(last_response.status).to eq(200)
        expect(last_response.body).to end_with("anonymous.txt")
      end

      it "retuns an error if the path is too deep" do
        post "/files/a/b/c/d/e/f/", "file" => Rack::Test::UploadedFile.new(tempfile.path, "text/plain", false, original_filename: "-")
        expect(last_response.status).to eq(400)
        expect(JSON.parse(last_response.body)["error"]).to match(/Subpath too deep./)
      end
    end
  end

  describe "GET /files/:sha1/:filename" do
    let(:sha1) { "1ba095dc345e2fdee0cea689a680e8dd8cebddbb" }
    let(:tempfile) { Tempfile.new("test") }
    let(:filename) { "test.txt" }

    before do
      tempfile.write("Hello World")
      tempfile.rewind

      post "/files/", "file" => Rack::Test::UploadedFile.new(tempfile.path, "text/plain", false, original_filename: filename)

      url = last_response.body
      @path = URI.parse(url).path
    end

    it "retrieves the file successfully" do
      get @path
      # We post then we do a get on the file
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include("Hello World")
    end

    it "returns an error non existing sha1" do
      get "/files/#{Digest::SHA1.hexdigest("abc")}/non_existing_file.txt"
      expect(last_response.status).to eq(404)
      expect(JSON.parse(last_response.body)["error"]).to eq("File not found")
    end

    it "sets the text/plain;charset=utf8 on content-type" do
      get @path
      # We post then we do a get on the file
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include("Hello World")
      headers = last_response.headers
      expect(headers["content-type"]).to eq("text/plain; charset=utf-8")
    end
  end
end
