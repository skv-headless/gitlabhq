class MergeRequestObserver < BaseObserver
  observe :merge_request

  def after_create(merge_request)
    if merge_request.author_id
      create_event(merge_request, OldEvent.determine_action(merge_request))
    end

    merge_request.create_cross_references!(merge_request.project, current_user)
    if merge_request.target_project && merge_request.target_project.jenkins_ci_with_mr?
      type = (merge_request.target_project == merge_request.source_project ? :project : :fork)
      service = merge_request.target_project.jenkins_ci
      service.build_merge_request(merge_request, current_user, type)
    end
  end

  def after_close(merge_request, transition)
    create_event(merge_request, OldEvent::CLOSED)
    Note.create_status_change_note(merge_request, merge_request.target_project, current_user, merge_request.state, nil)

    #notification.close_mr(merge_request, current_user)
  end

  def after_merge(merge_request, transition)
    # Since MR can be merged via sidekiq
    # to prevent event duplication do this check
    return true if merge_request.merge_event

    OldEvent.create(
      project: merge_request.target_project,
      target_id: merge_request.id,
      target_type: merge_request.class.name,
      action: OldEvent::MERGED,
      author_id: merge_request.author_id_of_changes
    )
  end

  def after_reopen(merge_request, transition)
    create_event(merge_request, OldEvent::REOPENED)
    Note.create_status_change_note(merge_request, merge_request.target_project, current_user, merge_request.state, nil)
  end

  def after_update(merge_request)
    #notification.reassigned_merge_request(merge_request, current_user) if merge_request.is_being_reassigned?

    merge_request.notice_added_references(merge_request.project, current_user)
  end

  def create_event(record, status)
    OldEvent.create(
      project: record.target_project,
      target_id: record.id,
      target_type: record.class.name,
      action: status,
      author_id: current_user.id
    )
  end
end
