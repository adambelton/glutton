module Ratings
  class Choice < Shared::Base
    def initialize(value:, label:, input_id: nil)
      @value, @label, @input_id = value, label, input_id
    end

    def view_template(&)
      div(class: "rating-choice") do
        if @input_id.present?
          yield
          label(for: @input_id, class: "rating-choice-caption") do
            render RatingValueIcon.new(value: @value)
            span(id: "#{@input_id}-label", data: { rating_vocabulary_picker_target: "sample", value: @value }) { @label }
          end
        else
          div(class: "rating-choice-caption") do
            render RatingValueIcon.new(value: @value)
            span(data: { rating_vocabulary_picker_target: "sample", value: @value }) { @label }
          end
        end
      end
    end
  end
end
