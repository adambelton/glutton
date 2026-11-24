module Community
  class PublishCuration
    def self.call(author_id:, title:, prompt:, reference_film_ids:, reference_comments:)
      PostCommunityCuration.transaction do
        author = Identity::UserRegistered.lock.find_by(id: author_id)
        raise Errors::PostingUnavailable unless author.present? && PostingAccess.allowed?(user: author)

        PostCommunityCuration.new(author:, title:, prompt:).publish(reference_film_ids:, reference_comments:) do |film_ids|
          CurationReferenceFilms.new(author:).for_publication(film_ids:)
        end
      end
    end
  end
end
