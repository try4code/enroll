require File.join(Rails.root, "app", "data_migrations", "change_applicant_of_enrollment_member")
# This rake task is to change the applicant of an enrollment member
# RAILS_ENV=production bundle exec rake migrations:change_applicant_of_enrollment_member enrollment_hbx_id="123123" enrolllment_member_id="123123123" new_applicant_id="123123213"
namespace :migrations do
  desc "change applicant_of_enrollment_member"
  ChangeApplicantOfEnrollmentMember.define_task :change_applicant_of_enrollment_member => :environment
end