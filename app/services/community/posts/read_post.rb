module Community
  module Posts
    class ReadPost
      def self.call(id:, viewer:, lock: false)
        Membership::Access.require!(user: viewer)
        post = Post.find(id)
        post.require_view_access!(viewer:, lock:)
        post.lock! if lock
        post
      end
    end
  end
end
