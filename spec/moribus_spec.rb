require "spec_helper"

describe Moribus do
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

    class SpecCustomerFeature < MoribusSpecModel(feature_name: :string)
      acts_as_aggregated cache_by: :feature_name
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

    class SpecCustomerInfoWithType < MoribusSpecModel(
      spec_customer_id: :integer!,
      spec_status_id:   :integer,
      spec_type_id:     :integer,
      is_current:       :boolean,
      lock_version:     :integer,
      created_at:       :datetime,
      updated_at:       :datetime
    )
      attr :custom_field

      belongs_to :spec_customer, inverse_of: :spec_customer_info_with_type, touch: true
      has_enumerated :spec_status
      has_enumerated :spec_type

      acts_as_tracked :by => [:spec_customer, :spec_type]
    end

    class SpecCustomer < MoribusSpecModel(spec_status_id: :integer)
      has_one_current :spec_customer_info, inverse_of: :spec_customer
      has_one_current :spec_customer_info_with_type, inverse_of: :spec_customer
      has_enumerated :spec_status, default: "inactive"

      delegate_associated :spec_person_name, :custom_field, :spec_type, to: :spec_customer_info
    end

    class SpecCustomerEmail < MoribusSpecModel(spec_customer_id: :integer,
                                               email:            :string,
                                               is_current:       :boolean,
                                               status:           :string
    )
      connection.add_index table_name, [:email, :is_current], unique: true

      belongs_to :spec_customer

      acts_as_tracked
    end
  end

  after do
    MoribusSpecModel.cleanup!
  end

  describe "common behavior" do
    before do
      @info = SpecCustomerInfo.create(
        spec_customer_id:    1,
        spec_person_name_id: 1,
        is_current:          true,
        created_at:          5.days.ago,
        updated_at:          5.days.ago
      )
    end

    it "reverts changes if exception is raised" do
      old_id         = @info.id
      old_updated_at = @info.updated_at
      old_created_at = @info.created_at

      suppress(Exception) do
        expect {
          @info.update! spec_customer_id: nil, spec_person_name_id: 2
        }.not_to change(SpecCustomerInfo, :count)
      end

      expect(@info.new_record?).to eq false
      expect(@info.id         ).to eq old_id
      expect(@info.updated_at ).to eq old_updated_at
      expect(@info.created_at ).to eq old_created_at

      expect(@info.changed_attributes[:updated_at]).to eq(nil)
      expect(@info.changed_attributes[:created_at]).to eq(nil)
    end

    it "has module included class check methods" do
      expect(SpecCustomerFeature.acts_as_aggregated?).to be_truthy
      expect(SpecCustomerEmail.acts_as_tracked?).to be_truthy
    end
  end

  describe "Tracked" do
    before do
      @customer = SpecCustomer.create
      @info = @customer.create_spec_customer_info spec_person_name_id: 1
    end

    it "creates a new current record if updated" do
      expect {
        @info.update!(spec_person_name_id: 2)
      }.to change(SpecCustomerInfo, :count).by(1)
    end

    it "replaces itself with new id" do
      old_id = @info.id
      @info.update!(spec_person_name_id: 2)
      expect(@info.id).not_to eq old_id
    end

    it "sets is_current record to false for superseded record" do
      old_id = @info.id
      @info.update!(spec_person_name_id: 2)
      expect(SpecCustomerInfo.find(old_id).is_current).to eq false
    end

    it "sets previous_id to the id of the previous record" do
      old_id = @info.id
      @info.update!(spec_person_name_id: 2)
      expect(@info.previous_id).to eq old_id
    end

    it "changes is_current to false for previous one when assigning a new current record" do
      new_info = SpecCustomerInfo.new spec_person_name_id: 2, is_current: true
      @customer.spec_customer_info = new_info
      expect(new_info.spec_customer_id).to eq @customer.id
      @info.reload
      expect(@info.is_current         ).to eq false
    end

    it "does not crash on superseding with 'is_current' conditional constraint" do
      email = SpecCustomerEmail.create( spec_customer: @customer,
                                        email:         "foo@bar.com",
                                        status:        "unverified",
                                        is_current:    true
      )
      expect{ email.update!(status: "verified") }.not_to raise_error
    end

    describe "updated_at and created_at" do
      let(:first_time)  { Time.zone.parse("2012-07-16 00:00:00") }
      let(:second_time) { Time.zone.parse("2012-07-17 08:10:15") }

      before { Timecop.freeze(first_time) }
      after  { Timecop.return             }

      it "is updated on change" do
        info = @customer.create_spec_customer_info spec_person_name_id: 1
        expect(info.updated_at).to eq first_time
        expect(info.created_at).to eq first_time

        Timecop.freeze(second_time)
        info.spec_person_name_id = 2
        info.save!
        expect(info.updated_at).to eq second_time
        expect(info.created_at).to eq second_time
      end
    end

    describe "Optimistic Locking" do
      before do
        @info1 = @customer.reload.spec_customer_info
        @info2 = @customer.reload.spec_customer_info
      end

      it "raises a stale object error" do
        @info1.update!(spec_person_name_id: 3)

        expect{ @info2.update!(spec_person_name_id: 4) }.
          to raise_error(ActiveRecord::StaleObjectError,
                         /Attempted to update_current \(version #{@info2.lock_version}\) a stale object: SpecCustomerInfo\./)
      end

      it "updates lock_version incrementally for each new record" do
        spec_customer_info = @customer.spec_customer_info

        expect {
          spec_customer_info.update!(spec_person_name_id: 3)
        }.to change { spec_customer_info.lock_version }.from(0).to(1)

        expect {
          spec_customer_info.update!(spec_person_name_id: 4)
        }.to change { spec_customer_info.lock_version }.from(1).to(2)
      end

      it "does not fail to update if a lock version growth is for any reason not monotonic" do
        spec_customer_info = @customer.spec_customer_info

        spec_customer_info.update!(spec_person_name_id: 3)
        spec_customer_info.update!(spec_person_name_id: 4)

        SpecCustomerInfo.where(spec_customer_id: @customer.id, lock_version: 1).delete_all

        expect {
          spec_customer_info.update!(spec_person_name_id: 5)
        }.to change { spec_customer_info.lock_version }.from(2).to(3)
      end

      it "does not fail if no locking_column is present" do
        email = SpecCustomerEmail.create(spec_customer_id: 1, email: "foo@bar.com")
        expect{ email.update!(email: "foo2@bar.com") }.not_to raise_error
      end

      it "updates lock_version column based on parent relation" do
        @other_customer = SpecCustomer.create
        spec_customer_info = @customer.spec_customer_info

        expect {
          spec_customer_info.update!(spec_person_name_id: 3)
        }.to change { spec_customer_info.lock_version }.from(0).to(1)

        expect {
          spec_customer_info.update!(spec_customer: @other_customer)
        }.to change { spec_customer_info.lock_version }.from(1).to(0)
      end

      it "updates lock_version column base on relation list from 'by' option" do
        info_with_type =
          @customer.reload.create_spec_customer_info_with_type(spec_type: :important)

        expect( info_with_type.lock_version ).to eq 0

        other_info_with_type =
          @customer.reload.create_spec_customer_info_with_type(spec_type: :unimportant)

        expect( other_info_with_type.lock_version ).to eq 0

        info_with_type.update!(spec_status: :active)
        expect( info_with_type.lock_version ).to eq 1

        info_with_type.update!(spec_status: :inactive)
        expect( info_with_type.lock_version ).to eq 2

        expect( other_info_with_type.lock_version ).to eq 0
      end
    end

    describe "with Aggregated" do
      before do
        @info.spec_person_name =
          SpecPersonName.create(first_name: "John", last_name: "Smith")
        @info.save
        @info.reload
      end

      it "supersedes when nested record changes" do
        old_id = @info.id
        @customer.spec_customer_info.spec_person_name.first_name = "Alice"
        expect{ @customer.save }.to change(@info, :spec_person_name_id)

        expect(@info.id        ).not_to eq old_id
        expect(@info.is_current).to     eq true

        expect(SpecCustomerInfo.find(old_id).is_current).to eq false
      end
    end
  end
end
