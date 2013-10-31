require 'spec_helper'

describe ApplicationHelper do
  describe 'current_controller?' do
    before do
      controller.stub!(:controller_name).and_return('foo')
    end

    it "returns true when controller matches argument" do
      current_controller?(:foo).should be_true
    end

    it "returns false when controller does not match argument" do
      current_controller?(:bar).should_not be_true
    end

    it "should take any number of arguments" do
      current_controller?(:baz, :bar).should_not be_true
      current_controller?(:baz, :bar, :foo).should be_true
    end
  end

  describe 'current_action?' do
    before do
      stub!(:action_name).and_return('foo')
    end

    it "returns true when action matches argument" do
      current_action?(:foo).should be_true
    end

    it "returns false when action does not match argument" do
      current_action?(:bar).should_not be_true
    end

    it "should take any number of arguments" do
      current_action?(:baz, :bar).should_not be_true
      current_action?(:baz, :bar, :foo).should be_true
    end
  end
  
  describe "avatar_icon" do
    avatar_file_path = File.join(Rails.root, 'public', 'gitlab_logo.png')

    it "should return an url for the avatar" do
      user = create(:user)
      user.avatar = File.open(avatar_file_path)
      user.save!
      avatar_icon(user.email).to_s.should == "/system/uploads/user/avatar/#{ user.id }/gitlab_logo.png"
    end

    it "should call gravatar_icon when no avatar is present" do
      user = create(:user)
      user.save!
      stub!(:gravatar_icon).and_return('gravatar_method_called')
      avatar_icon(user.email).to_s.should == "gravatar_method_called"
    end
  end

  describe "gravatar_icon" do
    let(:user_email) { 'user@email.com' }

    it "should return a generic avatar path when Gravatar is disabled" do
      Gitlab.config.gravatar.stub(:enabled).and_return(false)
      gravatar_icon(user_email).should == 'no_avatar.png'
    end

    it "should return a generic avatar path when email is blank" do
      gravatar_icon('').should == 'no_avatar.png'
    end

    it "should return default gravatar url" do
      stub!(:request).and_return(double(:ssl? => false))
      stub!(:gitlab_config).and_return(double(:https => false))
      gravatar_icon(user_email).should match('http://www.gravatar.com/avatar/b58c6f14d292556214bd64909bcdb118')
    end

    it "should use SSL when appropriate" do
      stub!(:request).and_return(double(:ssl? => true))
      gravatar_icon(user_email).should match('https://secure.gravatar.com')
    end

    it "should return custom gravatar path when gravatar_url is set" do
      stub!(:request).and_return(double(:ssl? => false))
      stub!(:gitlab_config).and_return(double(:https => false))
      Gitlab.config.gravatar.stub(:plain_url).and_return('http://example.local/?s=%{size}&hash=%{hash}')
      gravatar_icon(user_email, 20).should == 'http://example.local/?s=20&hash=b58c6f14d292556214bd64909bcdb118'
    end

    it "should accept a custom size" do
      stub!(:request).and_return(double(:ssl? => false))
      gravatar_icon(user_email, 64).should match(/\?s=64/)
    end

    it "should use default size when size is wrong" do
      stub!(:request).and_return(double(:ssl? => false))
      gravatar_icon(user_email, nil).should match(/\?s=40/)
    end

    it "should be case insensitive" do
      stub!(:request).and_return(double(:ssl? => false))
      gravatar_icon(user_email).should == gravatar_icon(user_email.upcase + " ")
    end

  end

  describe "user_color_scheme_class" do
    context "with current_user is nil" do
      it "should return a string" do
        stub!(:current_user).and_return(nil)
        user_color_scheme_class.should be_kind_of(String)
      end
    end

    context "with a current_user" do
      (1..5).each do |color_scheme_id|
        context "with color_scheme_id == #{color_scheme_id}" do
          it "should return a string" do
            current_user = double(:color_scheme_id => color_scheme_id)
            stub!(:current_user).and_return(current_user)
            user_color_scheme_class.should be_kind_of(String)
          end
        end
      end
    end
  end

  describe "simple_sanitize" do
    let(:a_tag) { '<a href="#">Foo</a>' }

    it "allows the a tag" do
      simple_sanitize(a_tag).should == a_tag
    end

    it "allows the span tag" do
      input = '<span class="foo">Bar</span>'
      simple_sanitize(input).should == input
    end

    it "disallows other tags" do
      input = "<strike><b>#{a_tag}</b></strike>"
      simple_sanitize(input).should == a_tag
    end
  end
end
