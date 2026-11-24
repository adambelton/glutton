module Views
  module Community
    class CurationCommentDeleted < Shared::Base
      def initialize(curation:, film_id:, discussion:, can_reply:)
        @curation, @film_id, @discussion, @can_reply = curation, film_id, discussion, can_reply
      end

      def view_template
        tag(:"turbo-stream", action: "replace", target: "film-discussion-#{@film_id}") do
          tag(:template) do
            render ::Community::CurationComments.new(curation: @curation, film_id: @film_id, discussion: @discussion,
              endorsements: @discussion.endorsements_for_film(@film_id), can_reply: @can_reply)
          end
        end
      end
    end
  end
end
