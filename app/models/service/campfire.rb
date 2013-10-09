# == Schema Information
#
# Table name: services
#
#  id          :integer          not null, primary key
#  type        :string(255)
#  title       :string(255)
#  token       :string(255)
#  project_id  :integer          not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  active      :boolean          default(FALSE), not null
#  project_url :string(255)
#  subdomain   :string(255)
#  room        :string(255)
#  state       :string(255)
#

class Service::Campfire < Service
  include Servisable

  default_title       'Campfire'
  default_description 'Simple web-based real-time group chat'
  service_name        'campfire'

  has_one :configuration, as: :service, class_name: Service::Configuration::Campfire

  delegate :token, :subdomain, :room, to: :configuration, prefix: false

  def execute(push_data)
    room = gate.find_room_by_name(self.room)
    return true unless room

    message = build_message(push_data)

    room.speak(message)
  end

  private

  def gate
    @gate ||= Tinder::Campfire.new(subdomain, token: token)
  end

  def build_message(push)
    ref = push[:ref].gsub("refs/heads/", "")
    before = push[:before]
    after = push[:after]

    message = ""
    message << "[#{project.name_with_namespace}] "
    message << "#{push[:user_name]} "

    if before =~ /000000/
      message << "pushed new branch #{ref} \n"
    elsif after =~ /000000/
      message << "removed branch #{ref} \n"
    else
      message << "pushed #{push[:total_commits_count]} commits to #{ref}. "
      message << "#{project.web_url}/compare/#{before}...#{after}"
    end

    message
  end
end
