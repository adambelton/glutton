module Community
  class CurationCard < Shared::Base
    def initialize(entry:)
      @entry = entry
      @curation = entry.curation
    end

    def view_template
      title_id = "curation-#{@curation.id}-title"
      username = @curation.author.community_username.presence || t("community.curations.member")
      article do
        a(class: "community-curation-card", href: community_curation_path(@curation), aria: { labelledby: title_id }) do
          div(class: "community-curation-card-content") do
            div(class: "community-curation-card-heading") do
              h2(id: title_id) { @curation.title }
              render CurationTag.new
            end
            p(class: "muted community-curation-card-byline") { t("community.curations.authored_by", username:) }
          end
          div(class: "community-curation-card-posters") do
            @entry.poster_films.each { |film| render ::Registry::FilmPoster.new(film:, placeholder: :wordmark) }
          end
          footer(class: "community-curation-card-footer") do
            ul(class: "muted community-curation-card-counts") do
              li { t("community.curations.films", count: @entry.film_count) }
              li { t("community.curations.endorsements", count: @entry.endorsement_count) }
              li { t("community.curations.comments", count: @entry.comment_count) }
            end
            div(class: "muted community-curation-card-timestamps") do
              timestamp(:updated, @curation.updated_at)
              timestamp(:created, @curation.created_at)
            end
          end
        end
      end
    end

    private

    def timestamp(label, value)
      span do
        plain t("community.curations.#{label}")
        plain " "
        time(datetime: value.iso8601) { I18n.l(value, format: :community_curation_card) }
      end
    end
  end
end
