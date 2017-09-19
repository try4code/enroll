module Notifier
  class NoticeKindsController < Notifier::ApplicationController

    layout 'notifier/single_column'

    def index
      @notice_kinds = Notifier::NoticeKind.all
      @datatable = Effective::Datatables::NoticesDatatable.new
      @errors = []
    end

    def show
      if params['id'] == 'upload_notices'
        redirect_to notice_kinds_path
      end
    end

    def new
      @notice_kind = Notifier::NoticeKind.new
      @notice_kind.template = Notifier::Template.new
    end

    def edit
      @notice_kind = Notifier::NoticeKind.find(params[:id])
      render :layout => 'notifier/application'
    end

    def create
      template = Template.new(notice_params.delete('template'))
      notice_kind = NoticeKind.new(notice_params)
      notice_kind.template = template

      if notice_kind.save
        flash[:notice] = 'Notice created successfully'
      end
      redirect_to notice_kinds_path
    end

    def update
      notice_kind = Notifier::NoticeKind.find(params['id'])
      notice_kind.update_attributes(notice_params)

      flash[:notice] = 'Notice content updated successfully'
      redirect_to notice_kinds_path
    end

    def preview
      notice_kind = Notifier::NoticeKind.find(params[:id])
      notice_kind.generate_pdf_notice

      send_file "#{Rails.root}/public/NoticeTemplate.pdf", 
        :type => 'application/pdf', 
        :disposition => 'inline'
    end

    def delete_notices
      Notifier::NoticeKind.where(:id.in => params['ids']).each do |notice|
        notice.delete
      end

      flash[:notice] = 'Notices deleted successfully'
      redirect_to notice_kinds_path
    end

    def download_notices
      notices = Notifier::NoticeKind.where(:id.in => params['ids'])

      send_data Notifier::NoticeKind.to_csv, 
        :filename => "notices_#{TimeKeeper.date_of_record.strftime('%m_%d_%Y')}.csv",
        :disposition => 'attachment',
        :type => 'text/csv'
    end

    def upload_notices
      notices = Roo::Spreadsheet.open(params[:file].tempfile.path)
      @errors = []

      notices.each do |notice_row|
        next if notice_row[0] == 'Notice Number'

        if Notifier::NoticeKind.where(notice_number: notice_row[0]).blank?
          notice = Notifier::NoticeKind.new(notice_number: notice_row[0], title: notice_row[1], description: notice_row[2])
          notice.template = Template.new(raw_body: notice_row[3])
          notice.save
        else
          @errors << "Notice #{notice_row[0]} already exists."
        end
      end

      if @errors.empty?
        flash[:notice] = 'Notices loaded successfully.'
      end

      @notice_kinds = Notifier::NoticeKind.all
      @datatable = Effective::Datatables::NoticesDatatable.new

      render :action => 'index'
    end

    def get_tokens
      builder = params['builder'] || 'Notifier::MergeDataModels::EmployerProfile'
      tokens = builder.constantize.new.editor_tokens

      respond_to do |format|
        format.html
        format.json {render json: tokens}
      end
    end

    def get_placeholders
      placeholders = Notifier::MergeDataModels::EmployerProfile.new.place_holders

      respond_to do |format|
        format.html
        format.json {render json: placeholders}
      end
    end

    private

    def notice_params
      params.require(:notice_kind).permit(:title, :description, :notice_number, :receipient, {:template => [:raw_body]})
    end
  end
end