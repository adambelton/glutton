module Community
  class CurationsController < ApplicationController
    before_action :require_member_access
    rescue_from Errors::MembershipRequired, Identity::Errors::Unavailable, with: -> { head :forbidden }
    rescue_from Errors::CurationEditUnavailable, Errors::CurationDeletionUnavailable, with: -> { head :forbidden }
    rescue_from Errors::NominationUnavailable, with: -> { head :not_found }
    rescue_from Library::Errors::AddToWatchlistUnavailable, Library::Errors::AddToWatchedUnavailable,
      Library::Errors::FilmUnavailable, Library::Errors::AlreadyWatched, Library::Errors::NotOnWatchlist, with: :library_action_unavailable

    def new
      return head :forbidden unless Membership::PostingAccess.allowed?(user: current_user)

      render_form(PostCommunityCuration.new)
    end

    def create
      title, prompt, reference_film_ids, reference_comments = publication_fields
      curation = Curations::PublishCuration.call(author_id: current_user.id, title:, prompt:, reference_film_ids:, reference_comments:)
      if curation.errors.any?
        return render_form(curation, reference_film_ids:, reference_comments:, status: :unprocessable_content)
      end

      redirect_to community_curation_path(curation), notice: t("community.curations.published"), status: :see_other
    rescue Errors::PostingUnavailable
      head :forbidden
    end

    def show
      details = Curations::ReadCuration.call(id: params[:id], viewer: current_user, selected_reply_id: params[:reply],
        expand_selected_branch: params[:replies] == "1")
      render Views::Community::Curation.new(**details)
    end

    def discussion
      page = Discussions::BrowseCurationDiscussion.call(curation_id: params[:id], film_id: discussion_id(params[:film_id]),
        parent_id: (discussion_id(params[:parent_id]) if params.key?(:parent_id)),
        after: (discussion_id(params[:after]) if params.key?(:after)), viewer: current_user)
      curation = page.delete(:curation)
      routes = CurationDiscussionRoutes.new(curation:, film_id: page.fetch(:film_id))
      render DiscussionCommentPage.new(routes:, **page), content_type: Mime[:html]
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

      redirect_to community_curation_path(curation), notice: t("community.curation_editing.saved"), status: :see_other
    end

    def destroy
      Curations::DeleteCuration.call(curation_id: params[:id], member_id: current_user.id)
      redirect_to community_path, notice: t("community.curation_deletion.deleted"), status: :see_other
    end

    def additional_description
      description = curation_fields[:additional_description]
      raise ActionController::BadRequest unless description.is_a?(String)

      curation = Curations::ManageCurationAuthorship.update_description(curation_id: params[:id], member_id: current_user.id,
        additional_description: description)
      return render Views::Community::EditCuration.new(curation:), status: :unprocessable_content if curation.errors.any?

      redirect_to community_curation_path(curation), notice: t("community.curation_protection.description_saved"), status: :see_other
    end

    def disassociate
      Curations::ManageCurationAuthorship.disassociate(curation_id: params[:id], member_id: current_user.id)
      redirect_to community_curation_path(params[:id]), notice: t("community.curation_protection.disassociated"), status: :see_other
    end

    def watchlist
      Curations::ManageCurationFilmInLibrary.add_to_watchlist(curation_id: params[:id], user_id: current_user.id, film_id: nominated_film_id)
      redirect_to community_curation_path(params[:id]), notice: t("library.detail.watchlisted"), status: :see_other
    end

    def watched
      Curations::ManageCurationFilmInLibrary.mark_watched(curation_id: params[:id], user_id: current_user.id, film_id: nominated_film_id)
      redirect_to community_curation_path(params[:id]), notice: t("library.detail.watched"), status: :see_other
    end

    private

    def require_member_access
      head :forbidden unless Membership::Access.allowed?(user: current_user)
    end

    def nominated_film_id
      discussion_id(params[:film_id])
    end

    def discussion_id(value)
      raise ActionController::BadRequest unless FilmId.valid?(value)

      value.to_i
    end

    def library_action_unavailable
      redirect_to community_curation_path(params[:id]), alert: t("community.curations.library_action_unavailable"), status: :see_other
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
