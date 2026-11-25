module Community
  module FilmDebriefControllerAccess
    extend ActiveSupport::Concern

    included do
      rescue_from Errors::MembershipRequired, Errors::PostingUnavailable, Errors::CommentChangeUnavailable, with: -> { head :forbidden }
      rescue_from Errors::FilmDebriefUnavailable, ActiveRecord::RecordNotFound, with: -> { head :not_found }
    end

    private

    def film_id
      discussion_id(params[:film_id])
    end

    def discussion_id(value)
      raise ActionController::BadRequest unless FilmId.valid?(value)

      value.to_i
    end
  end
end
