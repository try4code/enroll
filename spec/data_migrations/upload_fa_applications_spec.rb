require "rails_helper"
require File.join(Rails.root, "app", "data_migrations", "upload_faa")

describe UploadFAA, dbclean: :after_each do

  before :each do
    allow_any_instance_of(FinancialAssistance::Application).to receive(:set_benchmark_plan_id)
  end

  let(:given_task_name) {"upload_core_29"}
  subject {UploadFAA.new(given_task_name, double(:current_scope => nil))}

  it "has the given task name" do
    expect(subject.name).to eql given_task_name
  end

  describe "upload applications from CSV" do

    let!(:family) {FactoryGirl.create(:family, :with_primary_family_member, id: "5a3be50aeab5e71b2100000c")}
    let!(:household) {family.households.first}
    let!(:application) {FactoryGirl.create(:application, family: family, id: "5a3be50aea")}
    let!(:family_member) {FactoryGirl.create(:family_member, :family => family, id: "5a3be50")}
    let!(:applicant) {FactoryGirl.create(:applicant, application: application, family_member_id: family_member.id, id: "5a3be")}
    let!(:income) {FactoryGirl.create(:financial_assistance_income, applicant: applicant, id: "5a3be5")}
    let!(:employer_address) {income.build_employer_address()}
    let!(:employer_phone) {income.build_employer_phone()}
    let!(:benefit) {FinancialAssistance::Benefit.new(applicant: applicant, id: "5a3b")}
    let!(:employer_address) {benefit.build_employer_address()}
    let!(:employer_phone) {benefit.build_employer_phone()}
    let!(:deduction) {FinancialAssistance::Deduction.new}


    it "for a family before application is uploaded" do
      expect(family.applications.count).to eq 1
    end

    it "for a family after application is uploaded" do
      subject.migrate
      expect(family.applications.count).to eq 2
    end
  end
end
