require 'spec_helper'

describe Core::Behaviors do
  before do
    class SpecStatus < SpecModel(:name => :string, :description => :string)
      acts_as_enumerated

      self.enumeration_model_updates_permitted = true
      create!(:name => 'inactive', :description => 'Inactive')
      create!(:name => 'active', :description => 'Active')
    end

    class SpecSuffix < SpecModel(:name => :string, :description => :string)
      acts_as_enumerated

      self.enumeration_model_updates_permitted = true
      create!(:name => 'none', :description => '')
      create!(:name => 'jr', :description => 'Junior')
    end

    class SpecPersonName < SpecModel(:first_name => :string, :last_name => :string, :spec_suffix_id => :integer)
      acts_as_aggregated
      has_enumerated :spec_suffix, :default => ''

      validates_presence_of :first_name, :last_name
    end

    class SpecCustomerInfo < SpecModel(:spec_customer_id => :integer!, :spec_person_name_id => :integer, :spec_status_id => :integer, :is_current => :boolean, :lock_version => :integer, :created_at => :datetime, :updated_at => :datetime)
      attr :custom_field

      belongs_to :spec_customer, :inverse_of => :spec_customer_info, :touch => true
      has_aggregated :spec_person_name
      has_enumerated :spec_status

      acts_as_tracked
    end

    class SpecCustomer < SpecModel(:spec_status_id => :integer)
      has_one_current :spec_customer_info, :inverse_of => :spec_customer
      has_enumerated :spec_status, :default => 'inactive'

      delegate_associated :spec_person_name, :custom_field, :to => :spec_customer_info

      share :spec_status_id, :with => :spec_customer_info
    end

    class SpecCustomerEmail < SpecModel(:spec_customer_id => :integer, :email => :string, :is_current => :boolean, :status => :string)
      connection.add_index table_name, [:email], :unique => true, :where => 'is_current'

      belongs_to :spec_customer

      acts_as_tracked
    end
  end

  after do
    SpecModel.cleanup!
  end

  describe "common behavior" do
    before do
      @info = SpecCustomerInfo.create :spec_customer_id => 1, :spec_person_name_id => 1, :is_current => true
    end

    it "should revert changes if exception is raised" do
      old_id = @info.id
      suppress(Exception) do
        expect {
          @info.update_attributes :spec_customer_id => nil, :spec_person_name_id => 2
        }.not_to change(SpecCustomerInfo, :count)
        @info.new_record?.should be_false
        @info.id.should == old_id
      end
    end
  end

  describe 'Aggregated' do
    before do
      @existing = SpecPersonName.create! :first_name => 'John', :last_name => 'Smith'
    end

    it "should not duplicate records" do
      expect {
        SpecPersonName.create :first_name => 'John', :last_name => 'Smith'
      }.not_to change(SpecPersonName, :count)
    end

    it "should lookup self and replace id with existing on create" do
      name = SpecPersonName.new :first_name => 'John', :last_name => 'Smith'
      name.save
      name.id.should == @existing.id
    end

    it "should create a new record if lookup fails" do
      expect {
        SpecPersonName.create :first_name => 'Alice', :last_name => 'Smith'
      }.to change(SpecPersonName, :count).by(1)
    end

    it "should lookup self and replace id with existing on update" do
      name = SpecPersonName.create :first_name => 'Alice', :last_name => 'Smith'
      name.update_attributes :first_name => 'John'
      name.id.should == @existing.id
    end
  end

  describe 'Tracked' do
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
      @info.id.should_not == old_id
    end

    it "should set is_current record to false for superseded record" do
      old_id = @info.id
      @info.update_attributes(:spec_person_name_id => 2)
      SpecCustomerInfo.find(old_id).is_current.should be_false
    end

    it "assigning a new current record should change is_current to false for previous one" do
      new_info = SpecCustomerInfo.new :spec_person_name_id => 2, :is_current => true
      @customer.spec_customer_info = new_info
      new_info.spec_customer_id.should == @customer.id
      @info.is_current.should be_false
    end

    it "should not crash on superseding with 'is_current' conditional constraint" do
      email = SpecCustomerEmail.create(:spec_customer => @customer, :email => 'foo@bar.com', :status => 'unverified', :is_current => true)
      expect{ email.update_attributes(:status => 'verified') }.not_to raise_error
    end

    describe 'updated_at and created_at' do
      let(:first_time)  { Time.zone.parse('2012-07-16 00:00:00') }
      let(:second_time) { Time.zone.parse('2012-07-17 08:10:15') }

      before { Timecop.freeze(first_time) }
      after  { Timecop.return             }

      it "should be updated on change" do
        info = @customer.create_spec_customer_info :spec_person_name_id => 1
        info.updated_at.should == first_time
        info.created_at.should == first_time

        Timecop.freeze(second_time)
        info.spec_person_name_id = 2
        info.save!
        info.updated_at.should == second_time
        info.created_at.should == second_time
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

      it "should not fail if no locking_column present" do
        email = SpecCustomerEmail.create(:spec_customer_id => 1, :email => 'foo@bar.com')
        expect{ email.update_attributes(:email => 'foo2@bar.com') }.not_to raise_error
      end
    end

    describe 'with Aggregated' do
      before do
        @info.spec_person_name = SpecPersonName.create(:first_name => 'John', :last_name => 'Smith')
        @info.save
        @info.reload
      end

      it "should supersede when nested record changes" do
        old_id = @info.id
        @customer.spec_customer_info.spec_person_name.first_name = 'Alice'
        expect{ @customer.save }.to change(@info, :spec_person_name_id)
        @info.id.should_not == old_id
        @info.is_current.should == true
        SpecCustomerInfo.find(old_id).is_current.should be_false
      end
    end
  end

  describe 'Delegations' do
    before do
      @customer = SpecCustomer.create(
        :spec_customer_info_attributes => {
          :spec_person_name_attributes => {:first_name => 'John', :last_name => 'Smith'} } )
      @info = @customer.spec_customer_info
    end

    it "should have delegated column information" do
      @customer.column_for_attribute(:first_name).should_not be_nil
    end

    it "should not delegate special methods" do
      @customer.should_not respond_to(:reset_first_name)
      @customer.should_not respond_to(:first_name_was)
      @customer.should_not respond_to(:first_name_before_type_cast)
      @customer.should_not respond_to(:first_name_will_change!)
      @customer.should_not respond_to(:first_name_changed?)
      @customer.should_not respond_to(:lock_version)
    end

    it "should delegate methods to aggregated parts" do
      @info.should respond_to(:first_name)
      @info.should respond_to(:spec_suffix)
      @info.last_name.should == 'Smith'
    end

    it "should delegate methods to representation" do
      @customer.should respond_to(:first_name)
      @customer.should respond_to(:spec_suffix)
      @customer.last_name.should == 'Smith'
      @customer.should respond_to(:custom_field)
      @customer.should respond_to(:custom_field=)
    end

    it "should raise NoMethodError if unknown method received" do
      expect{ @customer.impossibru }.to raise_error(NoMethodError)
    end
  end
end
