module Community
  class DeliverCommentNotificationJob < ApplicationJob
    # GoodJob persists the job in the same database transaction as the comment.
    self.enqueue_after_transaction_commit = false

    retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer

    def self.enqueue!(content_id)
      perform_later(content_id) || raise(ActiveJob::EnqueueError, "Could not enqueue Community comment notification")
    end

    def perform(content_id)
      Notifications::DeliverComment.call(content_id:)
    end
  end
end
