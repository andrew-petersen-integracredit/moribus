require 'spec_helper'

describe Moribus::AliasAssociation do
  before do
    class SpecPost < MoribusSpecModel(:spec_author_id => :integer, :body => :string)
      belongs_to :spec_author   , :alias => :creator
      has_many   :spec_comments , :alias => :remarks
      has_one    :spec_post_info, :alias => :information

      alias_association :author   , :spec_author
      alias_association :comments , :spec_comments
      alias_association :post_info, :spec_post_info
    end

    class SpecAuthor < MoribusSpecModel(:name => :string)
      has_many :spec_posts
    end

    class SpecPostInfo < MoribusSpecModel(:spec_post_id => :integer, :ip => :string)
      belongs_to :spec_post, :alias => :note
    end

    class SpecComment < MoribusSpecModel(:spec_post_id => :integer, :body => :string)
      belongs_to :spec_post
    end
  end

  after do
    MoribusSpecModel.cleanup!
  end

  before do
    author = SpecAuthor.create(:name => 'John')
    @post = author.spec_posts.create(:body => 'Post Body')
    @post.spec_comments.create(:body => 'Fabulous!')
    @post.create_spec_post_info(:ip => '127.0.0.1')
  end

  describe "reflection aliasing" do
    it "alias association name in reflections" do
      SpecPost.reflect_on_association(:author).should_not be_nil
    end

    it "should not raise error when using aliased name in scopes" do
      expect{
        SpecPost.includes(:comments).first
      }.to_not raise_error
    end
  end

  describe "association accessor alias methods" do
    subject{ @post }

    it{ should respond_to :author }
    it{ should respond_to :author= }
    it{ should respond_to :comments }
    it{ should respond_to :comments= }
    it{ should respond_to :post_info }
    it{ should respond_to :post_info= }
  end

  describe "singular association alias method" do
    subject{ @post }

    it{ should respond_to :build_author }
    it{ should respond_to :create_author }
    it{ should respond_to :create_author! }

    it{ should respond_to :build_post_info }
    it{ should respond_to :create_post_info }
    it{ should respond_to :create_post_info! }
  end

  describe "collection association alias method" do
    subject{ @post }

    it{ should respond_to :comment_ids }
    it{ should respond_to :comment_ids= }
  end

  describe ":alias => alias_name shortcuts" do
    subject{ @post }

    it { should respond_to :creator }
    it { should respond_to :remarks }
    it { should respond_to :information }
  end
end
