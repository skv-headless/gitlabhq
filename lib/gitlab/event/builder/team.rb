class Gitlab::Event::Builder::Team < Gitlab::Event::Builder::Base
  class << self
    def prioritet
      4
    end

    def can_build?(action, data)
      known_action = known_action? action, ::Team.available_actions
      known_sources = [::Team, ::TeamProjectRelationship, ::TeamUserRelationship, ::TeamGroupRelationship]
      known_source = known_sources.include? data.class
      known_source && known_action
    end

    def build(action, source, user, data)
      meta = Gitlab::Event::Action.parse(action)
      temp_data = data.attributes
      actions = []

      case source
      when ::Team
        target = source

        case meta[:action]
        when :created
          actions << :created
        when :updated
          actions << :updated
          temp_data[:previous_changes] = source.changes
        when :deleted
          actions << :deleted
        end

      when ::TeamUserRelationship
        target = source.team

        case meta[:action]
        when :created
          actions << :joined
        when :updated
          actions << :updated
          temp_data[:previous_changes] = source.changes
        when :deleted
          actions << :left
        end

      when ::TeamProjectRelationship
        target = source.team

        case meta[:action]
        when :created
          actions << :assigned
        when :updated
          actions << :updated
          temp_data[:previous_changes] = source.changes
        when :deleted
          actions << :resigned
        end

      when ::TeamGroupRelationship
        target = source.team

        case meta[:action]
        when :created
          actions << :joined
        when :updated
          actions << :updated
          temp_data[:previous_changes] = source.changes
        when :deleted
          actions << :left
        end

      end
      events = []
      actions.each do |act|
        events << ::Event.new(action: act, source: source, data: temp_data.to_json, author: user, target: target)
      end
      events
    end
  end
end