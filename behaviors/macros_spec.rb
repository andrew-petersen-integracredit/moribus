require 'spec_helper'


# Some of the Core::Behaviors::Macros methods tested in
# spec/lib/core/behaviors_spec.rb
describe Core::Behaviors::Macros do

  describe 'filters_input_on' do
    before do
      class SpecFilterByDefault < SpecModel(:name => :string)
        filters_input_on :name
      end

      class SpecFilterByMethod < SpecModel(:name => :string)
        filters_input_on :name, :filter => :strip
      end

      class SpecFilterByLambda < SpecModel(:name => :string)
        filters_input_on :name, :filter => lambda { |value| value.squish }
      end

      @initial_value = <<-eostring
        My uncle - high  ideals inspire him;\n\n
        but   when past joking he fell sick,
      eostring
      @expected_value =
        'My uncle - high ideals inspire him; but when past joking he fell sick,'
    end

    after do
      SpecModel.cleanup!
    end


    describe 'DefaultFilter' do
      let(:model) { SpecFilterByDefault.create }

      it 'should sanitize' do
        model.name = @initial_value
        model.name.should == @expected_value
      end
    end

    describe 'MethodFilter' do
      let(:model) { SpecFilterByMethod.create }

      it 'should sanitize' do
        model.name = "\t\n here  is sripped  \nvalue   "
        model.name.should == "here  is sripped  \nvalue"
      end

      it 'should not fail if method could not be called on given value' do
        expect { model.name = 5 }.
          to_not raise_error(NoMethodError, 'undefined method `squish` for 5:Fixnum')
      end
    end

    describe 'LambdaFilter' do
      let(:model) { SpecFilterByLambda.create }

      it 'should sanitize' do
        model.name = @initial_value
        model.name.should == @expected_value
      end

      it 'should raise exceptions from lambda' do
        expect { model.name = 5 }.
          to raise_error(NoMethodError, "undefined method `squish' for 5:Fixnum")
      end
    end

    describe 'InvalidFilter' do
      it 'should raise ArgumentError("Do not know how to handle filter `<invalid filter info>`")' do
        expect do
          class SpecFilterByInvalid < SpecModel(:name => :string)
            filters_input_on :name, :filter => 1..5
          end

        end.to raise_error(ArgumentError, 'Do not know how to handle filter `1..5`')
      end
    end
  end

end
