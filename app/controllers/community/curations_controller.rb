module Community
  class CurationsController < ApplicationController
    before_action :require_preview_access
    rescue_from Errors::MembershipRequired, Identity::Errors::Unavailable, with: -> { head :forbidden }
    rescue_from Errors::NominationUnavailable, with: -> { head :not_found }
    rescue_from Library::Errors::AddToWatchlistUnavailable, Library::Errors::AddToWatchedUnavailable,
      Library::Errors::FilmUnavailable, Library::Errors::AlreadyWatched, Library::Errors::NotOnWatchlist, with: :library_action_unavailable

    def new
      return head :forbidden unless PostingAccess.allowed?(user: current_user)

      render_form(PostCommunityCuration.new)
    end

    def create
      title, prompt, reference_film_ids, reference_comments = publication_fields
      curation = PublishCuration.call(author_id: current_user.id, title:, prompt:, reference_film_ids:, reference_comments:)
      if curation.errors.any?
        return render_form(curation, reference_film_ids:, reference_comments:, status: :unprocessable_content)
      end

      redirect_to community_curation_path(curation), notice: t("community.curations.published"), status: :see_other
    rescue Errors::PostingUnavailable
      head :forbidden
    end

    def show
      render Views::Community::Curation.new(**BrowseCurations.detail(id: params[:id], viewer: current_user))
    end

    def watchlist
      ManageCurationFilmInLibrary.add_to_watchlist(curation_id: params[:id], user_id: current_user.id, film_id: nominated_film_id)
      redirect_to community_curation_path(params[:id]), notice: t("library.detail.watchlisted"), status: :see_other
    end

    def watched
      ManageCurationFilmInLibrary.mark_watched(curation_id: params[:id], user_id: current_user.id, film_id: nominated_film_id)
      redirect_to community_curation_path(params[:id]), notice: t("library.detail.watched"), status: :see_other
    end

    private

    def require_preview_access
      head :forbidden unless PreviewAccess.allowed?(user: current_user)
    end

    def nominated_film_id
      film_id = params[:film_id]
      raise ActionController::BadRequest unless valid_film_id?(film_id)

      film_id.to_i
    end

    def library_action_unavailable
      redirect_to community_curation_path(params[:id]), alert: t("community.curations.library_action_unavailable"), status: :see_other
    end

    def publication_fields
      fields = params[:curation]
      raise ActionController::BadRequest unless fields.is_a?(ActionController::Parameters)

      title, prompt, ids = fields.values_at(:title, :prompt, :reference_film_ids)
      ids = [] if ids.nil?
      unless [ title, prompt ].all? { |value| value.nil? || value.is_a?(String) } &&
          ids.is_a?(Array) && ids.all? { |id| valid_film_id?(id) }
        raise ActionController::BadRequest
      end

      [ title, prompt, ids.map(&:to_i), reference_comments(fields[:reference_comments], ids:) ]
    end

    def valid_film_id?(id)
      id.is_a?(String) && id.match?(/\A[1-9][0-9]{0,18}\z/) && id.to_i <= 2**63 - 1
    end

    def reference_comments(comments, ids:)
      return {} if comments.nil?

      unless comments.is_a?(ActionController::Parameters) &&
          comments.each_pair.all? { |id, body| ids.include?(id) && body.is_a?(String) }
        raise ActionController::BadRequest
      end

      comments.each_pair.to_h.transform_keys(&:to_i)
    end

    def render_form(curation, reference_film_ids: [], reference_comments: {}, status: :ok)
      films = CurationReferenceFilms.new(author: current_user).choices
      render Views::Community::NewCuration.new(curation:, films:, reference_film_ids:, reference_comments:), status:
    end
  end
end
