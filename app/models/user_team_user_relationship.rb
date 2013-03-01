# == Schema Information
#
# Table name: user_team_user_relationships
#
#  id           :integer          not null, primary key
#  user_id      :integer
#  user_team_id :integer
#  group_admin  :boolean
#  permission   :integer
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#

class UserTeamUserRelationship < ActiveRecord::Base
  include Watchable

  attr_accessible :group_admin, :permission, :user_id, :user_team_id

  belongs_to :user_team
  belongs_to :user

  has_many :events,         as: :source
  has_many :subscriptions,  conditions: { action: "some_action" }
  has_many :notifications,  through: :subscriptions
  has_many :subscribers,    through: :subscriptions

  validates :user_team, presence: true
  validates :user,      presence: true

  scope :with_user, ->(user) { where(user_id: user.id) }

  actions_to_watch [:created, :updated, :deleted]

  def user_name
    user.name
  end

  def access_human
    UsersProject.access_roles.invert[permission]
  end
end
