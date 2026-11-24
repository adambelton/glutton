module Identity
  module AccountAdministration
    module BrowseUsers
      PAGE_SIZE = 10

      def self.page(number:, query:)
        users = User.order(id: :desc)
        if query.match?(/\A[0-9]{1,18}\z/)
          users = users.where(id: query.to_i)
        elsif query.present?
          users = users.where("email_address ILIKE ?", "%#{User.sanitize_sql_like(query)}%")
        end

        CountedPage.load(users, number:, page_size: PAGE_SIZE)
      end

      def self.detail(user_id:)
        user = User.find_by(id: user_id) || raise(Errors::Unavailable)
        { user:, sessions: Session.where(user_id: user.id).order(id: :desc) }
      end
    end
  end
end
