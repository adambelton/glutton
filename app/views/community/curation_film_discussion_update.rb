module Views
  module Community
    class CurationFilmDiscussionUpdate < Shared::Base
      def initialize(curation:, film_id:, discussion:, can_reply:)
        @curation, @film_id, @discussion, @can_reply = curation, film_id, discussion, can_reply
      end

      def view_template
        tag(:"turbo-stream", action: "replace", target: "film-discussion-#{@film_id}") do
          tag(:template) do
            render ::Community::CurationComments.new(curation: @curation, film_id: @film_id, discussion: @discussion, can_reply: @can_reply)
          end
        end
      end
    end
  end
end
