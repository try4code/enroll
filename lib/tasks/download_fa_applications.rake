require File.join(Rails.root, "app", "data_migrations", "download_faa")

namespace :migrations do
  desc "download FAA to CSV"
  DownloadFAA.define_task :download_fa_applications => :environment
end
