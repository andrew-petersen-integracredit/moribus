require "spec_helper"

# Some of the Moribus::Macros methods are tested in
# spec/lib/moribus_spec.rb.
describe Moribus::Macros do
  before do
    class SpecCustomer < MoribusSpecModel(spec_status_id: :integer)
      has_one_current :spec_customer_info,
        -> { where(spec_customer_id: 3) }, inverse_of: :spec_customer
    end

    class SpecCustomerInfo < MoribusSpecModel(
                                                spec_customer_id: :integer!,
                                                is_current:       :boolean,
                                                lock_version:     :integer,
                                                created_at:       :datetime,
                                                updated_at:       :datetime,
                                                previous_id:      :integer
                                              )

      belongs_to :spec_customer, inverse_of: :spec_customer_info, touch: true
    end

    class SpecCustomerOrder < MoribusSpecModel(:spec_status_id => :integer)
      has_one_current :spec_customer_info_order,
        -> { order(:created_at) }, :inverse_of => :spec_customer_order
    end

    class SpecCustomerInfoOrder < MoribusSpecModel(
                                                spec_customer_order_id: :integer!,
                                                is_current:             :boolean,
                                                lock_version:           :integer,
                                                created_at:             :datetime,
                                                updated_at:             :datetime,
                                                previous_id:            :integer
                                              )

      belongs_to :spec_customer_order, inverse_of: :spec_customer_info_order, touch: true
    end
  end

  after do
    MoribusSpecModel.cleanup!
  end

  describe ".has_one_current" do
    let!(:customer)       { SpecCustomer.create(id: 3, spec_status_id: 2) }
    let!(:customer_order) { SpecCustomerOrder.create(id: 9, spec_status_id: 1) }

    let!(:info1) do
      SpecCustomerInfo.create(
        spec_customer_id: 1,
        is_current:       true,
        created_at:       5.days.ago,
        updated_at:       5.days.ago
      )
    end

    let!(:info2) do
      SpecCustomerInfo.create(
        spec_customer_id: 3,
        is_current:       true,
        created_at:       5.days.ago,
        updated_at:       5.days.ago
      )
    end

    let!(:info_order1) do
      SpecCustomerInfoOrder.create(
        spec_customer_order_id: 9,
        is_current:             true,
        created_at:             5.days.ago,
        updated_at:             5.days.ago
      )
    end

    let!(:info_order2) do
      SpecCustomerInfoOrder.create(
        spec_customer_order_id: 11,
        is_current:             true,
        created_at:             5.days.ago,
        updated_at:             5.days.ago
      )
    end

    it "merges has_one_current scope with has_one if given" do
      expect(customer.spec_customer_info            ).to eq(info2)
      expect(customer_order.spec_customer_info_order).to eq(info_order1)
    end
  end

  describe ".normalize_reflection" do
    subject do
      SpecCustomer.send(:normalize_reflection, { spec_customer_info: :key_value }, :spec_customer_info)
    end

    it "returns reflection with symbol key for rails 4.1" do
      is_expected.to eq(:key_value)
    end
  end
end
