require "aws-sdk-s3"

module Identity
  module AccountAdministration
    class DeletionLog
      UUID = /\A[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/
      NAMESPACE = /\A[a-z0-9][a-z0-9_-]{0,63}\z/

      def self.writer
        if Rails.env.test? && ENV["ACCOUNT_DELETION_R2_ENDPOINT"].blank?
          return new(client: Aws::S3::Client.new(region: "auto", stub_responses: true),
            bucket: "test-account-deletions", namespace: "test")
        end

        configured("WRITER")
      end

      def self.reader
        configured("READER")
      end

      def self.configured(role)
        endpoint, bucket, namespace = %w[ENDPOINT BUCKET NAMESPACE].map { |key| ENV["ACCOUNT_DELETION_R2_#{key}"] }
        access_key_id, secret_access_key = %w[ACCESS_KEY_ID SECRET_ACCESS_KEY].map do |key|
          ENV["ACCOUNT_DELETION_R2_#{role}_#{key}"]
        end
        unless endpoint&.match?(%r{\Ahttps://[a-f0-9]{32}(?:\.(?:eu|us|fedramp))?\.r2\.cloudflarestorage\.com/?\z}) &&
            bucket.present? && namespace&.match?(NAMESPACE) && access_key_id.present? && secret_access_key.present?
          raise Errors::DeletionLogUnavailable, "Incomplete R2 deletion log configuration"
        end

        client = Aws::S3::Client.new(endpoint:, region: "auto", credentials: Aws::Credentials.new(access_key_id, secret_access_key),
          force_path_style: true, http_open_timeout: 3, http_read_timeout: 5, retry_limit: 0,
          request_checksum_calculation: "when_required", response_checksum_validation: "when_required")
        new(client:, bucket:, namespace:)
      end
      private_class_method :configured

      def initialize(client:, bucket:, namespace:)
        @client = client
        @bucket = bucket
        @prefix = "account-deletions/v1/#{namespace}/"
      end

      def record!(account_id:)
        key = key_for(account_id)
        @client.put_object(bucket: @bucket, key:, if_none_match: "*", content_type: "application/json",
          body: JSON.generate(account_id:, recorded_at: Time.current.utc.iso8601(6)))
      rescue Aws::S3::Errors::ServiceError => error
        # A retry may find a committed write protected by either the precondition or the bucket lock.
        if error.context.http_response.status_code == 412 || error.code == "ObjectLockedByBucketPolicy"
          with_log_errors { read_account_id(key) }
        else
          raise Errors::DeletionLogUnavailable, "R2 rejected the deletion record", cause: nil
        end
      rescue Seahorse::Client::NetworkingError
        raise Errors::DeletionLogUnavailable, "R2 deletion log is unreachable", cause: nil
      end

      def account_ids
        with_log_errors do
          @client.list_objects_v2(bucket: @bucket, prefix: @prefix).flat_map do |page|
            page.contents.map { |object| read_account_id(object.key) }
          end
        end
      end

      private

      def read_account_id(key)
        body = @client.get_object(bucket: @bucket, key:).body.read(1025)
        raise Errors::DeletionLogUnavailable, "Invalid deletion record" unless body && body.bytesize <= 1024

        record = JSON.parse(body)
        unless record.is_a?(Hash) && record.keys.sort == %w[account_id recorded_at] &&
            key == key_for(record["account_id"]) && record["recorded_at"].is_a?(String)
          raise Errors::DeletionLogUnavailable, "Invalid deletion record"
        end

        Time.iso8601(record["recorded_at"])
        record["account_id"]
      rescue JSON::ParserError, ArgumentError
        raise Errors::DeletionLogUnavailable, "Invalid deletion record", cause: nil
      end

      def key_for(account_id)
        unless account_id.is_a?(String) && account_id.match?(UUID)
          raise Errors::DeletionLogUnavailable, "Invalid account deletion replay ID"
        end

        "#{@prefix}#{account_id}.json"
      end

      def with_log_errors
        yield
      rescue Aws::S3::Errors::ServiceError, Seahorse::Client::NetworkingError
        raise Errors::DeletionLogUnavailable, "Could not read the R2 deletion log", cause: nil
      end
    end
  end
end
