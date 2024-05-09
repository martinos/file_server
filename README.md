# File Management API

This project provides a simple API for uploading and retrieving files using a Roda-based web server. It uses Git for versioning files, ensuring that even deleted files can still be accessed via their SHA1 hash if not pruned.

## Requirements

-   Ruby
-   Bundler
-   Git

## Installation

1. Clone the repository:

```bash
   git clone your-repository-url
```

2. Navigate to the project directory:

```bash
   cd your-project-directory
```

3. Install dependencies:

```bash
   bundle install
```

## Running the Server

To start the server, run:

```bash
bundle exec rackup
```

## Environment Variables

-   `HOSTNAME`: Sets the hostname for the server. If not specified, defaults to `localhost:3000`.

## API Usage

### Uploading a File

To upload a file:

```bash
curl -X POST -F "file=@path_to_your_file" http://$HOSTNAME/files/optional_filename_here
```

If you do not specify a filename in the URL, the original filename will be used. If the file data does not contain a filename, it defaults to `anonymous.txt`.

#### Sample Response for Uploading a File

Upon successfully uploading a file, the server will return a JSON object containing the URL to access the uploaded file. Here's an example of what this response might look like:

```json
{
    "url": "http://localhost:3000/files/1a2b3c4d5e6f7890123456789abcdef01234567/sample.txt"
}
```

This URL includes the SHA1 hash of the uploaded file and the filename, allowing you to access the file directly through the API.

### Retrieving a File

To retrieve a file:

```bash
curl http://$HOSTNAME/files/{sha1}/{filename}
```

### Piping Content to Upload

You can also pipe content directly to `curl` for uploading. Here's how to upload content from a command:

```bash
echo "Sample text data" | curl -X POST -F "file=@-" http://$HOSTNAME/files/sample.txt
```

## Sample Ruby Code to Interact with the API

Here's a simple Ruby script to upload a file using Net::HTTP:

```ruby
require 'net/http'
require 'uri'

uri = URI('http://your-hostname/files/filename.txt')
request = Net::HTTP::Post.new(uri)
request.set_form([['file', File.open('path_to_your_file')]], 'multipart/form-data')

response = Net::HTTP.start(uri.hostname, uri.port) do |http|
  http.request(request)
end

puts response.body
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

