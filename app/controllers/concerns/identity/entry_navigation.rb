module Identity
  module EntryNavigation
    extend ActiveSupport::Concern

    included { helper_method :browsing_path }

    private

    def browsing_path
      root_path
    end

    def remember_entry_destination
      destination = Identity::ReturnDestination.capture(request.fullpath)
      session[:entry_destination] = destination if destination.present?
    end

    def entry_destination
      destination = Identity::ReturnDestination.resolve(session.delete(:entry_destination))
      destination || current_user.default_entry_path
    end
  end
end
