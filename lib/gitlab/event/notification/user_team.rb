module Gitlab
  module Event
    module Notification
      class UserTeam < Gitlab::Event::Notification::Base
        include Gitlab::Event::Action::UserTeam

        class << self
        end

      end
    end
  end
end
