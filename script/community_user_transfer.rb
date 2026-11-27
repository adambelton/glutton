# Run through bin/rails runner. The export mode also runs with the legacy application.
require "json"

class CommunityUserTransfer
  def initialize(connection:, database:)
    @connection, @database = connection, database
  end

  def export(path)
    snapshot = @connection.transaction(isolation: :repeatable_read) do
      ownership(legacy: true).merge("database" => @database, "version" => 1, "profiles" => legacy_profiles)
    end
    File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |file| file.write(JSON.generate(snapshot)) }
    report_counts("Exported", snapshot)
  end

  def import(path)
    snapshot = JSON.parse(File.read(path))
    unless snapshot.fetch("database") == @database && snapshot.fetch("version") == 1
      raise "The CommunityUser export does not match this database or transfer version"
    end

    Community::CommunityUser.transaction do
      ownership(legacy: false).each do |key, current|
        raise "The #{key} authorship has changed since the CommunityUser export" unless snapshot.fetch(key) == current
      end
      imported_profiles = profile_rows.index_by { |row| row.fetch("user_id") }
      snapshot.fetch("profiles").each do |attributes|
        user_id = attributes.fetch("user_id")
        if imported_profiles.key?(user_id)
          raise "Community profile conflict for account #{user_id}" unless imported_profiles.fetch(user_id) == attributes
        else
          Community::CommunityUser.create!(attributes)
        end
      end

      @connection.validate_foreign_key :posts, :community_users, column: :community_user_id
      @connection.validate_foreign_key :posts, :community_users, column: :deletable_community_user_id
      @connection.validate_foreign_key :comment_contents, :community_users, column: :community_user_id
    end
    report_counts("Imported", snapshot)
  end

  private

  def ownership(legacy:)
    attribution_column, deletion_column = legacy ? %w[author_id deletable_author_id] : %w[community_user_id deletable_community_user_id]
    {
      "posts" => @connection.select_all(<<~SQL).to_a,
        SELECT id, #{attribution_column} AS community_user_id, #{deletion_column} AS deletable_community_user_id FROM posts
        WHERE #{attribution_column} IS NOT NULL OR #{deletion_column} IS NOT NULL ORDER BY id
      SQL
      "comment_contents" => @connection.select_all("SELECT id, #{attribution_column} AS community_user_id FROM comment_contents ORDER BY id").to_a
    }
  end

  def legacy_profiles
    @connection.select_all(<<~SQL).to_a
      SELECT id AS user_id, community_username, community_avatar_preset
      FROM users
      WHERE type = 'UserRegistered' AND (
        num_nonnulls(community_username, community_avatar_preset, community_code_of_conduct_accepted_at) > 0
        OR id IN (
          SELECT author_id FROM posts
          UNION SELECT deletable_author_id FROM posts
          UNION SELECT author_id FROM comment_contents
        )
      )
      ORDER BY id
    SQL
  end

  def profile_rows
    @connection.select_all("SELECT user_id, community_username, community_avatar_preset FROM community_users").to_a
  end

  def report_counts(operation, snapshot)
    puts "#{operation} #{snapshot.fetch("profiles").size} profiles, #{snapshot.fetch("posts").size} post references, " \
      "and #{snapshot.fetch("comment_contents").size} comment references"
  end
end

mode, path = ARGV
abort "Usage: bin/rails runner script/community_user_transfer.rb export|import PATH" unless %w[export import].include?(mode) && path.present?
database = ActiveRecord::Base.connection_pool.db_config.database
abort "Use a local rehearsal database or glutton_staging" unless Rails.env.local? || database == "glutton_staging"
ActiveRecord::Base.with_connection do |connection|
  transfer = CommunityUserTransfer.new(connection:, database:)
  mode == "export" ? transfer.export(path) : transfer.import(path)
end
