require 'rails_helper'

RSpec.describe FinancialAssistance::Application, type: :model do

  let(:family)  { FactoryGirl.create(:family, :with_primary_family_member) }
  let(:family_member1) { FactoryGirl.create(:family_member, family: family) }
  let(:family_member2) { FactoryGirl.create(:family_member, family: family) }
  let(:family_member3) { FactoryGirl.create(:family_member, family: family) }
  let(:year) { TimeKeeper.date_of_record.year }
  let!(:application) { FactoryGirl.create(:application, family: family) }
  let!(:tax_household1) {FactoryGirl.create(:tax_household, application: application, effective_ending_on: nil)}
  let!(:tax_household2) {FactoryGirl.create(:tax_household, application: application, effective_ending_on: nil)}
  let!(:tax_household3) {FactoryGirl.create(:tax_household, application: application)}
  let!(:eligibility_determination1) {FactoryGirl.create(:eligibility_determination, application: application, tax_household_id: tax_household1.id, csr_eligibility_kind: "csr_87", determined_on: TimeKeeper.date_of_record)}
  let!(:eligibility_determination2) {FactoryGirl.create(:eligibility_determination, application: application, tax_household_id: tax_household2.id)}
  let!(:eligibility_determination3) {FactoryGirl.create(:eligibility_determination, application: application, tax_household_id: tax_household3.id)}
  let!(:application2) { FactoryGirl.create(:application, family: family, assistance_year: 2016, aasm_state: "denied") }
  let!(:application3) { FactoryGirl.create(:application, family: family, assistance_year: 2016, aasm_state: "verifying_income") }
  let!(:application4) { FactoryGirl.create(:application, family: family, assistance_year: 2016) }
  let!(:application5) { FactoryGirl.create(:application, family: family, assistance_year: 2016) }
  let!(:applicant1) { FactoryGirl.create(:applicant, tax_household_id: tax_household1.id, application: application, family_member_id: family_member1.id) }
  let!(:applicant2) { FactoryGirl.create(:applicant, tax_household_id: tax_household1.id, application: application, family_member_id: family_member2.id) }
  let!(:applicant3) { FactoryGirl.create(:applicant, tax_household_id: tax_household2.id, application: application, family_member_id: family_member3.id) }


  describe "given applications for a family" do
    context "applications for a family with eligibility determinations, tax households and applicants" do

      it "should return all the applications for the family" do
        expect(family.applications.count).to eq 5
        expect(family.active_approved_application).to eq application
      end

      it "should return all the apporved applications for the family" do
        expect(family.approved_applications.count).to eq 3
        family.approved_applications.each do |ap|
          expect(family.approved_applications).to include(ap)
        end
      end

      it "should only return all the apporved applications for the family and not all" do
        expect(family.approved_applications.count).not_to eq 5
        expect(family.approved_applications).not_to eq [application, application2, application3]
      end

      it "should return all the eligibility determinations of the application" do
        expect(application.eligibility_determinations_for_year(year).size).to eq 3
        application.eligibility_determinations_for_year(year).each do |ed|
          expect(application.eligibility_determinations_for_year(year)).to include(ed)
        end
      end

      it "should return all the tax households of the application" do
        expect(application.tax_households.count).to eq 3
        expect(application.tax_households).to eq [tax_household1, tax_household2, tax_household3]
      end

      it "should not return wrong number of tax households of the application" do
        expect(application.tax_households.count).not_to eq 4
        expect(application.tax_households).not_to eq [tax_household1, tax_household2]
      end

      it "should return the latest tax households" do
        expect(application.latest_active_tax_households_with_year(year).count).to eq 2
        expect(application.latest_active_tax_households_with_year(year)).to eq [tax_household1, tax_household2]
      end

      it "should only return latest tax households of the application" do
        expect(application.latest_active_tax_households_with_year(year).count).not_to eq 3
        expect(application.latest_active_tax_households_with_year(year)).not_to eq [tax_household1, tax_household2, tax_household3]
      end

      it "should match the right eligibility determination for the tax household" do
        ed1 = application.eligibility_determinations.where(tax_household_id: tax_household1.id).first
        ed2 = application.eligibility_determinations.where(tax_household_id: tax_household2.id).first
        ed3 = application.eligibility_determinations.where(tax_household_id: tax_household3.id).first
        expect(ed1).to eq eligibility_determination1
        expect(ed2).to eq eligibility_determination2
        expect(ed3).to eq eligibility_determination3
      end

      it "should not return wrong eligibility determinations" do
        expect(application.eligibility_determinations_for_year(year).size).not_to eq 1
        ed1 = application.eligibility_determinations.where(tax_household_id: tax_household1.id).first
        expect(ed1).not_to eq eligibility_determination3
      end

      it "should return unique tax households where the active_approved_application's applicants are present" do
        expect(application.all_tax_households.count).to eq 2
        expect(application.all_tax_households).to eq [tax_household1, tax_household2]
      end

      it "should only return all unique tax_households" do
        expect(application.all_tax_households.count).not_to eq 3
        expect(application.all_tax_households).not_to eq [tax_household1, tax_household1, tax_household2]
      end

      it "should not return all tax_households" do
        expect(application.all_tax_households).not_to eq application.tax_households
        expect(application.all_tax_households).not_to eq [tax_household1, tax_household2, tax_household3]
      end
    end

    context "current_csr_eligibility_kind" do

      it "should equal to the csr_eligibility_kind of preferred_eligibility_determination" do
        expect(application.current_csr_eligibility_kind(tax_household1.id)).to eq eligibility_determination1.csr_eligibility_kind
      end

      it "should return the right eligibility_determination based on the tax_household_id" do
        ed = application.eligibility_determinations.where(tax_household_id: tax_household1.id).first
        expect(ed).to eq eligibility_determination1
      end
    end
  end
end
