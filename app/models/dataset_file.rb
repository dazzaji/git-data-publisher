class DatasetFile < ActiveRecord::Base

  belongs_to :dataset

  def self.new_file(file, dataset = nil)
    f = new(
      dataset: dataset,
      title: file["title"],
      filename: file["file"].original_filename,
      description: file["description"],
      mediatype: get_content_type(file["file"].original_filename),
    )
    f.add_to_github(file["file"])
    f
  end

  def self.update_file(file)
    f = find(file.delete("id"))
    f.update_file(file) unless f.nil?
    f
  end

  def self.get_content_type(file)
    type = MIME::Types.type_for(file).first
    [(type.use_instead || type.content_type)].flatten.first
  end

  def github_url
    "#{dataset.github_url}/data/#{filename}"
  end

  def gh_pages_url
    "#{dataset.gh_pages_url}/data/#{filename}"
  end

  def update_file(file)
    original_file = self.dup

    update_hash = {
      title: file["title"],
      filename: file["file"].nil? ? nil : file["file"].original_filename,
      description: file["description"],
      mediatype: file["file"].nil? ? nil : self.class.get_content_type(file["file"].original_filename)
    }.delete_if { |k,v| v.nil? }

    self.update(update_hash)

    if file["file"]
      update_in_github(file["file"])
      delete_from_github(original_file) unless file["file"].original_filename == original_file.filename
    end
  end

  def add_to_github(tempfile)
    response = dataset.create_contents(filename, tempfile.read.encode('UTF-8', :invalid => :replace, :undef => :replace), "data")
    self.file_sha = response[:content][:sha]
    response = dataset.create_contents("#{File.basename(filename, '.*')}.md", File.open(File.join(Rails.root, "extra", "html", "data_view.md")).read, "data")
    self.view_sha = response[:content][:sha]
    save
  end

  def update_in_github(tempfile)
    response = dataset.update_contents(filename, tempfile.read.encode('UTF-8', :invalid => :replace, :undef => :replace), file_sha, "data")
    self.file_sha = response[:content][:sha]
    response = dataset.update_contents("#{File.basename(filename, '.*')}.md", File.open(File.join(Rails.root, "extra", "html", "data_view.md")).read, view_sha, "data")
    self.view_sha = response[:content][:sha]
    save
  end

  def delete_from_github(file)
    dataset.delete_contents(file.filename, file.file_sha)
    dataset.delete_contents("#{File.basename(file.filename, '.*')}.md", file.view_sha)
  end

end
