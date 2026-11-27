module Community
  class CurationCard < Shared::Base
    def initialize(entry:)
      @entry = entry
      @curation = entry.curation
    end

    def view_template
      title_id = "curation-#{@curation.id}-title"
      article do
        a(class: "community-curation-card", href: community_post_path(@curation), aria: { labelledby: title_id }) do
          div(class: "community-post-card-artwork community-curation-card-posters", data: { poster_count: @entry.poster_films.size }) do
            @entry.poster_films.each { |film| render ::Registry::FilmPoster.new(film:, placeholder: :wordmark) }
          end
          div(class: "community-post-card-details") do
            div(class: "community-post-card-heading") do
              h2(id: title_id) { @curation.title }
              render CurationTag.new(post_id: @curation.id, protected_post: @curation.protected?)
            end
            post_metadata
          end
        end
      end
    end

    private

    def post_metadata
      footer(class: "community-post-card-footer") do
        ul(class: "muted community-curation-card-counts") do
          li { t("community.curations.films", count: @entry.film_count) }
          li { t("community.curations.endorsements", count: @entry.endorsement_count) }
          li { t("community.curations.comments", count: @entry.comment_count) }
        end
        attribution
      end
    end

    def attribution
      community_user = @curation.community_user
      div(class: "muted community-curation-card-author") do
        if community_user.present?
          render MemberAvatar.new(community_user:)
          strong { community_user.community_username.presence || t("community.curations.member") }
        else
          plain t("community.curation_protection.unattributed")
        end
      end
    end
  end
end
