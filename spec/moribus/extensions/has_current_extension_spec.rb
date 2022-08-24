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
      delegate_associated :previous_id, to: :spec_customer_info
    end
  end

  after do
    MoribusSpecModel.cleanup!
  end

  let(:customer) { SpecCustomer.create }
  let!(:info) do
    SpecCustomerInfo.create(spec_customer: customer, is_current: true, created_at: 1.hour.ago, updated_at: 1.hour.ago)
  end

  describe ".remove_target!" do
    context "new record" do
      before do
        allow(customer.spec_customer_info).to receive(:new_record?).and_return(true)
      end

      it "sets 'is_current' flag of overridden record to false for new record" do
        old_info = customer.spec_customer_info
        customer.spec_customer_info = SpecCustomerInfo.new
        expect(old_info.is_current).to be false
      end

      it "sets 'is_current' flag updates updated_at column" do
        old_info = customer.spec_customer_info
        customer.spec_customer_info = SpecCustomerInfo.new
        expect(old_info.updated_at >= old_info.created_at + 1.hour).to be true
      end
    end

    context "persisted record" do
      it "sets 'is_current' flag updates updated_at column" do
        old_info = customer.spec_customer_info
        customer.spec_customer_info = SpecCustomerInfo.new
        old_info.reload
        # I use 59 minutes instead of hour because there can be small difference in milliseconds
        expect(old_info.updated_at >= old_info.created_at + 59.minutes).to be true
      end

      it "sets 'is_current' flag updates updated_at column" do
        old_info = customer.spec_customer_info
        customer.update!(previous_id: 123)
        old_info.reload
        # I use 59 minutes instead of hour because there can be small difference in milliseconds
        expect(old_info.updated_at >= old_info.created_at + 59.minutes).to be true
      end
    end
  end
end
