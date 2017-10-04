# RAILS_ENV=production bundle exec rake migrations:change_applicant_of_enrollment_member enrollment_hbx_id="123123" enrolllment_member_id="123123123" new_applicant_id="123123213"
require File.join(Rails.root, "lib/mongoid_migration_task")
class ChangeApplicantOfEnrollmentMember< MongoidMigrationTask
  def migrate
    puts "#{ENV["enrollment_hbx_id"]}"
    puts "#{ENV["enrolllment_member_id"]}"
    puts "#{ENV["new_applicant_id"]}"
    enrollment_id = ENV["enrollment_hbx_id"]
    hbx_enrollment = HbxEnrollment.find(enrollment_id)
    enrollment_member_id = ENV["enrolllment_member_id"]
    new_applicant_id = ENV["new_applicant_id"]
    if hbx_enrollment.nil?
      puts "No hbx_enrollment found with the given id" unless Rails.env.test?
    else
      enrollment_member = hbx_enrollment.hbx_enrollment_members.where(id: enrollment_member_id )
      if enrollment_member.nil?
        puts "No hbx_enrollment member found with the given hbx_enrollment member id" unless Rails.env.test?
      else
        enrollment_member.update_attributes(applicant_id:new_applicant_id)
        puts "change the applicant id of enrollment #{enrollment_id} to  #{new_applicant_id}" unless Rails.env.test?
      end
    end
  end
end

