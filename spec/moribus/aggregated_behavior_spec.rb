require "spec_helper"

describe Moribus::AggregatedBehavior do
  before do
    class SpecSuffix < MoribusSpecModel(name: :string, description: :string)
      acts_as_enumerated

      self.enumeration_model_updates_permitted = true
      create!(name: "none", description: "")
      create!(name: "jr"  , description: "Junior")
    end

    class SpecTag < MoribusSpecModel()
      has_and_belongs_to_many :person_names
    end

    class SpecPersonNamesTags < MoribusSpecModel(spec_tag_id: :integer,
                                                 spec_person_name_id: :integer
                                                )
    end

    class SpecPersonName < MoribusSpecModel(first_name:     :string,
                                            last_name:      :string,
                                            spec_suffix_id: :integer
                                          )
      acts_as_aggregated
      has_enumerated :spec_suffix, default: ""
      has_and_belongs_to_many :spec_tags

      validates_presence_of :first_name, :last_name

      # custom writer that additionally strips first name
      def first_name=(value)
        self[:first_name] = value.strip
      end
    end

    class SpecCustomerFeature < MoribusSpecModel(feature_name: :string)
      acts_as_aggregated cache_by: :feature_name
    end
  end

  after do
    MoribusSpecModel.cleanup!
  end

  describe "Aggregated" do
    it "supports has_and_belongs_to_many association reflections which do not have a macro" do
      tags = [SpecTag.new, SpecTag.new]
      name = SpecPersonName.create!(first_name: "John", last_name: "Smith", spec_tags: tags)
      expect(name.spec_tags.size).to eq(2)
    end

    context "definition" do
      it "raises an error on an unknown option" do
        expect{
          Class.new(ActiveRecord::Base).class_eval do
            acts_as_aggregated invalid_key: :error
          end
        }.to raise_error(ArgumentError)
      end

      it "raises an error when including AggregatedCacheBehavior without AggregatedBehavior" do
        expect{
          Class.new(ActiveRecord::Base).class_eval do
            include Moribus::AggregatedCacheBehavior
          end
        }.to raise_error(Moribus::AggregatedCacheBehavior::NotAggregatedError)
      end
    end

    before do
      @existing = SpecPersonName.create! first_name: "John", last_name: "Smith"
    end

    it "doesn't duplicate records" do
      expect {
        SpecPersonName.create first_name: " John ", last_name: "Smith"
      }.not_to change(SpecPersonName, :count)
    end

    it "looks up self and replaces id with existing on create" do
      name = SpecPersonName.new first_name: "John", last_name: "Smith"
      name.save
      expect(name.id).to eq @existing.id
    end

    it "creates a new record if lookup fails" do
      expect {
        SpecPersonName.create first_name: "Alice", last_name: "Smith"
      }.to change(SpecPersonName, :count).by(1)
    end

    it "looks up self and replaces id with existing on update" do
      name = SpecPersonName.create first_name: "Alice", last_name: "Smith"
      name.update_attributes first_name: "John"
      expect(name.id).to eq @existing.id
    end

    it "calls super in save if any aggregated behaviour non content columns wasn't changed" do
      name = SpecPersonName.create first_name: "Alice", last_name: "Smith"
      expect {
        name.save
      }.to change(SpecPersonName, :count).by(0)
    end

    it "raises the expected error when 'save!' fails" do
      name = SpecPersonName.create first_name: "Alice", last_name: "Smith"
      name.last_name = nil
      expect {
        name.save!
      }.to raise_error(ActiveRecord::RecordNotSaved)
    end

    context "with caching" do
      before do
        @existing = SpecCustomerFeature.create(feature_name: "Pays")
        SpecCustomerFeature.clear_cache
      end

      it "looks up the existing value and adds it to the cache" do
        feature = SpecCustomerFeature.new feature_name: @existing.feature_name

        expect{ feature.save }.
          to change(SpecCustomerFeature.aggregated_records_cache, :length).by(1)

        expect(feature.id).to eq @existing.id
      end

      it "adds the freshly-created record to the cache" do
        expect{ SpecCustomerFeature.create(feature_name: "Fraud") }.
          to change(SpecCustomerFeature.aggregated_records_cache, :length).by(1)
      end

      it "freezes the cached object" do
        feature = SpecCustomerFeature.create(feature_name: "Cancelled")
        expect(SpecCustomerFeature.aggregated_records_cache[feature.feature_name]).to be_frozen
      end

      it "caches the clone of the record, not the record itself" do
        feature = SpecCustomerFeature.create(feature_name: "Returned")
        expect(SpecCustomerFeature.aggregated_records_cache[feature.feature_name].object_id).
          not_to eq feature.object_id
      end
    end
  end
end
