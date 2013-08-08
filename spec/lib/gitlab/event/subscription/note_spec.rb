require 'spec_helper'

describe Gitlab::Event::Subscription::Note do
  it "should respond to :subscribe method" do
    Gitlab::Event::Subscription::Note.should respond_to :can_subscribe?
  end

  describe "Note subscribe" do
    before do
      @user = create :user
    end

    it "should subscribe user on exist note changes" do
      source = create :note
      target = source
      action = :updated

      Gitlab::Event::Subscription.subscribe(@user, action, target, source)

      subscription = ::Event::Subscription.last
      subscription.should_not be_nil
      subscription.should be_persisted
    end

    it "should subscribe user on all notes changes by subscribe with symbol" do
      source = :note
      target = create :issue
      action = :created

      Gitlab::Event::Subscription.subscribe(@user, action, target, source)

      subscription = ::Event::Subscription.last
      subscription.should_not be_nil
      subscription.should be_persisted
    end

    it "should subscribe user on all notes changes by subscribe with Class name" do
      source = Note
      target = create :issue
      action = :created

      Gitlab::Event::Subscription.subscribe(@user, action, target, source)

      subscription = ::Event::Subscription.last
      subscription.should_not be_nil
      subscription.should be_persisted
    end

    it "should subscribe user on exist note :note adds" do
      target = create :note
      source = :note
      action = :created

      Gitlab::Event::Subscription.subscribe(@user, action, target, source)

      subscription = ::Event::Subscription.last
      subscription.should_not be_nil
      subscription.should be_persisted
    end

  end
end