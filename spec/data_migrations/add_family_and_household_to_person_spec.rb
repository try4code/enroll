require "rails_helper"
require File.join(Rails.root, "app", "data_migrations", "add_family_and_household_to_person")

describe AddFamilyAndHouseholdToPerson, dbclean: :after_each do
  subject { AddFamilyAndHouseholdToPerson.new("add_family_and_household_to_person", double(:current_scope => nil)) }
  let(:person) { FactoryGirl.create(:person) }
  context "will add family and household to the person" do
    before do
      allow(ENV).to receive(:[]).with("hbx_id").and_return(person.hbx_id)
    end
    it "will add a family to the person" do
      expect(person.families.size).to eq 0
      subject.migrate
      person.reload
      expect(person.families.size).to eq 1
    end
    it "will add a active_household to the person" do
      expect(person.families.size).to eq 0
      subject.migrate
      person.reload
      expect(person.families.first.active_household).not_to eq nil
    end
    it "will add two coverage households to the person" do
      expect(person.families.size).to eq 0
      subject.migrate
      person.reload
      expect(person.families.first.active_household.coverage_households.size).to eq 2
    end
    it "will add family to the person with one family member" do
      expect(person.families.size).to eq 0
      subject.migrate
      person.reload
      expect(person.families.first.family_members.size).to eq 1
    end
  end
end
