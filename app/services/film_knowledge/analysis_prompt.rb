require "open3"
require "digest"

module FilmKnowledge
  class AnalysisPrompt
    def self.call(version: nil, label: nil, command_runner: Open3, environment: ENV)
      unless (version.is_a?(Integer) && version.positive? && label.nil?) || (version.nil? && label == "development")
        raise ArgumentError, "Choose an explicit positive prompt version or the development label"
      end
      selector = version ? [ "--version", version.to_s ] : [ "--label", label ]
      output, _errors, status = command_runner.capture3(
        { "LANGFUSE_HOST" => environment.fetch("LANGFUSE_BASE_URL") },
        "npx", "--yes", "langfuse-cli", "api", "prompts", "get", "film-analysis", *selector, "--json"
      )
      raise GenerationFailed.new(:prompt_retrieval) unless status.success?
      prompt = JSON.parse(output).fetch("body")
      unless prompt["name"] == "film-analysis" && prompt["type"] == "text" &&
          prompt["version"].is_a?(Integer) && prompt["prompt"].is_a?(String) && prompt["prompt"].present? &&
          prompt.dig("config", "contract") == "tmdb-analysis-v1" && (!version || prompt["version"] == version)
        raise GenerationFailed.new(:incompatible_prompt)
      end
      prompt.slice("name", "version", "prompt", "config").merge("sha256" => Digest::SHA256.hexdigest(prompt["prompt"]))
    rescue JSON::ParserError, KeyError
      raise GenerationFailed.new(:prompt_retrieval), cause: nil
    end
  end
end
