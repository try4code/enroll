
module Effective
  module Datatables
    class OutstandingVerificationDataTable < Effective::MongoidDatatable
      datatable do
        #table_column :family_hbx_id, :proc => Proc.new { |row| row.hbx_assigned_id }, :filter => false, :sql_column => "hbx_id"
        table_column :name, :label => 'Name', :proc => Proc.new { |row| link_to row.primary_applicant.person.full_name, resume_enrollment_exchanges_agents_path(person_id: row.primary_applicant.person.id)}, :filter => false, :sortable => false
        table_column :ssn, :label => 'SSN', :proc => Proc.new { |row| truncate(number_to_obscured_ssn(row.primary_applicant.person.ssn)) }, :filter => false, :sortable => false
        table_column :dob, :label => 'DOB', :proc => Proc.new { |row| format_date(row.primary_applicant.person.dob)}, :filter => false, :sortable => false
        table_column :hbx_id, :label => 'HBX ID', :proc => Proc.new { |row| row.primary_applicant.person.hbx_id }, :filter => false, :sortable => false
        table_column :count, :label => 'Count', :width => '100px', :proc => Proc.new { |row| row.active_family_members.size }, :filter => false, :sortable => false
        table_column :documents_uploaded, :label => 'Documents Uploaded', :proc => Proc.new { |row| "Fully Uploaded"}, :filter => false, :sortable => false
        table_column :verification_due, :label => 'Verification Due',:proc => Proc.new { |row|  TimeKeeper.row.date_of_record}, :filter => false, :sortable => false
         table_column :actions, :width => '50px', :proc => Proc.new { |row|
          dropdown = [
           ["Review", show_docs_documents_path(:person_id => row.primary_applicant.person.id)]
          ]
        }, :filter => false, :sortable => false
      end

      scopes do
         scope :legal_name, "Hello"
      end

      def collection
        unless  (defined? @families) && @families.present?   #memoize the wrapper class to persist @search_string
          @families = Family.by_enrollment_individual_market.where(:'households.hbx_enrollments.aasm_state' => "enrolled_contingent")
          #@families = Family.by_enrollment_individual_market.where(:'households.hbx_enrollments.aasm_state' => "enrolled_contingent").send(attributes[:documents_uploaded]) if attributes[:documents_uploaded].present?
        end
        @families
      end

      def global_search?
        true
      end


      def search_column(collection, table_column, search_term, sql_column)
          super
      end

      def nested_filter_definition
        filters = {
        documents_uploaded: [
          {scope: 'none_uploaded', label: 'None Uploaded'},
          {scope: 'partially_uploaded', label: 'Partially Uploaded'},
          {scope: 'fully_uploaded', label: 'Fully Uploaded'},
          {scope: 'all', label: 'All'},
        ],
        top_scope: :documents_uploaded
        }
      end
    end
  end
end
