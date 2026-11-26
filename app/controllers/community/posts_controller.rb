module Community
  class PostsController < ApplicationController
    before_action :require_member_access
    rescue_from Errors::MembershipRequired, Identity::Errors::Unavailable, with: -> { head :forbidden }
    rescue_from Errors::CurationEditUnavailable, Errors::CurationDeletionUnavailable, with: -> { head :forbidden }
    rescue_from ActiveRecord::RecordNotFound, Errors::FilmDebriefUnavailable, Errors::NominationUnavailable, with: -> { head :not_found }
    rescue_from Library::Errors::AddToWatchlistUnavailable, Library::Errors::AddToWatchedUnavailable,
      Library::Errors::FilmUnavailable, Library::Errors::AlreadyWatched, Library::Errors::NotOnWatchlist, with: :library_action_unavailable

    def new
      return head :forbidden unless Membership::PostingAccess.allowed?(user: current_user)

      render_form(PostCommunityCuration.new)
    end

    def create
      case params[:post_type]
      when "community_curation" then publish_curation
      when "film_debrief" then open_film_debrief
      else head :bad_request
      end
    rescue Errors::PostingUnavailable
      head :forbidden
    end

    def show
      post = Posts::ReadPost.call(id: post_id, viewer: current_user)
      render PostResponses.for(post).show(post:, viewer: current_user, selected_reply_id: params[:reply],
        expand_selected_branch: params[:replies] == "1")
    end

    def discussion
      post = Posts::ReadPost.call(id: post_id, viewer: current_user)
      parent_id = discussion_id(params[:parent_id]) if params.key?(:parent_id)
      after = discussion_id(params[:after]) if params.key?(:after)
      film_id = discussion_id(params[:film_id]) if params.key?(:film_id)
      render PostResponses.for(post).discussion(post:, viewer: current_user, parent_id:, after:, film_id:),
        content_type: Mime[:html]
    end

    def edit
      curation = Curations::EditCuration.load_for_edit(curation_id: params[:id], member: current_user)
      render Views::Community::EditCuration.new(curation:)
    end

    def update
      title, prompt = text_fields(curation_fields)
      curation = Curations::EditCuration.call(curation_id: params[:id], member_id: current_user.id, title:, prompt:)
      if curation.errors.any?
        return render Views::Community::EditCuration.new(curation:), status: :unprocessable_content
      end

      redirect_to community_post_path(curation), notice: t("community.curation_editing.saved"), status: :see_other
    end

    def destroy
      Curations::DeleteCuration.call(curation_id: params[:id], member_id: current_user.id)
      redirect_to community_path, notice: t("community.curation_deletion.deleted"), status: :see_other
    end

    def additional_description
      description = curation_fields[:additional_description]
      raise ActionController::BadRequest unless description.is_a?(String)

      curation = Curations::ManageCurationAuthorship.update_description(curation_id:, member_id: current_user.id,
        additional_description: description)
      return render Views::Community::EditCuration.new(curation:), status: :unprocessable_content if curation.errors.any?

      redirect_to community_post_path(curation), notice: t("community.curation_protection.description_saved"), status: :see_other
    end

    def disassociate
      Curations::ManageCurationAuthorship.disassociate(curation_id:, member_id: current_user.id)
      redirect_to community_post_path(curation_id), notice: t("community.curation_protection.disassociated"), status: :see_other
    end

    def watchlist
      Curations::ManageCurationFilmInLibrary.add_to_watchlist(curation_id:, user_id: current_user.id, film_id: nominated_film_id)
      redirect_to community_post_path(curation_id), notice: t("library.detail.watchlisted"), status: :see_other
    end

    def watched
      Curations::ManageCurationFilmInLibrary.mark_watched(curation_id:, user_id: current_user.id, film_id: nominated_film_id)
      redirect_to community_post_path(curation_id), notice: t("library.detail.watched"), status: :see_other
    end

    private

    def publish_curation
      title, prompt, reference_film_ids, reference_comments = publication_fields
      curation = Curations::PublishCuration.call(author_id: current_user.id, title:, prompt:, reference_film_ids:, reference_comments:)
      if curation.errors.any?
        return render_form(curation, reference_film_ids:, reference_comments:, status: :unprocessable_content)
      end

      redirect_to community_post_path(curation), notice: t("community.curations.published"), status: :see_other
    end

    def open_film_debrief
      film_id = discussion_id(params[:film_id])
      debrief = FilmDebriefs::OpenFilmDebrief.call(member_id: current_user.id, film_id:)
      redirect_to community_post_path(debrief), status: :see_other
    end

    def require_member_access
      head :forbidden unless Membership::Access.allowed?(user: current_user)
    end

    def post_id
      discussion_id(params[:id])
    end

    def curation_id
      discussion_id(request.path_parameters[:post_id])
    end

    def nominated_film_id
      discussion_id(request.path_parameters[:film_id])
    end

    def discussion_id(value)
      raise ActionController::BadRequest unless RecordId.valid?(value)

      value.to_i
    end

    def library_action_unavailable
      redirect_to community_post_path(curation_id), alert: t("community.curations.library_action_unavailable"), status: :see_other
    end

    def publication_fields
      fields = curation_fields
      title, prompt = text_fields(fields)
      film_ids, comments = CurationFilmSelectionParameters.parse(ids: fields[:reference_film_ids], comments: fields[:reference_comments])
      [ title, prompt, film_ids, comments ]
    end

    def curation_fields
      fields = params[:curation]
      raise ActionController::BadRequest unless fields.is_a?(ActionController::Parameters)

      fields
    end

    def text_fields(fields)
      title, prompt = fields.values_at(:title, :prompt)
      unless [ title, prompt ].all? { |value| value.nil? || value.is_a?(String) }
        raise ActionController::BadRequest
      end

      [ title, prompt ]
    end

    def render_form(curation, reference_film_ids: [], reference_comments: {}, status: :ok)
      films = Curations::EligibleCurationFilms.new(member: current_user).choices
      render Views::Community::NewCuration.new(curation:, films:, reference_film_ids:, reference_comments:), status:
    end
  end
end
