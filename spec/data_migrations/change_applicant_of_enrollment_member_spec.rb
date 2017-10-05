require "rails_helper"
require File.join(Rails.root, "app", "data_migrations", "change_applicant_of_enrollment_member")

describe ChangeApplicantOfEnrollmentMember, dbclean: :after_each do

  let(:given_task_name) { "change_applicant_of_enrollment_member" }
  subject { ChangeApplicantOfEnrollmentMember.new(given_task_name, double(:current_scope => nil)) }

  describe "given a task name" do
    it "has the given task name" do
      expect(subject.name).to eql given_task_name
    end
  end

  describe "change the applicant id of an enrollment member" do
    let!(:family1) { FactoryGirl.create(:family, :with_primary_family_member)}
    let!(:primary1) { family1.primary_applicant }
    let!(:family2) { FactoryGirl.create(:family, :with_primary_family_member)}
    let!(:primary2) { family2.primary_applicant }
    let!(:hbx_enrollment) { FactoryGirl.create(:hbx_enrollment, household: family1.active_household)}
    let(:date) { DateTime.now - 10.days }
    let(:subscriber) { FactoryGirl.create(:hbx_enrollment_member, :hbx_enrollment => hbx_enrollment, eligibility_date: date, coverage_start_on: date, applicant_id: primary.id) }
    let!(:hbx_en_member1) { FactoryGirl.create(:hbx_enrollment_member,
                                              :id => "111",
                                              :hbx_enrollment => hbx_enrollment,
                                              eligibility_date: date,
                                              coverage_start_on: date,
                                              applicant_id: primary1.id) }

    before :each do
     hbx_enrollment.hbx_enrollment_members = [hbx_en_member1]
     hbx_enrollment.save!
     allow(ENV).to receive(:[]).with("enrollment_hbx_id").and_return(hbx_enrollment.hbx_id)
     allow(ENV).to receive(:[]).with("enrollment_member_id").and_return(hbx_en_member1.id)
     allow(ENV).to receive(:[]).with("new_applicant_id").and_return(primary2.id)
    end
    it "change the applicant id of the hbx_enrollment_member" do
      expect(hbx_en_member1.applicant_id).to eq primary1.id
      subject.migrate
      family1.reload
      family2.reload
      hbx_en_member1.reload
      expect(hbx_en_member1.applicant_id).to eq primary2.id
    end
  end
end

