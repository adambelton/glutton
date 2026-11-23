module Community
  class CodeOfConductText < Shared::Base
    def initialize(code:, nested: false)
      @code = code
      @topic_heading = nested ? :h3 : :h2
    end

    def view_template
      scope = @code.translation_scope
      div(class: "community-conduct-text") do
        p { t("#{scope}.intro") }
        %i[respect spoilers avatars moderation].each do |topic|
          section do
            public_send(@topic_heading) { t("#{scope}.#{topic}.title") }
            p { t("#{scope}.#{topic}.description") }
          end
        end
        section do
          public_send(@topic_heading) { t("#{scope}.copyright.title") }
          p { t("#{scope}.copyright.description") }
          text_link(t("#{scope}.copyright.email"), "mailto:#{t("#{scope}.copyright.email")}")
        end
      end
    end
  end
end
