require "roda"
require "rugged"
require "json"
require "cgi"
require "mime-types"
require "pry-nav"

class App < Roda
  plugin :json
  plugin :all_verbs
  plugin :environments

  def public_dir
    @public_dir ||= ENV["PUBLIC_DIR"] || "./public"
  end

  def setup_public_git_repo
    Dir.mkdir(public_dir) unless Dir.exist?(public_dir)
    begin
      Rugged::Repository.new(public_dir)
    rescue Rugged::RepositoryError
      Rugged::Repository.init_at(public_dir, false)
    end
  end

  def content_type_from_extension(filename)
    type = MIME::Types.type_for(filename).first
    type ? type.content_type : "text/plain"
  end

  def with_charset(content_type)
    if content_type == "text/plain"
      content_type += "; charset=utf-8"
    end
    content_type
  end

  def inline_content?(content_type)
    content_type.start_with?("text/") || content_type.include?("script") || content_type == "application/json"
  end

  route do |r|
    setup_public_git_repo
    r.on "files" do
      r.post /(.*)/ do |subpath|
        filename = r.params["file"][:filename]
        # filename is set to - when curl reads file content from stdin if filename field is not set.
        filename = "anonymous.txt" if filename.nil? || filename == "-"
        # Construct the full path
        full_subpath = if subpath.end_with?("/")
            File.join(subpath, filename)
          else
            subpath
          end

        full_subpath = filename if subpath.empty?

        # Prevent directory traversal and limit subpath depth
        if full_subpath.split("/").reject(&:empty?).length > 5
          response.status = 400
          { error: "Subpath too deep. Maximum of 5 levels allowed." }
        else
          destination = File.join(public_dir, full_subpath)

          if !File.expand_path(destination).start_with?(File.expand_path(public_dir))
            response.status = 403
            { error: "Access denied" }
          else
            tempfile = r.params["file"][:tempfile]

            repo = Rugged::Repository.bare(File.join(public_dir, ".git"))
            oid = Rugged::Blob.from_io(repo, tempfile)
            index = repo.index
            index.add(path: full_subpath, oid: oid, mode: 0o100644)
            commit_author = { email: "devs@isptelecom.net", name: "dev", time: Time.now }
            Rugged::Commit.create(repo,
                                  author: commit_author,
                                  message: "Added file #{full_subpath}",
                                  parents: repo.empty? ? [] : [repo.head.target].compact,
                                  tree: index.write_tree(repo),
                                  update_ref: "HEAD")

            hostname = ENV["HOSTNAME"] || "localhost:9292"
            "http://#{hostname}/files/#{oid}/#{full_subpath}"
          end
        end
      end

      r.get %r{(\h{40})/(.+)} do |sha1, filename|
        filename = CGI.unescape(filename.gsub("%20", " "))
        begin
          repo = Rugged::Repository.new(public_dir)
          blob = repo.lookup(sha1)
          content_type = content_type_from_extension(filename)
          disposition = inline_content?(content_type) ? "inline" : "attachment; filename=\"#{File.basename(filename)}\""

          response["Content-Type"] = with_charset(content_type)
          response["Content-Disposition"] = disposition
          response.write(blob.content)
        rescue Rugged::OdbError
          response.status = 404
          { error: "File not found" }
        end
      end
    end
  end
end
