module Library
  class RatingIndicator < Shared::Base
    def initialize(value:, notes: false)
      @value, @notes = value, notes
    end

    def view_template
      render Ratings::RatingValueIcon.new(value: @value)
      span(class: "library-rating-notes-badge", aria: { hidden: true }) { render NotesIcon.new } if @notes
    end
  end
end
