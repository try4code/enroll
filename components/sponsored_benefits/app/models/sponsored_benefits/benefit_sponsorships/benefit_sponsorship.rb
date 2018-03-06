# Manage enrollment-related behavior for a benefit-sponsoring organization (e.g. employers, congress, HBX, etc.)
# The model design assumes a once annual enrollment period and effective date.  For scenarios where there's a once-yearly
# open enrollment, new sponsors may join mid-year for initial enrollment, subsequently renewing on-schedule in following
# cycles.  Scenarios where enollments are conducted on a rolling monthly basis are also supported.

# OrganzationProfiles will typically embed many BenefitSponsorships.  A new BenefitSponsorship is in order when
# a significant change occurs, such as the following supported scenarios:
# - Benefit Sponsor (employer) terminates and later returns after some elapsed period
# - Existing Benefit Sponsor changes effective date

# Referencing a new BenefitSponsorship helps ensure integrity on subclassed and associated data models and
# enables history tracking as part of the models structure
module SponsoredBenefits
  module BenefitSponsorships
    class BenefitSponsorship
      include Mongoid::Document
      include Mongoid::Timestamps
      # include Concerns::Observable

      embedded_in :benefit_sponsorable, polymorphic: true

      # This sponsorship's workflow status
      field :aasm_state,      type: String, default: :applicant
      field :site_id,         type: String

      belongs_to  :benefit_market,        class_name: "SponsoredBenefits::BenefitMarkets::BenefitMarket"
      has_many    :benefit_applications,  class_name: "SponsoredBenefits::BenefitApplications::BenefitApplication"

      validates_presence_of :benefit_market

      delegate :plan_design_organization, to: :benefit_sponsorable

      # Prevent changes to immutable fields. Instantiate a new model instead
      # before_validation {
      #     if persisted?
      #       false if  (self.initial_enrollment_period.changed? && self.initial_enrollment_period_was.present?) ||
      #                 (annual_enrollment_period_begin_month.changed? && annual_enrollment_period_begin_month.present?)
      #     end
      #   }

      after_create :build_nested_models

      def census_employees
        SponsoredBenefits::CensusMembers::PlanDesignCensusEmployee.find_by_benefit_sponsor(self)
      end




      def initial_enrollment_period=(new_initial_enrollment_period)
        initial_enrollment_range = SponsoredBenefits.tidy_date_range(new_initial_enrollment_period, :initial_enrollment_period)
        write_attribute(:initial_enrollment_period, initial_enrollment_range) if initial_enrollment_range.present?
      end

      def initial_enrollment_period_to_s
        date_start = initial_enrollment_period.begin
        date_end = initial_enrollment_period.end
        "#{date_start.strftime('%B')} #{date_start.day.ordinalize} #{date_start.strftime('%Y')}  -  #{date_end.strftime('%B')} #{date_end.day.ordinalize} #{date_end.strftime('%Y')}"
      end

      # TODO - turn this in to counter_cache -- see: https://gist.github.com/andreychernih/1082313
      def roster_size
        return @roster_size if defined? @roster_size
        @roster_size = census_employees.active.size
      end

      def earliest_plan_year_start_on_date
        plan_years = (self.plan_years.published_or_renewing_published + self.plan_years.where(:aasm_state.in => ["expired", "terminated"]))
        plan_years.reject!{|py| py.can_be_migrated? }
        plan_year = plan_years.sort_by {|test| test[:start_on]}.first
        if !plan_year.blank?
          plan_year.start_on
        end
      end

      class << self
        def find(id)
          organization = SponsoredBenefits::Organizations::PlanDesignOrganization.where("plan_design_proposals.profile.benefit_sponsorships._id" => BSON::ObjectId.from_string(id)).first
          return if organization.blank?
          proposal = organization.plan_design_proposals.where("profile.benefit_sponsorships._id" => BSON::ObjectId.from_string(id)).first
          proposal.profile.benefit_sponsorships.detect{|sponsorship| sponsorship.id.to_s == id.to_s}
        end

        def find_broker_for_sponsorship(id)
          organization = nil
          Organizations::PlanDesignOrganization.all.each do |pdo|
            sponsorships = pdo.plan_design_profile.try(:benefit_sponsorships) || []
            organization = pdo if sponsorships.any? { |sponsorship| sponsorship._id == BSON::ObjectId.from_string(id)}
          end
          organization
        end
      end

      private

      def build_nested_models
        # build_inbox if inbox.nil?
      end

      def save_inbox
        welcome_subject = "Welcome to #{Settings.site.short_name}"
        welcome_body = "#{Settings.site.short_name} is the #{Settings.aca.state_name}'s on-line marketplace to shop, compare, and select health insurance that meets your employee's health needs and budget."
        @inbox.save
        @inbox.messages.create(subject: welcome_subject, body: welcome_body)
      end


    end
  end
end