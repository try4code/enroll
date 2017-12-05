unless ARGV[0].present? && ARGV[1].present?
  puts "Please include mandatory arguments: File name and Event name. Example: rails runner script/ivl_renewal_notices.rb <file_name> <event_name>" unless Rails.env.test?
  puts "Event Names: ivl_renewal_notice_2, ivl_renewal_notice_3, ivl_renewal_notice_4, final_eligibility_notice_uqhp, final_eligibility_notice_aqhp" unless Rails.env.test?
  exit
end

begin
  file_name = ARGV[0]
  event = ARGV[1]
  @data_hash = {}
  CSV.foreach(file_name,:headers =>true).each do |d|
    if @data_hash[d["ic_number"]].present?
      hbx_ids = @data_hash[d["ic_number"]].collect{|r| r['member_id']}
      next if hbx_ids.include?(d["member_id"])
      @data_hash[d["ic_number"]] << d
    else
      @data_hash[d["ic_number"]] = [d]
    end
  end
rescue Exception => e
  puts "Unable to open file #{e}"
end

field_names = %w(
        ic_number
        hbx_id
        first_name
        last_name
      )
report_name = "#{Rails.root}/#{event}_#{TimeKeeper.date_of_record.strftime('%m_%d_%Y')}.csv"

event_kind = ApplicationEventKind.where(:event_name => event).first
notice_trigger = event_kind.notice_triggers.first

unless event_kind.present?
  puts "Not a valid event kind. Please check the event name" unless Rails.env.test?
end

#need to exlude this list from UQHP_FEL data set.
@excluded_list = []
CSV.foreach("UQHP_FEL_EXLUDE_LIST_nov_14.csv",:headers =>true).each do |d|
  @excluded_list << d["Subscriber"]
end

CSV.open(report_name, "w", force_quotes: true) do |csv|
  csv << field_names
  @data_hash.each do |ic_number , members|
    begin
      next if (members.any?{ |m| @excluded_list.include?(m["member_id"]) })
      primary_member = members.detect{ |m| m["dependent"].upcase == "NO"}
      next if primary_member.nil?
      next if (primary_member.present? && primary_member["policy.subscriber.person.is_dc_resident?"] == "FALSE")
      next if members.select{ |m| m["policy.subscriber.person.is_incarcerated"] == "TRUE"}.present?
      next if (members.any?{ |m| (m["policy.subscriber.person.citizen_status"] == "non_native_not_lawfully_present_in_us") || (m["policy.subscriber.person.citizen_status"] == "not_lawfully_present_in_us")})

      person = Person.where(:hbx_id => primary_member["subscriber_id"]).first
      consumer_role = person.consumer_role
      if person.present? && consumer_role.present?
        builder = notice_trigger.notice_builder.camelize.constantize.new(consumer_role, {
            template: notice_trigger.notice_template,
            subject: event_kind.title,
            event_name: event_kind.event_name,
            mpi_indicator: notice_trigger.mpi_indicator,
            person: person,
            data: members
            }.merge(notice_trigger.notice_trigger_element_group.notice_peferences)
            )
        builder.deliver
        csv << [
          ic_number,
          person.hbx_id,
          person.first_name,
          person.last_name
        ]
      else
        puts "Error for ic_number - #{ic_number} -- #{e}" unless Rails.env.test?
      end
    rescue Exception => e
      puts "Unable to deliver #{event} notice to family - #{ic_number} due to the following error #{e.backtrace}" unless Rails.env.test?
    end

  end
end