module Shared
  class FilmSearchResultRow < Base
    def initialize(title:, release_date:, poster:, data:, link: nil, overview: nil, status: nil, icon_actions: false)
      @title, @release_date, @poster, @data = title, release_date, poster, data
      @link, @overview, @status = link, overview, status
      @icon_actions = icon_actions
    end

    def view_template
      li(data: @data) do
        render @poster
        div(class: "film-search-result-body") do
          div(class: "film-search-result-details") do
            h3 do
              if @link.present?
                a(**@link) { film_title }
              else
                film_title
              end
            end
            p(class: "film-search-overview") { @overview } if @overview.present?
            p { @status } if @status.present?
          end
          if block_given?
            div(class: [ "film-search-actions", ("film-search-text-actions" unless @icon_actions) ]) { yield }
          end
        end
      end
    end

    private

    def film_title
      render ::Registry::FilmTitle.new(title: @title, release_date: @release_date)
    end
  end
end
