module API
  # Projects API
  class Projects < Grape::API
    before { authenticate! }

    resource :projects do
      helpers do
        def map_public_to_visibility_level(attrs)
          publik = attrs.delete(:public)
          publik = [ true, 1, '1', 't', 'T', 'true', 'TRUE', 'on', 'ON' ].include?(publik)
          attrs[:visibility_level] = Gitlab::VisibilityLevel::PUBLIC if !attrs[:visibility_level].present? && publik == true
          attrs
        end
      end

      # Get a projects list for authenticated user
      #
      # Example Request:
      #   GET /projects
      get do
        search_options = { page: params[:page] }
        search_options[:pids] = current_user.known_projects.pluck(:id) unless current_user.admin?
        @projects = Project.search(params[:search], options: search_options).records
        present @projects, with: Entities::Project
      end

      # Get a projects list for authenticated user
      #
      # Example Request:
      #   GET /projects/to_assign
      get '/to_assign' do
        search_options = { page: params[:page] }
        unless current_user.admin?
          search_options[:pids] = (current_user.master_projects.pluck(:id) +
                                   current_user.created_projects.pluck(:id) +
                                   current_user.owned_projects.pluck(:id))
        end
        @projects = Project.search(params[:search], options: search_options).records
        present @projects, with: Entities::Project
      end

      # Get an owned projects list for authenticated user
      #
      # Example Request:
      #   GET /projects/owned
      get '/owned' do
        @projects = paginate current_user.owned_projects
        present @projects, with: Entities::Project
      end

      # Get all projects for admin user
      #
      # Example Request:
      #   GET /projects/all
      get '/all' do
        authenticated_as_admin!
        @projects = paginate Project
        present @projects, with: Entities::Project
      end

      # Get a single project
      #
      # Parameters:
      #   id (required) - The ID of a project
      # Example Request:
      #   GET /projects/:id
      get ":id" do
        present user_project, with: Entities::ProjectWithAccess, user: current_user
      end

      # Get a single project events
      #
      # Parameters:
      #   id (required) - The ID of a project
      # Example Request:
      #   GET /projects/:id
      get ":id/events" do
        limit = (params[:per_page] || 20).to_i
        offset = (params[:page] || 0).to_i * limit
        events = user_project.old_events.recent.limit(limit).offset(offset)

        present events, with: Entities::Event
      end

      # Create new project
      #
      # Parameters:
      #   name (required) - name for new project
      #   description (optional) - short project description
      #   issues_enabled (optional)
      #   wall_enabled (optional)
      #   merge_requests_enabled (optional)
      #   wiki_enabled (optional)
      #   snippets_enabled (optional)
      #   namespace_id (optional) - defaults to user namespace
      #   public (optional) - if true same as setting visibility_level = 20
      #   visibility_level (optional) - 0 by default
      # Example Request
      #   POST /projects
      post do
        required_attributes! [:name]
        attrs = attributes_for_keys [:name,
                                     :path,
                                     :description,
                                     :issues_enabled,
                                     :wall_enabled,
                                     :merge_requests_enabled,
                                     :wiki_enabled,
                                     :snippets_enabled,
                                     :namespace_id,
                                     :public,
                                     :visibility_level,
                                     :import_url]
        attrs = map_public_to_visibility_level(attrs)
        @project = ProjectsService.new(current_user, attrs).create
        if @project.saved?
          present @project, with: Entities::Project
        else
          if @project.errors[:limit_reached].present?
            error!(@project.errors[:limit_reached], 403)
          end
          not_found!
        end
      end

      # Create new project for a specified user.  Only available to admin users.
      #
      # Parameters:
      #   user_id (required) - The ID of a user
      #   name (required) - name for new project
      #   description (optional) - short project description
      #   default_branch (optional) - 'master' by default
      #   issues_enabled (optional)
      #   wall_enabled (optional)
      #   merge_requests_enabled (optional)
      #   wiki_enabled (optional)
      #   snippets_enabled (optional)
      #   public (optional) - if true same as setting visibility_level = 20
      #   visibility_level (optional)
      # Example Request
      #   POST /projects/user/:user_id
      post "user/:user_id" do
        authenticated_as_admin!
        user = User.find(params[:user_id])
        attrs = attributes_for_keys [:name,
                                     :description,
                                     :default_branch,
                                     :issues_enabled,
                                     :wall_enabled,
                                     :merge_requests_enabled,
                                     :wiki_enabled,
                                     :snippets_enabled,
                                     :public,
                                     :visibility_level]
        attrs = map_public_to_visibility_level(attrs)
        @project = ProjectsService.new(user, attrs).create
        if @project.saved?
          present @project, with: Entities::Project
        else
          not_found!
        end
      end

      # Remove project
      #
      # Parameters:
      #   id (required) - The ID of a project
      # Example Request:
      #   DELETE /projects/:id
      delete ":id" do
        authorize! :remove_project, user_project
        user_project.destroy
      end

      # Mark this project as forked from another
      #
      # Parameters:
      #   id: (required) - The ID of the project being marked as a fork
      #   forked_from_id: (required) - The ID of the project it was forked from
      # Example Request:
      #   POST /projects/:id/fork/:forked_from_id
      post ":id/fork/:forked_from_id" do
        authenticated_as_admin!
        forked_from_project = find_project(params[:forked_from_id])
        unless forked_from_project.nil?
          if user_project.forked_from_project.nil?
            user_project.create_forked_project_link(forked_to_project_id: user_project.id, forked_from_project_id: forked_from_project.id)
          else
            render_api_error!("Project already forked", 409)
          end
        else
          not_found!
        end

      end

      # Remove a forked_from relationship
      #
      # Parameters:
      # id: (required) - The ID of the project being marked as a fork
      # Example Request:
      #  DELETE /projects/:id/fork
      delete ":id/fork" do
        authenticated_as_admin!
        unless user_project.forked_project_link.nil?
          user_project.forked_project_link.destroy
        end
      end
      # search for projects current_user has access to
      #
      # Parameters:
      #   query (required) - A string contained in the project name
      #   per_page (optional) - number of projects to return per page
      #   page (optional) - the page to retrieve
      # Example Request:
      #   GET /projects/search/:query
      get "/search/:query" do
        ids = current_user.known_projects.pluck(:id)
        projects = Project.search(params[:query], options: { pids: ids, page: params[:page] }).records
        present projects, with: Entities::Project
      end


      # Get a users list
      #
      # Example Request:
      #  GET /users
      params do
        optional :search, type: String
        optional :page, type: Integer
        optional :per_page, type: Integer
      end
      get ':id/users' do
        uids = user_project.team.users.pluck(:id)

        @users = User.search(params[:search], page: params[:page],
                             per: params[:per_page], options: {uids: uids}).records
        present @users, with: Entities::User
      end

      # Get a project labels
      #
      # Parameters:
      #   id (required) - The ID of a project
      # Example Request:
      #   GET /projects/:id/labels
      get ':id/labels' do
        @labels = user_project.issues_labels
        present @labels, with: Entities::Label
      end
    end
  end
end
