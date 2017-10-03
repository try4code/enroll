require File.join(Rails.root, "lib/mongoid_migration_task")

class AddFamilyAndHouseholdToPerson < MongoidMigrationTask
  def migrate
    person = Person.where(hbx_id: ENV['hbx_id']).first
    if person.nil?
      raise "Invalid Hbx Id"
    end
    fam = Family.new
    fam.add_family_member(person, is_primary_applicant: true) unless fam.find_family_member_by_person(person)
    fam.save!
    hh = person.primary_family.active_household
    hh.immediate_family_coverage_household
    hh.extended_family_coverage_household
  end
end
