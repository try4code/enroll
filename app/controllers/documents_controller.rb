class DocumentsController < ApplicationController
  before_action :updateable?, except: [:show_docs, :download]
  before_action :set_document, only: [:destroy, :update]
  before_action :set_person, only: [:enrollment_docs_state, :fed_hub_request, :enrollment_verification, :update_verification_type]
  respond_to :html, :js

  def download
    bucket = params[:bucket]
    key = params[:key]
    uri = "urn:openhbx:terms:v1:file_storage:s3:bucket:#{bucket}##{key}"
    send_data Aws::S3Storage.find(uri), get_options(params)
  end

  def authorized_download
    begin
      model = params[:model].camelize
      model_id = params[:model_id]
      relation = params[:relation]
      relation_id = params[:relation_id]
      model_object = Object.const_get(model).find(model_id)
      documents = model_object.send(relation.to_sym)
      if authorized_to_download?(model_object, documents, relation_id)
        uri = documents.find(relation_id).identifier
        send_data Aws::S3Storage.find(uri), get_options(params)
      else
       raise "Sorry! You are not authorized to download this document."
      end
    rescue => e
      redirect_to(:back, :flash => {error: e.message})
    end
  end

  def update_verification_type
    v_type = params[:verification_type]
    update_reason = params[:verification_reason]
    admin_action = params[:admin_action]
    family_member = FamilyMember.find(params[:family_member_id]) if params[:family_member_id].present?
    reasons_list = VlpDocument::VERIFICATION_REASONS + VlpDocument::ALL_TYPES_REJECT_REASONS + VlpDocument::CITIZEN_IMMIGR_TYPE_ADD_REASONS
    if (reasons_list).include? (update_reason)
      verification_result = @person.consumer_role.admin_verification_action(admin_action, v_type, update_reason)
      message = (verification_result.is_a? String) ? verification_result : "Person verification successfully approved."
      flash_message = { :success => message}
      update_documents_status(family_member) if family_member
    else
      flash_message = { :error => "Please provide a verification reason."}
    end

    respond_to do |format|
      format.html { redirect_to :back, :flash => flash_message }
    end
  end

  def enrollment_verification
     family = @person.primary_family
     if family.active_household.hbx_enrollments.verification_needed.any?
       family.active_household.hbx_enrollments.verification_needed.each do |enrollment|
         enrollment.evaluate_individual_market_eligiblity
       end
       family.save!
       respond_to do |format|
         format.html {
           flash[:success] = "Enrollment group was completely verified."
           redirect_to :back
         }
       end
     else
       respond_to do |format|
         format.html {
           flash[:danger] = "Family does not have any active Enrollment to verify."
           redirect_to :back
         }
       end
     end
  end

  def fed_hub_request
    @person.consumer_role.redetermine!(verification_attr)
    respond_to do |format|
      format.html {
        flash[:success] = "Request was sent to FedHub."
        redirect_to :back
      }
      format.js
    end
  end

  def show_docs
    if current_user.has_hbx_staff_role?
      session[:person_id] = params[:person_id]
      set_current_person
      @person.primary_family.active_household.hbx_enrollments.verification_needed.each do |enrollment|
        enrollment.update_attributes(:review_status => "in review")
      end
    end
    redirect_to verification_insured_families_path
  end

  def extend_due_date
    @family_member = FamilyMember.find(params[:family_member_id])
    v_type = params[:verification_type]
    enrollment = @family_member.family.enrollments.verification_needed.where(:"hbx_enrollment_members.applicant_id" => @family_member.id).first
    if enrollment.present?
      sv = @family_member.person.consumer_role.special_verifications.where(:"verification_type" => v_type).order_by(:"created_at".desc).first
      if sv.present?
        new_date = sv.due_date.to_date + 30.days
        flash[:success] = "Special verification period was extended for 30 days."
      elsif enrollment.special_verification_period
        new_date = enrollment.special_verification_period.to_date + 30.days
        flash[:success] = "Special verification period was extended for 30 days."
      else
        new_date = (enrollment.submitted_at.to_date + 95.days) + 30.days
        flash[:success] = "You set special verification period for this Enrollment. Verification due date now is #{new_date.to_date}"
      end

      # special_verification_period is the day we send notices
      # enrollment.update_attributes!(:special_verification_period => new_date)
      sv = SpecialVerification.new(due_date: new_date, verification_type: v_type, updated_by: current_user.id, type: "admin")
      @family_member.person.consumer_role.special_verifications << sv
      @family_member.person.consumer_role.save!
      set_min_due_date_on_family
    else
      flash[:danger] = "Family Member does not have any unverified Enrollment to extend verification due date."
    end
    redirect_to :back
  end

  def destroy
    @document.delete
    respond_to do |format|
      format.html { redirect_to verification_insured_families_path }
      format.js
    end

  end

  def update
    if params[:comment]
      @document.update_attributes(:status => params[:status],
                                  :comment => params[:person][:vlp_document][:comment])
    else
      @document.update_attributes(:status => params[:status])
    end
    respond_to do |format|
      format.html {redirect_to verification_insured_families_path, notice: "Document Status Updated"}
      format.js
    end
  end

  private
  def updateable?
    authorize Family, :updateable?
  end

  def get_options(params)
    options = {}
    options[:content_type] = params[:content_type] if params[:content_type]
    options[:filename] = params[:filename] if params[:filename]
    options[:disposition] = params[:disposition] if params[:disposition]
    options
  end

  def authorized_to_download?(owner, documents, document_id)
    return true
    owner.user.has_hbx_staff_role? || documents.find(document_id).present?
  end

  def update_documents_status(family_member)
    family = family_member.family
    family.update_family_document_status!
  end

  def set_document
    set_person
    @document = @person.consumer_role.vlp_documents.find(params[:id])
  end

  def set_person
    @person = Person.find(params[:person_id])
  end

  def verification_attr
    OpenStruct.new({:determined_at => Time.now,
                    :authority => "hbx"
                   })
  end

  def set_min_due_date_on_family
    family = @family_member.family
    family.update_attributes(min_verification_due_date: family.min_verification_due_date_on_family)
  end
end
