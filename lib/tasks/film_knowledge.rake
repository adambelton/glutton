namespace :film_knowledge do
  desc "Load three development sample film identities without changing existing metadata"
  task load_sample: :environment do
    films = FilmKnowledge::LoadDevelopmentSample.call
    puts "sample_films=#{films.size}"
  end
end

namespace :film_knowledge do
  desc "Import one TMDB film and generate unpublished analysis (one paid request)"
  task generate_analysis: :environment do
    generator = FilmKnowledge::GenerateAnalysis.new
    begin
      model = ENV.fetch("OPENAI_MODEL")
      cap = Integer(ENV.fetch("ANALYSIS_MAX_OUTPUT_TOKENS"), 10)
      version = ENV["ANALYSIS_PROMPT_VERSION"] && Integer(ENV["ANALYSIS_PROMPT_VERSION"], 10)
      film = FilmKnowledge::ImportTmdbFilm.call(tmdb_id: Integer(ENV.fetch("TMDB_ID"), 10), ensure_metadata: true)
      analysis = generator.call(film:, model:, max_output_tokens: cap,
        output_directory: ENV.fetch("ANALYSIS_OUTPUT_DIRECTORY", Rails.root.join("tmp/film_analysis_runs").to_s),
        version:, label: version ? nil : "development")
      puts "Saved unpublished analysis #{analysis.id}; artifact=#{generator.artifact_path}"
      artifact = JSON.parse(File.read(generator.artifact_path))
      warn "Trace export #{artifact['trace_export']}; saved draft remains available" unless artifact["trace_export"] == "flushed"
    rescue StandardError => error
      abort "Generation failed (#{error.class}); artifact=#{generator.artifact_path || 'not started'}"
    end
  end
end
