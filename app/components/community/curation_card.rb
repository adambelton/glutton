module Community
  class CurationCard < Shared::Base
    def initialize(entry:)
      @entry = entry
      @curation = entry.curation
    end

    def view_template
      title_id = "curation-#{@curation.id}-title"
      article do
        a(class: "community-curation-card", href: community_curation_path(@curation), aria: { labelledby: title_id }) do
          div(class: "community-curation-card-heading") do
            h2(id: title_id) { @curation.title }
            render CurationTag.new(post_id: @curation.id, protected_post: @curation.protected?)
          end
          div(class: "community-curation-card-posters") do
            @entry.poster_films.each { |film| render ::Registry::FilmPoster.new(film:, placeholder: :wordmark) }
          end
          footer(class: "community-curation-card-footer") do
            ul(class: "muted community-curation-card-counts") do
              author_identity
              li { t("community.curations.films", count: @entry.film_count) }
              li { t("community.curations.endorsements", count: @entry.endorsement_count) }
              li { t("community.curations.comments", count: @entry.comment_count) }
            end
            updated_timestamp
          end
        end
      end
    end

    private

    def author_identity
      author = @curation.author
      li(class: "community-curation-card-author") do
        if author.present?
          render MemberAvatar.new(member: author)
          strong { author.community_username.presence || t("community.curations.member") }
        else
          plain t("community.curation_protection.unattributed")
        end
      end
    end

    def updated_timestamp
      updated_at = @curation.updated_at
      span(class: "muted community-curation-card-timestamp") do
        plain t("community.curations.updated")
        plain " "
        time(datetime: updated_at.iso8601) { I18n.l(updated_at, format: :community_curation_card) }
      end
    end
  end
end
