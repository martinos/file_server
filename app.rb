require "roda"
require "rugged"
require "json"
require "cgi"
require "mime-types"

class App < Roda
  plugin :json
  plugin :all_verbs
  plugin :environments

  def public_dir
    @public_dir ||= ENV["PUBLIC_DIR"] || "./public"
    binding.pry
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

  def inline_content?(content_type)
    content_type.start_with?("text/") || content_type.include?("script") || content_type == "application/json"
  end

  route do |r|
    setup_public_git_repo

    r.on "files" do
      r.post /(.*)/ do |subpath|
        puts "SUBPATH= #{subpath}"
        tempfile = r.params["file"][:tempfile]
        filename = r.params["file"][:filename]
        if filename.nil? || filename == "-"
          filename = "anonymous.txt"
        end

        # Construct the full path
        full_subpath = File.join(subpath, filename)
        if subpath.empty?
          full_subpath = filename
        end

        # Prevent directory traversal and limit subpath depth
        if full_subpath.split("/").reject(&:empty?).length > 5
          response.status = 400
          { error: "Subpath too deep. Maximum of 5 levels allowed." }
        else
          destination = File.join(public_dir, full_subpath)

          unless File.expand_path(destination).start_with?(File.expand_path(public_dir))
            response.status = 403
            { error: "Access denied" }
          else
            puts destination
            FileUtils.mkdir_p(File.dirname(destination))
            FileUtils.mv(tempfile.path, destination)

            repo = Rugged::Repository.new(public_dir)
            oid = Rugged::Blob.from_workdir(repo, full_subpath)
            index = repo.index
            index.add(path: full_subpath, oid: oid, mode: 0100644)
            index.write
            commit_tree = index.write_tree(repo)
            commit_author = { email: "test@example.com", name: "Test", time: Time.now }
            Rugged::Commit.create(repo,
                                  author: commit_author,
                                  message: "Added file #{full_subpath}",
                                  parents: repo.empty? ? [] : [repo.head.target].compact,
                                  tree: commit_tree,
                                  update_ref: "HEAD")

            hostname = ENV["HOSTNAME"] || "localhost:3000"
            { url: "http://#{hostname}/files/#{oid}/#{full_subpath}" }
          end
        end
      end

      r.get %r{(\h{40})/(.+)} do |sha1, filename|
        filename = CGI.unescape(filename.gsub("%20", " "))
        path = File.join(public_dir, filename)

        begin
          repo = Rugged::Repository.new(public_dir)
          blob = repo.lookup(sha1)
          content_type = content_type_from_extension(filename)
          disposition = inline_content?(content_type) ? "inline" : "attachment; filename=\"#{File.basename(filename)}\""

          response["Content-Type"] = content_type
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
