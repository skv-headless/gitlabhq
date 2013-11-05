# == Schema Information
#
# Table name: users
#
#  id                     :integer          not null, primary key
#  email                  :string(255)      default(""), not null
#  encrypted_password     :string(255)      default(""), not null
#  reset_password_token   :string(255)
#  reset_password_sent_at :datetime
#  remember_created_at    :datetime
#  sign_in_count          :integer          default(0)
#  current_sign_in_at     :datetime
#  last_sign_in_at        :datetime
#  current_sign_in_ip     :string(255)
#  last_sign_in_ip        :string(255)
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  name                   :string(255)
#  admin                  :boolean          default(FALSE), not null
#  projects_limit         :integer          default(10)
#  skype                  :string(255)      default(""), not null
#  linkedin               :string(255)      default(""), not null
#  twitter                :string(255)      default(""), not null
#  authentication_token   :string(255)
#  theme_id               :integer          default(1), not null
#  bio                    :string(255)
#  failed_attempts        :integer          default(0)
#  locked_at              :datetime
#  extern_uid             :string(255)
#  provider               :string(255)
#  username               :string(255)
#  can_create_group       :boolean          default(TRUE), not null
#  can_create_team        :boolean          default(TRUE), not null
#  state                  :string(255)
#  color_scheme_id        :integer          default(1), not null
#  notification_level     :integer          default(1), not null
#  password_expires_at    :datetime
#  created_by_id          :integer
#  avatar                 :string(255)
#  confirmation_token     :string(255)
#  confirmed_at           :datetime
#  confirmation_sent_at   :datetime
#  unconfirmed_email      :string(255)
#

require 'carrierwave/orm/activerecord'
require 'file_size_validator'

class User < ActiveRecord::Base
  include Watchable

  devise :database_authenticatable, :token_authenticatable, :lockable, :async,
         :recoverable, :rememberable, :trackable, :validatable, :omniauthable, :confirmable, :registerable

  attr_accessible :email, :password, :password_confirmation, :remember_me, :bio, :name, :username,
                  :skype, :linkedin, :twitter, :color_scheme_id, :theme_id, :force_random_password,
                  :extern_uid, :provider, :password_expires_at, :avatar,
                  as: [:default, :admin]

  attr_accessible :projects_limit, :can_create_group,
                  as: :admin

  attr_accessor :force_random_password

  # Virtual attribute for authenticating by either username or email
  attr_accessor :login

  # Add login to attr_accessible
  attr_accessible :login


  #
  # Relations
  #

  # Namespace for personal projects
  has_one :namespace, dependent: :destroy, foreign_key: :owner_id, class_name: "Namespace", conditions: 'type IS NULL'

  # Namespaces (owned groups and own namespace)
  has_many :namespaces, foreign_key: :owner_id

  # Profile
  has_many :keys, dependent: :destroy

  # Groups
  has_many :own_groups,   class_name: Group, foreign_key: :owner_id
  has_many :owned_groups, through: :users_groups, source: :group, conditions: { users_groups: { group_access: UsersGroup::OWNER } }

  has_many :users_groups, dependent: :destroy
  has_many :groups, through: :users_groups

  # Projects
  has_many :users_projects,           dependent: :destroy

  has_many :projects,                 through: :users_projects
  has_many :personal_projects,        through: :namespace, source: :projects
  has_many :own_projects,             foreign_key: :creator_id, class_name: Project
  has_many :accessed_projects,        through: :namespaces, source: :projects
  has_many :groups_projects,          through: :groups, source: :projects
  has_many :master_projects,          through: :users_projects, source: :project,
                                      conditions: { users_projects: { project_access: UsersProject::MASTER } }

  has_many :snippets,                 dependent: :destroy, foreign_key: :author_id, class_name: "Snippet"
  has_many :issues,                   dependent: :destroy, foreign_key: :author_id
  has_many :notes,                    dependent: :destroy, foreign_key: :author_id
  has_many :merge_requests,           dependent: :destroy, foreign_key: :author_id
  has_many :assigned_issues,          dependent: :destroy, foreign_key: :assignee_id, class_name: Issue
  has_many :assigned_merge_requests,  dependent: :destroy, foreign_key: :assignee_id, class_name: MergeRequest

  # Teams
  has_many :team_user_relationships,         dependent: :destroy
  has_many :teams,                           through: :team_user_relationships
  has_many :personal_teams,                  through: :team_user_relationships, foreign_key: :creator_id, source: :team
  has_many :own_teams,                       through: :team_user_relationships, conditions: { team_user_relationships: { team_access: [Gitlab::Access::OWNER, Gitlab::Access::MASTER] } }, source: :team
  has_many :master_teams,                    through: :team_user_relationships, conditions: { team_user_relationships: { team_access: [Gitlab::Access::OWNER, Gitlab::Access::MASTER] } }, source: :team
  has_many :team_project_relationships,      through: :teams
  has_many :team_group_relationships,        through: :teams
  has_many :team_projects,                   through: :team_project_relationships,      source: :project
  has_many :team_groups,                     through: :team_group_relationships,        source: :group
  has_many :team_group_grojects,             through: :team_groups,                     source: :projects
  has_many :master_team_group_relationships, through: :teams, conditions: { team_user_relationships: { team_access: [Gitlab::Access::OWNER, Gitlab::Access::MASTER] } }, source: :team_group_relationships
  has_many :master_team_groups,              through: :master_team_group_relationships, source: :group

  # Events
  has_many :events,                   as: :source
  has_many :personal_events,                               class_name: OldEvent, foreign_key: :author_id
  has_many :recent_events,                                 class_name: OldEvent, foreign_key: :author_id, order: "id DESC"
  has_many :old_events,               dependent: :destroy, class_name: OldEvent, foreign_key: :author_id

  # Notifications & Subscriptions
  has_many :personal_subscriprions,   dependent: :destroy, class_name: Event::Subscription
  has_many :subscriprions,            dependent: :destroy, class_name: Event::Subscription, as: :target
  has_many :notifications,            dependent: :destroy, class_name: Event::Subscription::Notification, foreign_key: :subscriber_id
  has_one  :notification_setting,     dependent: :destroy, class_name: Event::Subscription::NotificationSetting

  has_many :file_tokens

  #
  # Validations
  #
  validates :name, presence: true
  validates :email, presence: true, format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/ }
  validates :bio, length: { within: 0..255 }
  validates :extern_uid, allow_blank: true, uniqueness: {scope: :provider}
  validates :projects_limit, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :username, presence: true, uniqueness: true,
            exclusion: { in: Gitlab::Blacklist.path },
            format: { with: Gitlab::Regex.username_regex,
                      message: "only letters, digits & '_' '-' '.' allowed. Letter should be first" }
  validate :namespace_uniq, if: ->(user) { user.username_changed? }

  validates :avatar, file_size: { maximum: 100.kilobytes.to_i }

  before_validation :generate_password, on: :create
  before_validation :sanitize_attrs

  before_save :ensure_authentication_token

  alias_attribute :private_token, :authentication_token

  delegate :path, to: :namespace, allow_nil: true, prefix: true

  state_machine :state, initial: :active do
    event :block do
      transition active: :blocked
    end

    event :activate do
      transition blocked: :active
    end
  end

  mount_uploader :avatar, AttachmentUploader

  # Scopes
  scope :admins, -> { where(admin:  true) }
  scope :blocked, -> { with_state(:blocked) }
  scope :active, -> { with_state(:active) }
  scope :alphabetically, -> { order('name ASC') }
  scope :in_team, ->(team){ where(id: team.member_ids) }
  scope :not_in_team, ->(team){ where('users.id NOT IN (:ids)', ids: team.member_ids) }
  scope :not_in_project, ->(project) { project.users.present? ? where("id not in (:ids)", ids: project.users.map(&:id) ) : scoped }
  scope :not_in_group, ->(group) { group.users.present? ? where("id not in (:ids)", ids: group.users.pluck(:id)) : scoped }
  scope :without_projects, -> { where('id NOT IN (SELECT DISTINCT(user_id) FROM users_projects)') }
  scope :ldap, -> { where(provider:  'ldap') }

  scope :potential_team_members, ->(team) { team.members.any? ? active.not_in_team(team) : active  }

  actions_to_watch [:created, :deleted, :updated, :joined, :left, :transfer, :added, :blocked, :activate]

  #
  # Class methods
  #
  class << self
    # Devise method overridden to allow sign in with email or username
    def find_for_database_authentication(warden_conditions)
      conditions = warden_conditions.dup
      if login = conditions.delete(:login)
        where(conditions).where(["lower(username) = :value OR lower(email) = :value", { value: login.downcase }]).first
      else
        where(conditions).first
      end
    end

    def filter filter_name
      case filter_name
      when "admins"; self.admins
      when "blocked"; self.blocked
      when "wop"; self.without_projects
      else
        self.active
      end
    end

    def search query
      where("name LIKE :query OR email LIKE :query OR username LIKE :query", query: "%#{query}%")
    end

    def by_username_or_id(name_or_id)
      field = (name_or_id.to_s == name_or_id.to_i.to_s ? "id" : "username")
      where(:"#{field}" => name_or_id).first
    end

    def build_user(attrs = {}, options= {})
      if options[:as] == :admin
        User.new(defaults.merge(attrs.symbolize_keys), options)
      else
        User.new(attrs, options).with_defaults
      end
    end

    def defaults
      {
        projects_limit: Gitlab.config.gitlab.default_projects_limit,
        can_create_group: Gitlab.config.gitlab.default_can_create_group,
        theme_id: Gitlab.config.gitlab.default_theme
      }
    end
  end

  #
  # Instance methods
  #

  def to_param
    username
  end

  def notification
    @notification ||= Notification.new(self)
  end

  def generate_password
    if self.force_random_password
      self.password = self.password_confirmation = Devise.friendly_token.first(8)
    end
  end

  def namespace_uniq
    namespace_name = self.username
    if Namespace.find_by_path(namespace_name)
      self.errors.add :username, "already exist"
    end
  end

  # Groups where user is an owner
  def owned_groups
   @group_ids = groups.pluck(:id) + master_team_groups.pluck(:id)
   Group.where(id: @group_ids)
  end

  def owned_teams
    own_teams
  end

  def owned_projects
    @project_ids ||= (Project.where(namespace_id: owned_groups).pluck(:id) + master_projects.pluck(:id) + accessed_projects.pluck(:id)).uniq
    Project.where(id: @project_ids)
  end

  # Groups user has access to
  def authorized_groups
    agroups = Group.scoped
    unless self.admin?
      agroups = personal_groups
    end
    agroups
  end

  def personal_groups
    @group_ids ||= (groups.pluck(:id) + team_groups.pluck(:id) + authorized_projects.pluck(:namespace_id))
    Group.where(id: @group_ids).order('namespaces.name ASC')
  end

  def authorized_namespaces
    namespace_ids = owned_groups.pluck(:id) + [namespace.id]
    Namespace.where(id: namespace_ids)
  end

  # Projects user has access to
  def authorized_projects
    @authorized_projects ||= begin
                               project_ids = (owned_projects.pluck(:id) + groups_projects.pluck(:id) + projects.pluck(:id) + team_projects.pluck(:id) + team_group_grojects.pluck(:id)).uniq
                               Project.where(id: project_ids).joins(:namespace).order('namespaces.name ASC')
                             end
  end

  def known_projects
    @project_ids ||= (owned_projects.pluck(:id) + groups_projects.pluck(:id) + projects.pluck(:id) + team_projects.pluck(:id) + team_group_grojects.pluck(:id) + Project.public_only.pluck(:id)).uniq
    Project.where(id: @project_ids)
  end

  def authorized_teams
    ateams = Team.scoped
    unless self.admin?
      ateams = known_teams
    end
    ateams
  end

  def known_teams
    @known_teams_ids ||= (personal_teams.pluck(:id) + own_teams.pluck(:id) + master_teams.pluck(:id) + teams.pluck(:id) + Team.where(public: true).pluck(:id)).uniq
    Team.where(id: @known_teams_ids)
  end

  # Team membership in authorized projects
  def tm_in_authorized_projects
    UsersProject.where(project_id: authorized_projects.map(&:id), user_id: self.id)
  end

  def is_admin?
    admin
  end

  def require_ssh_key?
    keys.count == 0
  end

  def can_change_username?
    Gitlab.config.gitlab.username_changing_enabled
  end

  def can_create_project?
    projects_limit_left > 0
  end

  def can_create_group?
    can?(:create_group, nil)
  end

  def abilities
    @abilities ||= begin
                     abilities = Six.new
                     abilities << Ability
                     abilities
                   end
  end

  def can_select_namespace?
    several_namespaces? || admin
  end

  def can? action, subject
    abilities.allowed?(self, action, subject)
  end

  def first_name
    name.split.first unless name.blank?
  end

  def cared_merge_requests
    MergeRequest.cared(self)
  end

  def projects_limit_left
    projects_limit - personal_projects.count
  end

  def projects_limit_percent
    return 100 if projects_limit.zero?
    (personal_projects.count.to_f / projects_limit) * 100
  end

  def recent_push project_id = nil
    # Get push old_events not earlier than 2 hours ago
    old_events = recent_events.code_push.where("created_at > ?", Time.now - 2.hours)
    old_events = old_events.where(project_id: project_id) if project_id

    # Take only latest one
    old_events = old_events.recent.limit(1).first
  end

  def projects_sorted_by_activity
    authorized_projects.sorted_by_push_date
  end

  def several_namespaces?
    namespaces.many? || owned_groups.any?
  end

  def namespace_id
    namespace.try :id
  end

  def name_with_username
    "#{name} (#{username})"
  end

  def tm_of(project)
    project.team_member_by_id(self.id)
  end

  def already_forked? project
    !!fork_of(project)
  end

  def fork_of project
    links = ForkedProjectLink.where(forked_from_project_id: project, forked_to_project_id: personal_projects)

    if links.any?
      links.first.forked_to_project
    else
      nil
    end
  end

  def ldap_user?
    extern_uid && provider == 'ldap'
  end

  def accessible_deploy_keys
    DeployKey.in_projects(self.known_projects).uniq
  end

  def accessible_service_keys
    p "Fix accessible_service_keys !!!"
    ServiceKey.for_projects(self.known_projects).uniq
  end

  def created_by
    User.find_by_id(created_by_id) if created_by_id
  end

  def sanitize_attrs
    %w(name username skype linkedin twitter bio).each do |attr|
      value = self.send(attr)
      self.send("#{attr}=", Sanitize.clean(value)) if value.present?
    end
  end

  def solo_owned_groups
    @solo_owned_groups ||= owned_groups.select do |group|
      group.owners == [self]
    end
  end

  def with_defaults
    User.defaults.each do |k, v|
      self.send("#{k}=", v)
    end

    self
  end
end
