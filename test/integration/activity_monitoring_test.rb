require "test_helper"
require "active_support/testing/constant_stubbing"
require_relative "../support/assessed_recommendation_films"

class ActivityMonitoringTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::ConstantStubbing
  include AssessedRecommendationFilms

  test "successful reads and polls are ignored while submissions and recommendation ranking are retained" do
    namespaces = []
    sdk = Module.new
    sdk.define_singleton_method(:active?) { true }
    sdk.define_singleton_method(:set_namespace) { |name| namespaces << name }

    stub_const(Object, :Appsignal, sdk, exists: Object.const_defined?(:Appsignal)) do
      get root_path
      assert_equal [ "routine_activity" ], namespaces

      post guest_session_path
      assert_response :redirect
      assert_equal 1, namespaces.size
      get availability_recommendation_path
      assert_response :accepted
      assert_equal 2, namespaces.size

      user = Identity::UserGuest.last
      unlock_recommendations_for(user:)
      Registry::Film.create!(title: "Candidate")
      get recommendation_path
      assert_response :success
      assert_equal 2, namespaces.size
      get recommendation_path
      assert_response :success
      assert_equal 3, namespaces.size

      Ratings::RefreshTasteProfilesJob.perform_now
      assert_equal 4, namespaces.size
    end
  end
end
