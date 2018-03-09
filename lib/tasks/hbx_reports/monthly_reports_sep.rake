require 'csv'
# RAILS_ENV=production bundle exec rake reports:monthly_reports_sep
namespace :reports do
 desc "Monthly sep enrollments report"
 task :monthly_reports_sep => :environment do

    file_name = "#{Rails.root}/monthly_sep_enrollments_report_#{TimeKeeper.date_of_record.strftime("%m_%d_%Y")}.csv"
    puts "Created file and trying to import the data #{file_name}" 
    date_range = ((TimeKeeper.date_of_record - 1.month).beginning_of_month..(TimeKeeper.date_of_record - 1.month).end_of_month)

    families = Family.where({:"households.hbx_enrollments" => {"$elemMatch" => {
      "aasm_state" => {"$in" => HbxEnrollment::ENROLLED_STATUSES + HbxEnrollment::TERMINATED_STATUSES },
      :enrollment_kind => "special_enrollment",
      :effective_on.gte => Date.new(2018,1,1),
      :kind => 'individual'
      }}})

    CSV.open(file_name,"w") do |csv|
      csv <<  ["Subscriber ID",
        "Policy ID",
        "Primary First Name",
        "Primary Last Name",
        "SEP Type",
        "Date Of Enrollment",
        "Enrollee First Name", 
        "Enrollee Last Name",
        "Coverage Dental or health",
        "Plan Name",
        "HIOS ID",
        "No. of Enrollees"
      ]

      families.each do |family|
        hbx_enrollments = family.active_household.hbx_enrollments.special_enrollments
        if hbx_enrollments
          hbx_enrollments.each do |hbx_enroll|
            next unless date_range.cover?(hbx_enroll.special_enrollment_period.created_at.to_date)
            hbx_enroll.hbx_enrollment_members.each do |hbx_member|
              person = hbx_member.person
              if hbx_enroll.special_enrollment_period
                sep_qle = hbx_enroll.special_enrollment_period
                plan = hbx_enroll.plan
                enrollees = hbx_enroll.hbx_enrollment_members.count
                csv << [ hbx_enroll.subscriber.person.hbx_id, 
                  hbx_enroll.hbx_id,
                  hbx_enroll.subscriber.person.first_name,
                  hbx_enroll.subscriber.person.last_name,
                  sep_qle.title,
                  sep_qle.effective_on,
                  person.first_name,
                  person.last_name,
                  plan.coverage_kind,
                  plan.name,
                  plan.hios_id,
                  enrollees
                ]
              end
            end
          end
        end
      end
    end
  end
end
