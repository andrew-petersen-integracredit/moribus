require "spec_helper"

describe Moribus do
  before do
    class SpecStatus < MoribusSpecModel(:name => :string, :description => :string)
      acts_as_enumerated

      self.enumeration_model_updates_permitted = true
      create!(:name => "inactive", :description => "Inactive")
      create!(:name => "active"  , :description => "Active")
    end

    class SpecType < MoribusSpecModel(:name => :string, :description => :string)
      acts_as_enumerated

      self.enumeration_model_updates_permitted = true
      create!(:name => "important"  , :description => "Important")
      create!(:name => "unimportant", :description => "Unimportant")
    end

    class SpecSuffix < MoribusSpecModel(:name => :string, :description => :string)
      acts_as_enumerated

      self.enumeration_model_updates_permitted = true
      create!(:name => "none", :description => "")
      create!(:name => "jr"  , :description => "Junior")
    end

    class SpecPersonName < MoribusSpecModel(:first_name => :string, :last_name => :string, :spec_suffix_id => :integer)
      acts_as_aggregated
      has_enumerated :spec_suffix, :default => ""

      validates_presence_of :first_name, :last_name

      # custom writer that additionally strips first name
      def first_name=(value)
        self[:first_name] = value.strip
      end
    end

    class SpecCustomerFeature < MoribusSpecModel(:feature_name => :string)
      acts_as_aggregated :cache_by => :feature_name
    end

    class SpecCustomerInfo < MoribusSpecModel(
                                        :spec_customer_id    => :integer!,
                                        :spec_person_name_id => :integer,
                                        :spec_status_id      => :integer,
                                        :spec_type_id        => :integer,
                                        :is_current          => :boolean,
                                        :lock_version        => :integer,
                                        :created_at          => :datetime,
                                        :updated_at          => :datetime,
                                        :previous_id         => :integer
                              )
      attr :custom_field

      belongs_to :spec_customer, :inverse_of => :spec_customer_info, :touch => true
      has_aggregated :spec_person_name
      has_enumerated :spec_status
      has_enumerated :spec_type

      acts_as_tracked :by => :spec_customer, :preceding_key => :previous_id
    end

    class SpecCustomerInfoWithType < MoribusSpecModel(
                                        :spec_customer_id    => :integer!,
                                        :spec_status_id      => :integer,
                                        :spec_type_id        => :integer,
                                        :is_current          => :boolean,
                                        :lock_version        => :integer,
                                        :created_at          => :datetime,
                                        :updated_at          => :datetime
                                      )
      attr :custom_field

      belongs_to :spec_customer, :inverse_of => :spec_customer_info_with_type, :touch => true
      has_enumerated :spec_status
      has_enumerated :spec_type

      acts_as_tracked :by => [:spec_customer, :spec_type]
    end

    class SpecCustomer < MoribusSpecModel(:spec_status_id => :integer)
      has_one_current :spec_customer_info, :inverse_of => :spec_customer
      has_one_current :spec_customer_info_with_type, :inverse_of => :spec_customer
      has_enumerated :spec_status, :default => "inactive"

      delegate_associated :spec_person_name, :custom_field, :spec_type, :to => :spec_customer_info
    end

    class SpecCustomerEmail < MoribusSpecModel(:spec_customer_id => :integer, :email => :string, :is_current => :boolean, :status => :string)
      connection.add_index table_name, [:email, :is_current], :unique => true

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
        :spec_customer_id    => 1,
        :spec_person_name_id => 1,
        :is_current          => true,
        :created_at          => 5.days.ago,
        :updated_at          => 5.days.ago
      )
    end

    it "should revert changes if exception is raised" do
      old_id         = @info.id
      old_updated_at = @info.updated_at
      old_created_at = @info.created_at

      suppress(Exception) do
        expect {
          @info.update_attributes :spec_customer_id => nil, :spec_person_name_id => 2
        }.not_to change(SpecCustomerInfo, :count)
      end
      expect(@info.new_record?).to eq false
      expect(@info.id         ).to eq old_id
      expect(@info.updated_at ).to eq old_updated_at
      expect(@info.created_at ).to eq old_created_at
    end
  end

  describe "Aggregated" do
    context "definition" do
      it "should raise an error on an unknown option" do
        expect{
          Class.new(ActiveRecord::Base).class_eval do
            acts_as_aggregated :invalid_key => :error
          end
        }.to raise_error(ArgumentError)
      end

      it "should raise an error when including AggregatedCacheBehavior without AggregatedBehavior" do
        expect{
          Class.new(ActiveRecord::Base).class_eval do
            include Moribus::AggregatedCacheBehavior
          end
        }.to raise_error(Moribus::AggregatedCacheBehavior::NotAggregatedError)
      end
    end

    before do
      @existing = SpecPersonName.create! :first_name => "John", :last_name => "Smith"
    end

    it "should not duplicate records" do
      expect {
        SpecPersonName.create :first_name => " John ", :last_name => "Smith"
      }.not_to change(SpecPersonName, :count)
    end

    it "should lookup self and replace id with existing on create" do
      name = SpecPersonName.new :first_name => "John", :last_name => "Smith"
      name.save
      expect(name.id).to eq @existing.id
    end

    it "should create a new record if lookup fails" do
      expect {
        SpecPersonName.create :first_name => "Alice", :last_name => "Smith"
      }.to change(SpecPersonName, :count).by(1)
    end

    it "should lookup self and replace id with existing on update" do
      name = SpecPersonName.create :first_name => "Alice", :last_name => "Smith"
      name.update_attributes :first_name => "John"
      expect(name.id).to eq @existing.id
    end

    context "with caching" do
      before do
        @existing = SpecCustomerFeature.create(:feature_name => "Pays")
        SpecCustomerFeature.clear_cache
      end

      it "should lookup the existing value and add it to the cache" do
        feature = SpecCustomerFeature.new :feature_name => @existing.feature_name

        expect{ feature.save }.
          to change(SpecCustomerFeature.aggregated_records_cache, :length).by(1)

        expect(feature.id).to eq @existing.id
      end

      it "should add the freshly-created record to the cache" do
        expect{ SpecCustomerFeature.create(:feature_name => "Fraud") }.
          to change(SpecCustomerFeature.aggregated_records_cache, :length).by(1)
      end

      it "should freeze the cached object" do
        feature = SpecCustomerFeature.create(:feature_name => "Cancelled")
        expect(SpecCustomerFeature.aggregated_records_cache[feature.feature_name]).to be_frozen
      end

      it "should cache the clone of the record, not the record itself" do
        feature = SpecCustomerFeature.create(:feature_name => "Returned")
        expect(SpecCustomerFeature.aggregated_records_cache[feature.feature_name].object_id).
          not_to eq feature.object_id
      end
    end
  end

  describe "Tracked" do
    before do
      @customer = SpecCustomer.create
      @info = @customer.create_spec_customer_info :spec_person_name_id => 1
    end

    it "should create a new current record if updated" do
      expect {
        @info.update_attributes(:spec_person_name_id => 2)
      }.to change(SpecCustomerInfo, :count).by(1)
    end

    it "should replace itself with new id" do
      old_id = @info.id
      @info.update_attributes(:spec_person_name_id => 2)
      expect(@info.id).not_to eq old_id
    end

    it "should set is_current record to false for superseded record" do
      old_id = @info.id
      @info.update_attributes(:spec_person_name_id => 2)
      expect(SpecCustomerInfo.find(old_id).is_current).to eq false
    end

    it "should set previous_id to the id of the previous record" do
      old_id = @info.id
      @info.update_attributes(:spec_person_name_id => 2)
      expect(@info.previous_id).to eq old_id
    end

    it "assigning a new current record should change is_current to false for previous one" do
      new_info = SpecCustomerInfo.new :spec_person_name_id => 2, :is_current => true
      @customer.spec_customer_info = new_info
      expect(new_info.spec_customer_id).to eq @customer.id
      @info.reload
      expect(@info.is_current         ).to eq false
    end

    it "should not crash on superseding with "is_current" conditional constraint" do
      email = SpecCustomerEmail.create( :spec_customer => @customer,
                                        :email         => "foo@bar.com",
                                        :status        => "unverified",
                                        :is_current    => true
                                      )
      expect{ email.update_attributes(:status => "verified") }.not_to raise_error
    end

    describe "updated_at and created_at" do
      let(:first_time)  { Time.zone.parse("2012-07-16 00:00:00") }
      let(:second_time) { Time.zone.parse("2012-07-17 08:10:15") }

      before { Timecop.freeze(first_time) }
      after  { Timecop.return             }

      it "should be updated on change" do
        info = @customer.create_spec_customer_info :spec_person_name_id => 1
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

      it "should raise stale object error" do
        @info1.update_attributes(:spec_person_name_id => 3)

        expect{ @info2.update_attributes(:spec_person_name_id => 4) }.to raise_error(ActiveRecord::StaleObjectError)
      end

      it "updates lock_version incrementally for each new record" do
        spec_customer_info = @customer.spec_customer_info

        expect {
          spec_customer_info.update_attributes(:spec_person_name_id => 3)
        }.to change { spec_customer_info.lock_version }.from(0).to(1)

        expect {
          spec_customer_info.update_attributes(:spec_person_name_id => 4)
        }.to change { spec_customer_info.lock_version }.from(1).to(2)
      end

      it "should not fail if no locking_column present" do
        email = SpecCustomerEmail.create(:spec_customer_id => 1, :email => "foo@bar.com")
        expect{ email.update_attributes(:email => "foo2@bar.com") }.not_to raise_error
      end

      it "updates lock_version column based on parent relation" do
        @other_customer = SpecCustomer.create
        spec_customer_info = @customer.spec_customer_info

        expect {
          spec_customer_info.update_attributes(:spec_person_name_id => 3)
        }.to change { spec_customer_info.lock_version }.from(0).to(1)

        expect {
          spec_customer_info.update_attributes(:spec_customer => @other_customer)
        }.to change { spec_customer_info.lock_version }.from(1).to(0)
      end

      it "updates lock_version column base on relation list from 'by' option" do
        info_with_type =
          @customer.reload.create_spec_customer_info_with_type(:spec_type => :important)

        expect( info_with_type.lock_version ).to eq 0

        other_info_with_type =
          @customer.reload.create_spec_customer_info_with_type(:spec_type => :unimportant)

        expect( other_info_with_type.lock_version ).to eq 0

        info_with_type.update_attributes(:spec_status => :active)
        expect( info_with_type.lock_version ).to eq 1

        info_with_type.update_attributes(:spec_status => :inactive)
        expect( info_with_type.lock_version ).to eq 2

        expect( other_info_with_type.lock_version ).to eq 0
      end
    end

    describe "with Aggregated" do
      before do
        @info.spec_person_name = SpecPersonName.create(:first_name => "John", :last_name => "Smith")
        @info.save
        @info.reload
      end

      it "should supersede when nested record changes" do
        old_id = @info.id
        @customer.spec_customer_info.spec_person_name.first_name = "Alice"
        expect{ @customer.save }.to change(@info, :spec_person_name_id)
        expect(@info.id).not_to eq old_id
        expect(@info.is_current).to eq true
        expect(SpecCustomerInfo.find(old_id).is_current).to eq false
      end
    end
  end

  describe "Delegations" do
    before do
      @customer = SpecCustomer.create(
        :spec_customer_info_attributes => {
          :spec_person_name_attributes => {:first_name => " John ", :last_name => "Smith"} } )
      @info = @customer.spec_customer_info
    end

    it "should have delegated column information" do
      expect(@customer.column_for_attribute(:first_name)).not_to be_nil
    end

    it "should not delegate special methods" do
      expect(@customer).not_to respond_to(:reset_first_name)
      expect(@customer).not_to respond_to(:first_name_was)
      expect(@customer).not_to respond_to(:first_name_before_type_cast)
      expect(@customer).not_to respond_to(:first_name_will_change!)
      expect(@customer).not_to respond_to(:first_name_changed?)
      expect(@customer).not_to respond_to(:lock_version)
    end

    it "should delegate methods to aggregated parts" do
      expect(@info).to respond_to(:first_name)
      expect(@info).to respond_to(:first_name=)
      expect(@info).to respond_to(:spec_suffix)
      expect(@info.last_name).to eq "Smith"
    end

    it "should delegate methods to representation" do
      expect(@customer).to respond_to(:first_name)
      expect(@customer).to respond_to(:first_name=)
      expect(@customer).to respond_to(:spec_suffix)
      expect(@customer.last_name).to eq "Smith"
      expect(@customer).to respond_to(:custom_field)
      expect(@customer).to respond_to(:custom_field=)
    end

    it "should properly delegate enumerated attributes" do
      expect(@customer).to respond_to(:spec_type)
      expect(@customer).to respond_to(:spec_type=)
      @customer.spec_type = :important
      expect(@customer.spec_type === :important).to eq true
    end

    it "should raise NoMethodError if unknown method received" do
      expect{ @customer.impossibru }.to raise_error(NoMethodError)
    end
  end
end
