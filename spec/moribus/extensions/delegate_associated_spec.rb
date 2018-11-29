require "spec_helper"

describe Moribus::Extensions::DelegateAssociated do
  before do
    class SpecStatus < MoribusSpecModel(name: :string, description: :string)
      acts_as_enumerated

      self.enumeration_model_updates_permitted = true
      create!(name: "inactive", description: "Inactive")
      create!(name: "active"  , description: "Active")
    end

    class SpecType < MoribusSpecModel(name: :string, description: :string)
      acts_as_enumerated

      self.enumeration_model_updates_permitted = true
      create!(name: "important"  , description: "Important")
      create!(name: "unimportant", description: "Unimportant")
    end

    class SpecSuffix < MoribusSpecModel(name: :string, description: :string)
      acts_as_enumerated

      self.enumeration_model_updates_permitted = true
      create!(name: "none", description: "")
      create!(name: "jr"  , description: "Junior")
    end

    class SpecPersonName < MoribusSpecModel(first_name:     :string,
                                            middle_name:    :string,
                                            last_name:      :string,
                                            spec_suffix_id: :integer
                                          )
      acts_as_aggregated non_content_columns: :middle_name
      has_enumerated :spec_suffix, default: ""

      validates_presence_of :first_name, :last_name

      # custom writer that additionally strips first name
      def first_name=(value)
        self[:first_name] = value.strip
      end
    end

    class SpecCustomerInfo < MoribusSpecModel(
                                        spec_customer_id:    :integer!,
                                        spec_person_name_id: :integer,
                                        spec_status_id:      :integer,
                                        spec_type_id:        :integer,
                                        is_current:          :boolean,
                                        lock_version:        :integer,
                                        created_at:          :datetime,
                                        updated_at:          :datetime,
                                        previous_id:         :integer
                              )
      attr :custom_field

      belongs_to :spec_customer, inverse_of: :spec_customer_info, touch: true
      has_aggregated :spec_person_name
      has_enumerated :spec_status
      has_enumerated :spec_type

      acts_as_tracked by: :spec_customer, preceding_key: :previous_id
    end

    class SpecCustomer < MoribusSpecModel(spec_status_id: :integer)
      has_one_current :spec_customer_info, inverse_of: :spec_customer
      has_one_current :spec_customer_info_with_type, inverse_of: :spec_customer
      has_enumerated :spec_status, default: "inactive"

      delegate_associated :spec_person_name, :custom_field, :spec_type, to: :spec_customer_info
    end
  end

  after do
    MoribusSpecModel.cleanup!
  end

  let!(:customer) do
    SpecCustomer.create(
      spec_customer_info_attributes: {
        spec_person_name_attributes: { first_name: " John ", last_name: "Smith" }
      }
    )
  end

  let(:info) { customer.spec_customer_info }

  describe "Delegations" do
    it "has delegated column information" do
      expect(customer.column_for_attribute(:first_name)).not_to be_nil
    end

    it "does not delegate special methods" do
      expect(customer).not_to respond_to(:reset_first_name)
      expect(customer).not_to respond_to(:first_name_was)
      expect(customer).not_to respond_to(:first_name_before_type_cast)
      expect(customer).not_to respond_to(:first_name_will_change!)
      expect(customer).not_to respond_to(:first_name_changed?)
      expect(customer).not_to respond_to(:lock_version)
    end

    it "delegates methods to aggregated parts" do
      expect(info).to respond_to(:first_name)
      expect(info).to respond_to(:first_name=)
      expect(info).to respond_to(:spec_suffix)
      expect(info.last_name).to eq "Smith"
    end

    it "delegates methods to representation" do
      expect(customer).to respond_to(:first_name)
      expect(customer).to respond_to(:first_name=)
      expect(customer).to respond_to(:spec_suffix)
      expect(customer.last_name).to eq "Smith"
      expect(customer).to respond_to(:custom_field)
      expect(customer).to respond_to(:custom_field=)
    end

    it "properly delegates enumerated attributes" do
      expect(customer).to respond_to(:spec_type)
      expect(customer).to respond_to(:spec_type=)
      customer.spec_type = :important
      expect(customer.spec_type === :important).to eq true
    end

    it "raises NoMethodError if unknown method is received" do
      expect{ customer.impossibru }.to raise_error(NoMethodError)
    end
  end

  describe "#column_for_attribute" do
    it "returns class db column if it exists" do
      expect(customer.column_for_attribute(:id)).not_to be_nil
    end
  end
end
