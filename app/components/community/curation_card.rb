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
          tags = CurationTag.new(post_id: @curation.id, protected_post: @curation.protected?)
          attribution = CurationAttribution.new(curation: @curation, class_name: "muted community-post-card-attribution community-curation-card-author")
          render PostCardDetails.new(title_id:, below_title: tags, attribution:, status: method(:post_status)) { @curation.title }
        end
      end
    end

    private

    def post_status
      ul(class: "community-curation-card-counts") do
        li { t("community.curations.films", count: @entry.film_count) }
        li { t("community.curations.endorsements", count: @entry.endorsement_count) }
        li { t("community.curations.comments", count: @entry.comment_count) }
      end
    end
  end
end
