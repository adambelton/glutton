module Views
  module Community
    class FilmDebriefDiscussionUpdated < Shared::Base
      def initialize(debrief:, discussion:, can_reply:)
        @debrief, @discussion, @can_reply = debrief, discussion, can_reply
      end

      def view_template
        tag(:"turbo-stream", action: "replace", target: ::Community::FilmDebriefDiscussion.section_id(@debrief)) do
          tag(:template) do
            render ::Community::FilmDebriefDiscussion.new(debrief: @debrief, discussion: @discussion, can_reply: @can_reply)
          end
        end
      end
    end
  end
end
