module Projects
  module Users
    class ImportRelationContext < Projects::BaseContext
      def execute
        giver = Project.find(params[:source_project_id])

        Gitlab::Event::Action.trigger :imported, @project

        status = @project.team.import(giver)

        receive_delayed_notifications

        status
      end
    end
  end
end
