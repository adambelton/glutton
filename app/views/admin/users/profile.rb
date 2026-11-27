module Views
  module Admin
    module Users
      class Profile < ::Views::Admin::Base
        def initialize(user_id:, profile:)
          @user_id, @profile = user_id, profile
        end

        def view_template
          dashboard(title: t("ratings.profile_inspection.title", id: @user_id), resource: :users,
            back_to: admin_user_path(@user_id), back_label: t("ratings.profile_inspection.back")) do
            profile_narrative
            div(class: "admin-profile-rankings") do
              @profile.fetch(:quality_rankings).each { |kind, qualities| ranked_qualities(kind, qualities) }
            end
            saved_claims
          end
        end

        private

        def profile_narrative
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
        end

        def saved_claims
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

        def claim_with_evidence(claim)
          article do
            h3 { claim.fetch(:claim) }
            p { claim.fetch(:explanation) }
            ul do
              claim.fetch(:citations).each do |citation|
                li do
                  p do
                    render ::Registry::FilmTitle.new(title: citation.fetch(:title), release_date: citation.fetch(:release_date))
                    plain " · "
                    plain t("ratings.profile_inspection.citation_revision", id: citation.fetch(:rating_id))
                  end
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
                qualities.each { |quality| li { render Shared::ProfileQualityExpansionItem.new(quality:) } }
              end
            end
          end
        end
      end
    end
  end
end
