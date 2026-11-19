module Admin
  module Users
    class Profile < Shared::Base
      def initialize(user_id:, profile:)
        @user_id, @profile = user_id, profile
      end

      def view_template
        section(class: "admin-detail-section", aria: { labelledby: "profile-narrative-heading" }) do
          h2(id: "profile-narrative-heading") { t("ratings.profile_inspection.narrative") }
          revision = @profile.fetch(:revision)
          if revision.present?
            p(class: "muted") { t("ratings.profile_inspection.revision", id: revision.id, time: I18n.l(revision.created_at, format: :long)) }
          end
          if @profile[:profile].present?
            div(class: "profile-narrative") { @profile.fetch(:profile) }
          else
            p { t("account.empty") }
          end
        end
        div(class: "admin-profile-rankings") do
          @profile.fetch(:quality_rankings).each { |kind, qualities| ranked_qualities(kind, qualities) }
        end
        section(class: "admin-detail-section profile-saved-claims", aria: { labelledby: "saved-claims-heading" }) do
          h2(id: "saved-claims-heading") { t("ratings.profile_inspection.claims") }
          claims = @profile.fetch(:claims)
          if claims.empty?
            p { t("ratings.profile_inspection.no_claims") }
          else
            claims.each { |claim| claim_with_evidence(claim) }
          end
        end
      end

      private

      def claim_with_evidence(claim)
        article do
          h3 { claim.fetch(:claim) }
          p { claim.fetch(:explanation) }
          ul do
            claim.fetch(:citations).each do |citation|
              li do
                p { t("ratings.profile_inspection.citation", title: citation.fetch(:title), id: citation.fetch(:rating_id)) }
                blockquote { citation.fetch(:quote) }
              end
            end
          end
        end
      end

      def ranked_qualities(kind, qualities)
        section(class: "admin-detail-section") do
          h2 { t("account.quality_rankings.#{kind}") }
          if qualities.empty?
            p { t("account.quality_rankings.#{kind}_empty") }
          else
            ul do
              qualities.each do |quality|
                li do
                  details do
                    summary do
                      span { quality.fetch(:name) }
                      span { "%+d" % quality.fetch(:score) }
                    end
                    p { quality.fetch(:definition).presence || t("account.quality_rankings.definition_unavailable") }
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
