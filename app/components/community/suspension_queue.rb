module Community
  class SuspensionQueue < Shared::Base
    def initialize(suspensions:, state:)
      @suspensions = suspensions
      @lifted = state == "lifted"
    end

    def view_template
      if @suspensions.any?
        suspension_table
      else
        p(class: "ui-empty") { t(@lifted ? "community.suspensions.none_lifted" : "community.suspensions.none") }
      end
    end

    private

    def suspension_table
      caption = t(@lifted ? "community.suspensions.lifted_tab" : "community.suspensions.active")
      render RubyUI::Table.new(scroll_label: caption, class: "ui-collection-table") do
        render RubyUI::TableCaption.new(class: "sr-only") { caption }
        render RubyUI::TableHeader.new do
          render RubyUI::TableRow.new do
            [ "member", "suspended_at", (@lifted ? "lifted_at" : "action") ].each do |column|
              render Shared::TableCell.new(heading: true) { t("community.suspensions.table.#{column}") }
            end
          end
        end
        render RubyUI::TableBody.new do
          @suspensions.each { |suspension| suspension_row(suspension) }
        end
      end
    end

    def suspension_row(suspension)
      render RubyUI::TableRow.new do
        render Shared::TableCell.new { member_name(suspension.member) }
        render Shared::TableCell.new { timestamp(suspension.suspended_at) }
        if @lifted
          render Shared::TableCell.new { timestamp(suspension.lifted_at) }
        else
          td(class: "ui-table-action-cell") do
            render Shared::ActionForm.new(url: lift_community_suspension_path(suspension), method: :patch) do
              render Shared::GhostButton.new(type: :submit) { t("community.suspensions.lift") }
            end
          end
        end
      end
    end

    def timestamp(value)
      time(datetime: value.iso8601) { I18n.l(value, format: :long) }
    end

    def member_name(member)
      member.community_user&.community_username.presence || t("community.reports.resolution.moderator_account", id: member.id)
    end
  end
end
