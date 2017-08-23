module Factories
  class EmployerEnrollFactory

    attr_accessor :employer_profile, :date

    def initialize
      @logger = Logger.new("#{Rails.root}/log/employer_enroll_factory_logfile.log")
    end

    def begin
      @logger.debug "Processing #{employer_profile.legal_name}"
      published_plan_years = @employer_profile.plan_years.published_or_renewing_published.select do |plan_year|
        (plan_year.start_on..plan_year.end_on).cover?(@date || TimeKeeper.date_of_record)
      end

      if published_plan_years.size > 1
        @logger.debug "Found more than 1 published plan year for #{employer_profile.legal_name}"
        return
      end

      if published_plan_years.empty?
        @logger.debug "Published plan year missing for #{employer_profile.legal_name}."
        return
      end

      current_plan_year = published_plan_years.first
      if current_plan_year.may_activate?
        begin_coverage_for_employees(current_plan_year)
        current_plan_year.activate!

        if @employer_profile.may_enroll_employer?
          @employer_profile.enroll_employer!
        elsif @employer_profile.may_force_enroll?
          @employer_profile.force_enroll!
        end
      end
    end

    def end
      expiring_plan_years = @employer_profile.plan_years.published_or_renewing_published.where(:"end_on".lt => (@date || TimeKeeper.date_of_record))
      expiring_plan_years.each do |expiring_plan_year|
        expiring_plan_year.hbx_enrollments.each do |enrollment|
          begin
            enrollment.expire_coverage! if enrollment.may_expire_coverage?
            if assignment = enrollment.benefit_group_assignment
              assignment.expire_coverage! if assignment.may_expire_coverage?
              assignment.update_attributes(is_active: false) if assignment.is_active?
            end
          rescue Exception => e
            @logger.debug "Exception #{e.inspect} occured for #{census_employee.full_name}"
          end
        end
        expiring_plan_year.expire! if expiring_plan_year.may_expire?
      end
    end

    private

    def begin_coverage_for_employees(current_plan_year)
      id_list = current_plan_year.benefit_groups.collect(&:_id).uniq

      enrollment_expr = {
        :benefit_group_id.in => id_list,
        :effective_on => current_plan_year.start_on,
        :aasm_state.in => (HbxEnrollment::ENROLLED_AND_RENEWAL_STATUSES + HbxEnrollment::WAIVED_STATUSES)
      }

      families = Family.where(:"households.hbx_enrollments" => {:$elemMatch => enrollment_expr})
      families.each do |family|
        enrollments = family.active_household.hbx_enrollments.where(enrollment_expr)

        %w(health dental).each do |coverage_kind|
          enrollments_by_kind = enrollments.by_coverage_kind(coverage_kind)
          enrollment = enrollments_by_kind.first
          next if enrollment.blank?

          if enrollments_by_kind.size > 1
            enrollment = enrollments_by_kind.order(:"created_at".desc).first
            enrollments_by_kind.each do |e|
              next if e.hbx_id == enrollment.hbx_id
              e.cancel_coverage! if e.may_cancel_coverage?
            end
          end

          enrollment.begin_coverage! if enrollment.may_begin_coverage?
          if enrollment.is_coverage_waived?
            enrollment.benefit_group_assignment.waive_benefit
          else
            enrollment.benefit_group_assignment.begin_benefit
          end
        end
      end
    end
  end 
end