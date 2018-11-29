require "spec_helper"

describe Moribus::Extensions::HasCurrentExtension do
  before do
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

    class SpecCustomer < MoribusSpecModel(spec_status_id: :integer)
      has_one_current :spec_customer_info, inverse_of: :spec_customer, dependent: :destroy
    end
  end

  after do
    MoribusSpecModel.cleanup!
  end

  let(:customer) { SpecCustomer.create }
  let!(:info)    { SpecCustomerInfo.create(spec_customer: customer, is_current: true) }

  describe ".remove_target!" do
    before do
      allow(customer.spec_customer_info).to receive(:new_record?).and_return(true)
    end

    it "sets 'is_current' flag of overridden record to false for new record" do
      old_info = customer.spec_customer_info
      customer.spec_customer_info = SpecCustomerInfo.new
      expect(old_info.is_current).to be_falsey
    end
  end
end
