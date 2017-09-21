class FinancialAssistance::DeductionsController < ApplicationController

  before_action :set_current_person

  include UIHelpers::WorkflowController
  include NavigationHelper

  before_filter :find_application_and_applicant

  def index
    save_faa_bookmark(@person, request.original_url)
    render layout: 'financial_assistance'
  end

  def new
    @model = FinancialAssistance::Application.find(params[:application_id]).active_applicants.find(params[:applicant_id]).deductions.build
    load_steps
    current_step
    render 'workflow/step', layout: 'financial_assistance'
  end

  def step
    save_faa_bookmark(@person, request.original_url.gsub(/\/step.*/, "/step/#{@current_step.to_i}"))
    model_name = @model.class.to_s.split('::').last.downcase
    model_params = params[model_name]
    format_date_params model_params if model_params.present?
    @model.assign_attributes(permit_params(model_params)) if model_params.present?

    if params.key?(model_name)
      @model.workflow = { current_step: @current_step.to_i}
      @current_step = @current_step.next_step if @current_step.next_step.present?
    end

    if params.key?(model_name)
      if @model.save(context: "step_#{@current_step.to_i}".to_sym)
        if params.key? :last_step
          flash[:notice] = "Deduction Added - (#{@model.kind})"
          redirect_to financial_assistance_application_applicant_deductions_path(@application, @applicant)
        else
          render 'workflow/step', layout: 'financial_assistance'
        end
      else
        flash[:error] = build_error_messages(@model)
        render 'workflow/step', layout: 'financial_assistance'
      end
    else
      render 'workflow/step', layout: 'financial_assistance'
    end
  end

  def create
    @deduction = @applicant.deductions.build permit_params(params[:financial_assistance_deduction])

    if @deduction.save
      render :update, :locals => { kind: params[:financial_assistance_deduction][:kind]}
    else
      render :error
      flash[:error] = @deduction.errors.messages.first.flatten.flatten.join(',').gsub(",", " ").titleize
    end
  end

  def update
    @deduction = @applicant.deductions.find params[:id]
    if @deduction.update_attributes permit_params(params[:financial_assistance_deduction])
      render :update, :locals => { kind: params[:financial_assistance_deduction][:kind]}
    else
      render :error
    end
  end

  def destroy
    deduction = @applicant.deductions.find(params[:id])
    deduction.destroy!

    render head: 'ok'
  end

  private

  def format_date_params model_params
    model_params["start_on"]=Date.strptime(model_params["start_on"].to_s, "%m/%d/%Y") if model_params.present?
    model_params["end_on"]=Date.strptime(model_params["end_on"].to_s, "%m/%d/%Y") if model_params.present? && model_params["end_on"].present?
  end

  def build_error_messages(model)
    model.valid?("step_#{@current_step.to_i}".to_sym) ? nil : model.errors.messages.first[1][0].titleize
  end

  def find_application_and_applicant
    @application = FinancialAssistance::Application.find(params[:application_id])
    @applicant = @application.active_applicants.find(params[:applicant_id])
  end

  def find_application_and_applicant
    @application = FinancialAssistance::Application.find(params[:application_id])
    @applicant = @application.active_applicants.find(params[:applicant_id])
  end

  def permit_params(attributes)
    attributes.permit!
  end

  def find
    begin
      FinancialAssistance::Application.find(params[:application_id]).active_applicants.find(params[:applicant_id]).deductions.find(params[:id])
    rescue
      nil
    end
  end
end