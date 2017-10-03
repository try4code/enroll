require File.join(Rails.root, "app", "data_migrations", "add_family_and_household_to_person")
# This rake task is to add a family and a household to an existing person and set the person as the primary applicant and the only family member
# RAILS_ENV=production bundle exec rake migrations:add_family_and_household_to_person hbx_id="person's hbx id"
namespace :migrations do
  desc "add_family_and_household_to_person"
  AddFamilyAndHouseholdToPerson.define_task :add_family_and_household_to_person => :environment
end
