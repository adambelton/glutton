module Identity
  module AccountAdministration
    module InspectUsers
      PAGE_SIZE = 10
      Page = Data.define(:entries, :number, :total, :total_pages)

      def self.page(number:, query:)
        users = User.order(id: :desc)
        if query.match?(/\A[0-9]{1,18}\z/)
          users = users.where(id: query.to_i)
        elsif query.present?
          users = users.where("email_address ILIKE ?", "%#{User.sanitize_sql_like(query)}%")
        end

        total = users.count
        entries = users.offset((number - 1) * PAGE_SIZE).limit(PAGE_SIZE).to_a
        Page.new(entries:, number:, total:, total_pages: [ (total.to_f / PAGE_SIZE).ceil, 1 ].max)
      end

      def self.detail(user_id:)
        user = User.find_by(id: user_id) || raise(Errors::Unavailable)
        { user:, sessions: Session.where(user_id: user.id).order(id: :desc) }
      end
    end
  end
end
