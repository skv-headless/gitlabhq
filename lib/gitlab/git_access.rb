module Gitlab
  class GitAccess
    DOWNLOAD_COMMANDS = %w{ git-upload-pack git-upload-archive }
    PUSH_COMMANDS = %w{ git-receive-pack }

    attr_reader :params, :project, :git_cmd, :user

    def allowed?(actor, cmd, project, ref = nil, oldrev = nil, newrev = nil)
      case cmd
      when *DOWNLOAD_COMMANDS
        case actor
        when User
          download_allowed?(actor, project)
        when DeployKey
          actor.projects.include?(project)
        when ServiceKey
          service = actor.services.with_project(project).first
          if service.present?
            service.allowed_clone?(actor)
          else
            false
          end
        when Key
          download_allowed?(actor.user, project)
        else
          raise 'Wrong actor'
        end
      when *PUSH_COMMANDS
        case actor
        when User
          push_allowed?(actor, project, ref, oldrev, newrev)
        when DeployKey
          # Deploy key not allowed to push
          return false
        when ServiceKey
          service = actor.services.with_project(project).first
          if service.present?
            if project.protected_branch?(ref)
              services.allowed_protected_push?(actor)
            else
              service.allowed_push?(actor)
            end
          else
            false
          end
        when Key
          push_allowed?(actor.user, project, ref, oldrev, newrev)
        else
          raise 'Wrong actor'
        end
      else
        false
      end
    end

    def download_allowed?(user, project)
      if user && user_allowed?(user)
        user.can?(:download_code, project)
      else
        false
      end
    end

    def push_allowed?(user, project, ref, oldrev, newrev)
      if user && user_allowed?(user)
        action = if project.protected_branch?(ref)
                   :push_code_to_protected_branches
                 else
                   :push_code
                 end
        user.can?(action, project)
      else
        false
      end
    end

    private

    def user_allowed?(user)
      return false if user.blocked?

      if Gitlab.config.ldap.enabled
        if user.ldap_user?
          # Check if LDAP user exists and match LDAP user_filter
          unless Gitlab::LDAP::Access.new.allowed?(user)
            return false
          end
        end
      end

      true
    end
  end
end
