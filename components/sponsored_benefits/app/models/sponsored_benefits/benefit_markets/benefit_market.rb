module SponsoredBenefits
  module BenefitMarkets
    class BenefitMarket
      include Mongoid::Document
      include Mongoid::Timestamps

      PROBATION_PERIOD_KINDS  = [:first_of_month_before_15th, :date_of_hire, :first_of_month, :first_of_month_after_30_days, :first_of_month_after_60_days]

      field :kind,        type: Symbol  # => :aca_shop
      field :title,       type: String, default: "" # => DC Health Link SHOP Market
      field :description, type: String, default: ""

      belongs_to  :site,                  class_name: "SponsoredBenefits::Site"
      has_many    :benefit_applications,  class_name: "SponsoredBenefits::BenefitApplications::BenefitApplication"

      embeds_one :configuration 
      embeds_one :contact_center_profile, class_name: "SponsoredBenefits::Organizations::ContactCenter"

      embeds_many :benefit_catalogs,      class_name: "SponsoredBenefits::BenefitCatalogs::BenefitCatalog",
        cascade_callbacks: true,
        validate: true

      validates :kind,
        inclusion: { in: SponsoredBenefits::BENEFIT_MARKET_KINDS, message: "%{value} is not a valid market kind" },
        allow_nil:    false

      index({ "kind"  => 1 })
      index({ "benefit_catalogs._id" => 1 })
      index({ "benefit_catalogs.application_period.min" => 1,
              "benefit_catalogs.application_period.max" => 1 },
            { name: "benefit_catalogs_application_period" })


      def kind=(new_kind)
        initialize_configuration(new_kind)
        write_attribute(:kind, new_kind)
      end

      def benefit_catalog_for(date)
        benefit_catalogs.select { |catalog| catalog.application_period_cover?(date)}
      end      

      # Calculate available effective dates periods using passed date
      def effective_periods_for(base_date = ::Timekeeper.date_of_record)
        start_on = if TimeKeeper.date_of_record.day > open_enrollment_minimum_begin_day_of_month
          TimeKeeper.date_of_record.beginning_of_month + open_enrollment_maximum_length
        else
          TimeKeeper.date_of_record.prev_month.beginning_of_month + open_enrollment_maximum_length
        end

        end_on = TimeKeeper.date_of_record - Settings.aca.shop_market.initial_application.earliest_start_prior_to_effective_on.months.months
        (start_on..end_on).select {|t| t == t.beginning_of_month}
      end

      def calculate_start_on_options
        calculate_start_on_dates.map {|date| [date.strftime("%B %Y"), date.to_s(:db) ]}
      end

      def open_enrollment_minimum_begin_day_of_month(use_grace_period = false)
        if use_grace_period
          open_enrollment_end_on_day_of_month - open_enrollment_grace_period_minimum_length_days
        else
          open_enrollment_end_on_day_of_month - open_enrollment_minimum_length_days
        end
      end

      def open_enrollment_maximum_length
        # Settings.aca.shop_market.open_enrollment.maximum_length.months.months
        configuration.open_enrollment_months_max.months
      end

      def open_enrollment_end_on_day_of_month
        Settings.aca.shop_market.open_enrollment.monthly_end_on
      end

      def open_enrollment_minimum_length_days
        Settings.aca.shop_market.open_enrollment.minimum_length.adv_days
      end

      def open_enrollment_grace_period_minimum_length_days
        Settings.aca.shop_market.open_enrollment.minimum_length.days
      end

      private

      def initialize_configuration(benefit_market_kind)
        klass_name = "#{new_kind.to_s}_configuration".camelcase
        klass = klass_name.constantize
        self.configuration = klass.new
      end



    end
  end
end