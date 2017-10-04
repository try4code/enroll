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

  describe "changing plan year's state" do
    let(:family) { FactoryGirl.build(:family, :with_primary_family_member_and_dependent)}
    let(:primary) { family.primary_family_member }
    let(:dependents) { family.dependents }
    let(:hbx_enrollment) { FactoryGirl.create(:hbx_enrollment, household: family.active_household)}
    let(:date) { DateTime.now - 10.days }
    let(:subscriber) { FactoryGirl.create(:hbx_enrollment_member, :hbx_enrollment => hbx_enrollment, eligibility_date: date, coverage_start_on: date, applicant_id: primary.id) }
    let(:hbx_en_member1) { FactoryGirl.create(:hbx_enrollment_member,
                                              :id => "111",
                                              :hbx_enrollment => hbx_enrollment,
                                              eligibility_date: date,
                                              coverage_start_on: date,
                                              applicant_id: dependents.first.id) }

    let(:new_member) { HbxEnrollmentMember.new({ :id => "222",
                                                 :applicant_id => dependents.last.id,
                                                 :eligibility_date => date,
                                                 :coverage_start_on => date}) }


      before :each do
        hbx_enrollment.hbx_enrollment_members = [subscriber, hbx_en_member1]
        hbx_enrollment.save!
        allow(ENV).to receive(:[]).with("enrollment_hbx_id").and_return(hbx_enrollment.hbx_id)
        allow(ENV).to receive(:[]).with("enrollment_member_id").and_return(hbx_en_member1.id)
        allow(ENV).to receive(:[]).with("new_applicant_id").and_return(new_member.id)
      end

      it "change the applicant id of the hbx_enrollment_member" do
        expect(hbx_en_member1.applicant_id).to eq dependents.first.id
        subject.migrate
        hbx_enrollment.reload!
        hbx_en_member1.reload!
        expect(hbx_en_member1.applicant_id).to eq new_member.id
      end
  end
end

