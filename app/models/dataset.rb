class Dataset < ActiveRecord::Base

  belongs_to :user
  has_many :dataset_files

  before_create :create_in_github

  def add_files(files_array)
    files_array.each do |file|
      dataset_files << DatasetFile.new_file(file, self)
    end
    save
    create_files
  end

  def update_files(files_array)
    files_array.each do |file|
      if file["id"]
        DatasetFile.update_file(file)
      else
        dataset_files << DatasetFile.new_file(file, self)
      end
    end
    update_datapackage
  end

  def create_contents(filename, file, folder = nil)
    user.octokit_client.create_contents(full_name, path(filename, folder), "Adding #{filename}", file, branch: "gh-pages")
  end

  def update_contents(filename, file, sha, folder = nil)
    user.octokit_client.update_contents(full_name, path(filename, folder), "Updating #{filename}", sha, file, branch: "gh-pages")
  end

  def delete_contents(filename, sha, folder = nil)
    user.octokit_client.delete_contents(full_name, path(filename, folder), "Deleting #{filename}", sha, branch: "gh-pages")
  end

  def path(filename, folder = "")
    File.join([folder,filename].reject { |n| n.blank? })
  end

  def create_files
    create_datapackage
    create_contents("index.html", File.open(File.join(Rails.root, "extra", "html", "index.html")).read)
    create_contents("_config.yml", config)
    create_contents("style.css", File.open(File.join(Rails.root, "extra", "stylesheets", "style.css")).read, "css")
    create_contents("default.html", File.open(File.join(Rails.root, "extra", "html", "default.html")).read, "_layouts")
    create_contents("resource.html", File.open(File.join(Rails.root, "extra", "html", "resource.html")).read, "_layouts")
    create_contents("data_table.html", File.open(File.join(Rails.root, "extra", "html", "data_table.html")).read, "_includes")
  end

  def create_datapackage
    response = create_contents("datapackage.json", datapackage)
    self.datapackage_sha = response[:content][:sha]
    save
  end

  def update_datapackage
    response = update_contents("datapackage.json", datapackage, datapackage_sha)
    self.datapackage_sha = response[:content][:sha]
    save
  end

  def datapackage

    datapackage = {}

    datapackage["name"] = name.downcase.parameterize
    datapackage["datapackage-version"] = ""
    datapackage["title"] = name
    datapackage["description"] = description
    datapackage["licenses"] = [{
      "url"   => license_details.url,
      "title" => license_details.title
    }]
    datapackage["publishers"] = [{
      "name"   => publisher_name,
      "web" => publisher_url
    }]

    datapackage["resources"] = []

    dataset_files.each do |file|
      datapackage["resources"] << {
        "url" => file.gh_pages_url,
        "name" => file.title,
        "mediatype" => file.mediatype,
        "description" => file.description,
        "path" => "data/#{file.filename}"
      }
    end

    datapackage.to_json
  end

  def config
    {
      "data_source" => ".",
      "update_frequency" => frequency,
    }.to_yaml
  end

  def license_details
    Odlifier::License.define(license)
  end

  def github_url
    "http://github.com/#{full_name}"
  end

  def gh_pages_url
    "http://#{user.name}.github.io/#{repo}"
  end

  def full_name
    "#{user.name}/#{repo}"
  end

  private

    def create_in_github
      repo = user.octokit_client.create_repository(name.downcase)
      self.url = repo[:html_url]
      self.repo = repo[:name]
    end

end
