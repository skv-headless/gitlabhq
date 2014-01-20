module Projects::UsersActions
  private

  def add_membership_action


    user_ids = params[:user_ids].respond_to?(:each) ? params[:user_ids] : params[:user_ids].split(',')

    if user_ids.many?
      RequestStore.store[:borders] ||= []
      RequestStore.store[:borders].push("gitlab.memberships_add.project")
      Gitlab::Event::Action.trigger :memberships_add, @project
    end

    users = User.where(id: user_ids)
    @project.team << [users, params[:project_access]]

    RequestStore.store[:borders].pop if user_ids.many?

    receive_delayed_notifications
  end

  def update_membership_action(member)
    pur = project_member_relation(member)
    member_params = params
    member_params = params[:team_member] if params.has_key?(:team_member)
    pur.update(member_params)

    if pur.valid?
      receive_delayed_notifications
      return true
    else
      return false
    end
  end

  def remove_membership_action(member)
    pur = project_member_relation(member)
    pur.destroy
    receive_delayed_notifications
  end

  def import_memberships_action(giver)
    RequestStore.store[:borders] ||= []
    RequestStore.store[:borders].push("gitlab.import.project")

    Gitlab::Event::Action.trigger :import, @project

    status = @project.team.import(giver)

    RequestStore.store[:borders].pop

    receive_delayed_notifications

    status
  end

  def batch_remove_memberships_action
    user_project_ids = params[:ids].respond_to?(:each) ? params[:ids] : params[:ids].split(',')
    user_project_relations = UsersProject.where(id: user_project_ids)

    user_project_relations.destroy_all

    receive_delayed_notifications
  end

  def batch_update_memberships_action
    user_project_ids = params[:ids].respond_to?(:each) ? params[:ids] : params[:ids].split(',')
    UsersProject.where(id: user_project_ids).update_all(project_access: params[:team_member][:project_access])

    receive_delayed_notifications
  end

  private

  def project_member_relation(member)
    member.users_projects.find_by(project_id: project)
  end
end
