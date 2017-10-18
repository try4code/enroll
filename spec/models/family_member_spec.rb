require 'rails_helper'

describe FamilyMember do
  subject { FamilyMember.new(:is_primary_applicant => nil, :is_coverage_applicant => nil) }

  before(:each) do
    subject.valid?
  end

  it "should validate the presence of a person" do
    expect(subject).to have_errors_on(:person_id)
  end
  it "should validate the presence of is_primary_applicant" do
    expect(subject).to have_errors_on(:is_primary_applicant)
  end
  it "should validate the presence of is_coverage_applicant" do
    expect(subject).to have_errors_on(:is_coverage_applicant)
  end

end

describe FamilyMember, "given a person" do
  let(:person) { Person.new }
  subject { FamilyMember.new(:person => person) }

  it "delegates #ivl_coverage_selected to person" do
    expect(person).to receive(:ivl_coverage_selected)
    subject.ivl_coverage_selected
  end
end


describe FamilyMember, "given a person" do
  let(:person) { create :person ,:with_family }

  it "should error when trying to save duplicate family member" do
    family_member = FamilyMember.new(:person => person) 
    person.families.first.family_members << family_member
    person.families.first.family_members << family_member
    expect(family_member.errors.full_messages.join(",")).to match(/Family members Duplicate family_members for person/)
  end
end

describe FamilyMember, dbclean: :after_each do
  context "a family with members exists" do
    include_context "BradyBunchAfterAll"

    before :each do
      create_brady_families
    end

    let(:family_member_id) {mikes_family.primary_applicant.id}

    it "FamilyMember.find(id) should work" do
      expect(FamilyMember.find(family_member_id).id.to_s).to eq family_member_id.to_s
    end

    it "should be possible to find the primary_relationship" do
      mikes_family.dependents.each do |dependent|
        if brady_children.include?(dependent.person)
          expect(dependent.primary_relationship).to eq "child"
        else
          expect(dependent.primary_relationship).to eq "spouse"
        end
      end
    end
  end

  let(:p0) {Person.create!(first_name: "Dan", last_name: "Aurbach")}
  let(:p1) {Person.create!(first_name: "Patrick", last_name: "Carney")}
  let(:ag) { 
    fam = Family.new
    fam.family_members.build(
      :person => p0,
      :is_primary_applicant => true
    )
    fam.save!
    fam
  }
  let(:family_member_params) {
    { person: p1,
      is_primary_applicant: true,
      is_coverage_applicant: true,
      is_consent_applicant: true,
      is_active: true}
  }

  context "parent" do
    it "should equal to family" do
      family_member = ag.family_members.create(**family_member_params)
      expect(family_member.parent).to eq ag
    end

    it "should raise error with nil family" do
      family_member = FamilyMember.new(**family_member_params)
      expect{family_member.parent}.to raise_error(RuntimeError, "undefined parent family")
    end
  end

  context "person" do
    it "with person" do
      family_member = FamilyMember.new(**family_member_params)
      family_member.person= p1
      expect(family_member.person).to eq p1
    end

    it "without person" do
      expect(FamilyMember.new(**family_member_params.except(:person)).valid?).to be_falsey
    end
  end

  context "broker" do
    let(:broker_role)   {FactoryGirl.create(:broker_role)}
    let(:broker_role2)  {FactoryGirl.create(:broker_role)}

    it "with broker_role" do
      family_member = ag.family_members.create(**family_member_params)
      family_member.broker= broker_role
      expect(family_member.broker).to eq broker_role
    end

    it "without broker_role" do
      family_member = ag.family_members.create(**family_member_params)
      family_member.broker = broker_role
      expect(family_member.broker).to eq broker_role

      family_member.broker = broker_role2
      expect(family_member.broker).to eq broker_role2
    end
  end

  context "comments" do
    it "with blank" do
      family_member = ag.family_members.create({
        person: p0,
        is_primary_applicant: true,
        is_coverage_applicant: true,
        is_consent_applicant: true,
        is_active: true,
        comments: [{priority: 'normal', content: ""}]
      })

      expect(family_member.errors[:comments].any?).to eq true
    end

    it "without blank" do
      family_member = ag.family_members.create({
        person: p0,
        is_primary_applicant: true,
        is_coverage_applicant: true,
        is_consent_applicant: true,
        is_active: true,
        comments: [{priority: 'normal', content: "aaas"}]
      })

      expect(family_member.errors[:comments].any?).to eq false
      expect(family_member.comments.size).to eq 1
    end
  end

  describe "instantiates object." do
    it "sets and gets all basic model fields and embeds in parent class" do
      a = FamilyMember.new(
        person: p0,
        is_primary_applicant: true,
        is_coverage_applicant: true,
        is_consent_applicant: true,
        is_active: true
        )

      a.family = ag

      expect(a.person.last_name).to eql(p0.last_name)
      expect(a.person_id).to eql(p0._id)

      expect(a.is_primary_applicant?).to eql(true)
      expect(a.is_coverage_applicant?).to eql(true)
      expect(a.is_consent_applicant?).to eql(true)
    end
  end
end

# describe FamilyMember, "which is inactive" do
#   it "can be reactivated with a specified relationship"
# end

describe "for families with financial assistance application" do
  let(:person) { FactoryGirl.create(:person)}
  let(:person1) { FactoryGirl.create(:person)}
  let(:family) { FactoryGirl.create(:family, :with_primary_family_member,person: person) }

  before(:each) do
    allow_any_instance_of(FinancialAssistance::Application).to receive(:set_benchmark_plan_id)
  end

  context "family_member added when application is in progress" do
    it "should create an applicant with the family_member_id of the added member" do
      family.applications.create!
      expect(family.application_in_progress.active_applicants.count).to eq 0
      fm = family.family_members.create!({person_id: person1.id, is_primary_applicant: false, is_coverage_applicant: true})
      expect(family.application_in_progress.active_applicants.count).to eq 1
      expect(family.application_in_progress.active_applicants.first.family_member_id).to eq fm.id
    end
  end
end


describe "tbnn" do
  let(:consumer_role){FactoryGirl.build(:consumer_role)}
  let!(:person) {Person.new (person_demo)}
  let!(:same_phone) {Phone.new(kind: "home", area_code: "202", number: "555-9999", full_phone_number:"2025559999") }
  let(:same_address){ Address.new(kind: 'home', address_1: "1 street ct", address_2: "test2", city: "was", state: "DC", zip: "22211")}

  let!(:other_phone) {Phone.new(kind: "home", area_code: "123", number: "456-7890", full_phone_number:"1234567890") }
  let(:other_address){ Address.new(kind: 'home', address_1: "1111 spalding ct", address_2: "apt 444", city: "was", state: "DC", zip: "22211")}


  # let!(:person2) {FactoryGirl.create(:person,:with_test_data, phones: phone.to_a, addresses: address.to_a)}
  let!(:family) {FactoryGirl.create(:family, :with_primary_family_member, person: person)}
  let!(:family_member) {FactoryGirl.build(:family_member, family: family, person: person2)}
  let!(:family_members) {family.family_members}
  let!(:dob) {"1972-04-04"}

  let!(:person_demo) {
    {
        first_name: 'ivl',
        middle_name: 'X',
        last_name: 'test',
        gender: "male",
        dob: dob.to_date,
        ssn: '123121234',
        no_ssn: "0",
        us_citizen: 'true',
        naturalized_citizen: 'true',
        indian_tribe_member: 'true',
        tribal_id: '1234',
        is_incarcerated: 'true',
        is_physically_disabled: 'true',
        eligible_immigration_status: "false",
        ethnicity: ["", "", "", "", "", "", ""],
        addresses: same_address.to_a,
        phones: same_phone.to_a,
        no_dc_address: "false"
    }
  }
  let!(:person2) {Person.new (person_demo)}

  let!(:person_demographics) {
    {
    "first_name" => 'ivl',
    "middle_name" => 'X',
    "last_name" => 'test',
    "gender" => "male",
    "dob" => dob.to_date,
    "ssn" => '123121234',
    "no_ssn" => "0",
    "relationship" => 'spouse',
    "is_applying_coverage" => 'true',
    "us_citizen" => 'true',
    "naturalized_citizen" => 'true',
    "indian_tribe_member" => 'true',
    "tribal_id" => '1234',
    "is_incarcerated" => 'true',
    "is_physically_disabled" => 'true',
    "eligible_immigration_status" => "false",
    "ethnicity" => ["", "", "", "", "", "", ""],
    "no_dc_address" => "false"
    }
  }


  let(:email_attributes) { {"0"=>{"kind"=>"home", "address"=>"test@example.com"}}}
  let(:addresses_attributes) { {"0"=>{"kind"=>"home", "address_1"=>"1 street ct", "address_2"=>"apt test2", "city"=>"was", "state"=>"DC", "zip"=>"22211"}
                                } }
  let!(:same_phones_attributes) {{"0"=>{"kind"=>"home", "full_phone_number"=> "2025559999"},
                                  "1"=>{"kind"=>"home", "full_phone_number"=> ""},
                                  "2"=>{"kind"=>"work", "full_phone_number"=>""},
                                  "3"=>{"kind"=>"fax", "full_phone_number"=>""}}}

  let!(:phones_attributes) {{"0"=>{"kind"=>"home", "full_phone_number"=>"20211111133"}}}
  let!(:person_attributes) { person_demographics.merge({ "phones_attributes"=>same_phones_attributes,"addresses" => addresses_attributes})}




  it "test" do
    allow(family_member).to receive(:relationship).and_return 'spouse'
    allow(family_member).to receive(:is_applying_coverage).and_return 'true'
    allow(family_member).to receive(:eligible_immigration_status).and_return 'false'
    allow(person).to receive(:consumer_role).and_return(consumer_role)
    allow(person2).to receive(:consumer_role).and_return(consumer_role)
    allow(person2).to receive(:us_citizen).and_return 'true'
    allow(family_member).to receive(:naturalized_citizen).and_return 'true'
    allow(family_member).to receive(:indian_tribe_member).and_return 'true'
    expect(family_member.family_mem_attr_changed?(person_attributes)).to eq true
  end

end
