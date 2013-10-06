module Groups
  class CreateContext < ::BaseContext
    def execute
      group = Group.new(params)
      group.path = group.name.dup.parameterize  if group.name && params[:path].blank?
      group.owner = current_user                if params[:owner_id].blank?
      group.save

      receive_delayed_notifications

      group
    end
  end
end