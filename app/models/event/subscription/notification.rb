class Event::Subscription::Notification < ActiveRecord::Base
  attr_accessible :event_id, :event, :notification_state, :notified_at, :subscription_id, :subscriber, :subscriber_id

  belongs_to :event
  belongs_to :subscriber,   class_name: User
  belongs_to :subscription, class_name: Event::Subscription

  validates :subscriber,   presence: true
  validates :event,        presence: true

  scope :pending, -> { where(notification_state: :new) }
  scope :delayed, -> { where(notification_state: :delayed) }
  scope :instantaneous, -> { pending.where(notification_interval: 0) }

  state_machine :notification_state, initial: :new do
    state :new
    state :delayed
    state :processing
    state :delivered
    state :failed

    event :process do
      transition [:new, :delayed, :failed] => :processing
    end

    event :deliver do
      transition [:processing] => :delivered
    end

    event :delay do
      transition [:new, :failed] => :delayed
    end

    event :failing do
      transition [:processing] => :failed
    end
  end

end
