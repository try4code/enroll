require 'rails_helper'

RSpec.describe PeopleController, type: :controller do
  before :each do
    allow_any_instance_of(FinancialAssistance::Application).to receive(:set_benchmark_plan_id)
  end

  let(:census_employee_id) { "abcdefg" }
  let(:user) { FactoryGirl.build(:user) }
  let(:email) {FactoryGirl.build(:email)}

  let(:consumer_role){FactoryGirl.build(:consumer_role)}

  let(:census_employee){FactoryGirl.build(:census_employee)}
  let(:employee_role){FactoryGirl.build(:employee_role, :census_employee => census_employee)}
  let(:person) { FactoryGirl.create(:person, :with_employee_role) }

  let!(:person_demographics) {
    {
        "first_name" => "aaa",
        "last_name" => "bbb",
        "middle_name" => "",
        "name_pfx" => "ddd",
        "name_sfx" => "eee",
        "gender" => "male",
        "race" => "race",
        "ethnicity" => ["ethnicity"],
        "is_incarcerated" => "true",
        "tribal_id" => "test",
        "is_physically_disabled" => nil
    }
  }

  let(:vlp_document){FactoryGirl.build(:vlp_document)}

  it "GET new" do
    sign_in(user)
    get :new
    expect(response).to have_http_status(:success)
  end

  describe "POST update" do
    let(:vlp_documents_attributes) { {"1" => vlp_document.attributes.to_hash}}
    let(:consumer_role_attributes) { consumer_role.attributes.to_hash}
    let(:person_attributes) { person_demographics.to_hash}
    let(:employee_roles) { person.employee_roles }
    let(:census_employee_id) {employee_roles[0].census_employee_id}

    let(:email_attributes) { {"0"=>{"kind"=>"home", "address"=>"test@example.com"}}}
    let(:addresses_attributes) { {"0"=>{"kind"=>"home", "address_1"=>"address1", "address_2"=>"", "city"=>"city1", "state"=>"DC", "zip"=>"22211"},
        "1"=>{"kind"=>"mailing", "address_1"=>"address1", "address_2"=>"", "city"=>"city1", "state"=>"DC", "zip"=>"22211"}} }

    let!(:family) {FactoryGirl.create(:family, :with_primary_family_member, person: person)}

    before :each do
      allow(Person).to receive(:find).and_return(person)
      allow(Person).to receive(:where).and_return(Person)
      allow(Person).to receive(:first).and_return(person)
      allow(person).to receive(:phone_numbers_matched?).and_return true
      allow(controller).to receive(:sanitize_person_params).and_return(true)
      allow(person).to receive(:consumer_role).and_return(consumer_role)

      sign_in user
    end

    context "duplicate addresses records" do
      it "clean all existing addresses " do
        allow(person).to receive(:has_active_consumer_role?).and_return(false)
        allow(person).to receive(:update_attributes).and_return(true)
        person_attributes[:addresses_attributes] = addresses_attributes

        post :update, id: person.id, person: person_attributes
        expect(person.addresses).to eq []
      end

      it "keep old addresses if person update failed" do
        allow(person).to receive(:has_active_consumer_role?).and_return(false)
        allow(person).to receive(:update_attributes).and_return(false)
        person_attributes[:addresses_attributes] = addresses_attributes
        address = person.addresses

        post :update, id: person.id, person: person_attributes
        expect(person.addresses).to eq address
      end
    end

    context "when individual" do
      it "update person" do
        allow(request).to receive(:referer).and_return("insured/families/personal")
        allow(person).to receive(:has_active_consumer_role?).and_return(true)
        allow(consumer_role).to receive(:find_document).and_return(vlp_document)
        allow(vlp_document).to receive(:save).and_return(true)
        allow(vlp_document).to receive(:update_attributes).and_return(true)


        consumer_role_attributes[:vlp_documents_attributes] = vlp_documents_attributes
        person_attributes[:consumer_role_attributes] = consumer_role_attributes

    
        post :update, id: person.id, person: person_attributes
        expect(response).to redirect_to(personal_insured_families_path)
        expect(assigns(:person)).not_to be_nil
        expect(flash[:notice]).to eq 'Person was successfully updated.'
      end

      it "should update is_applying_coverage" do
        allow(request).to receive(:referer).and_return("insured/families/personal")
        allow(person).to receive(:has_active_consumer_role?).and_return(true)
        allow(person).to receive(:update_attributes).and_return(true)
        person_attributes.merge!({"is_applying_coverage" => "false"})

        post :update, id: person.id, person: person_attributes
        expect(assigns(:person).consumer_role.is_applying_coverage).to eq false
      end
    end

    context "when employee" do
      it "when employee" do
        person_attributes[:emails_attributes] = email_attributes

        allow(controller).to receive(:get_census_employee).and_return(census_employee)
        allow(person).to receive(:has_active_consumer_role?).and_return(false)
        allow(person).to receive(:update_attributes).and_return(true)

        post :update, id: person.id, person: person_attributes
        expect(response).to redirect_to(family_account_path)
        expect(flash[:notice]).to eq 'Person was successfully updated.'
      end
    end
  end


  describe "POST ivl update" do
    let!(:person) { FactoryGirl.create(:person) }
    let!(:family) {FactoryGirl.create(:family, :with_primary_family_member, person: person)}
    let!(:application) {FactoryGirl.create(:application, family: family, assistance_year: 2017)}

    let!(:person_demographics) {
    {"first_name"=>"ivl",
     "middle_name"=>"",
     "last_name"=>"test",
     "name_sfx"=>"",
     "gender"=>"male",
     "is_applying_coverage"=>"true",
     "us_citizen"=>"true",
     "naturalized_citizen"=>"false",
     "indian_tribe_member"=>"false",
     "tribal_id"=>"",
     "is_incarcerated"=>"false",
     "is_physically_disabled"=>"false",
     "ethnicity"=>["", "Other Asian", "", "", "", "", "", ""],
     "is_consumer_role"=>"true",
     "no_dc_address"=>"false"
    } }

    let(:person_attributes) { person_demographics.merge({:email_attributes=> email_attributes, :addresses_attributes=> addresses_attributes, :phones_attributes=>phones_attributes.to_hash})}

    let(:email_attributes) { {"0"=>{"kind"=>"home", "address"=>"test@example.com"}}}
    let(:addresses_attributes) { {"0"=>{"kind"=>"home", "address_1"=>"address1", "address_2"=>"", "city"=>"city1", "state"=>"DC", "zip"=>"22211"},
                                  "1"=>{"kind"=>"mailing", "address_1"=>"address1", "address_2"=>"", "city"=>"city1", "state"=>"DC", "zip"=>"22211"}} }

    let!(:phones_attributes) {{"0"=>{"kind"=>"home", "full_phone_number"=>""},
                               "1"=>{"kind"=>"mobile", "full_phone_number"=>""},
                               "2"=>{"kind"=>"work", "full_phone_number"=>""},
                               "3"=>{"kind"=>"fax", "full_phone_number"=>""}}}
    before :each do
      allow(Person).to receive(:find).and_return(person)
      allow(Person).to receive(:where).and_return(Person)
      allow(Person).to receive(:first).and_return(person)
      allow(person).to receive(:phone_numbers_matched?).and_return true
      allow(person).to receive(:consumer_role).and_return(consumer_role)
      sign_in user
    end

    context "when update on demographic fields" do
      it 'should copy lastest submitted application on change in attributes' do
        allow(controller).to receive(:primary_mem_attr_changed?).and_return false
        allow(request).to receive(:referer).and_return("insured/families/personal")
        allow(person).to receive(:has_active_consumer_role?).and_return(true)
        post :update, id: person.id, person: person_attributes
        expect(family.applications.count).to eq 2
      end

      it 'should not copy application when in draft' do
        allow(controller).to receive(:primary_mem_attr_changed?).and_return false
        allow(person.primary_family).to receive(:application_in_progress).and_return true
        allow(request).to receive(:referer).and_return("insured/families/personal")
        allow(person).to receive(:has_active_consumer_role?).and_return(true)
        post :update, id: person.id, person: person_attributes
        expect(family.applications.count).to eq 1
      end

      it 'should not copy application when there are no applications'do
        family.applications = []
        allow(controller).to receive(:primary_mem_attr_changed?).and_return false
        allow(request).to receive(:referer).and_return("insured/families/personal")
        allow(person).to receive(:has_active_consumer_role?).and_return(true)
        post :update, id: person.id, person: person_attributes
        expect(family.applications.count).to eq 0
      end

    end
    end
end
