module FilmAnalysisHelpers
  def analysis_content
    {
      "format_version" => FilmKnowledge::AnalysisContent::FORMAT_VERSION, "context" => "Theatrical cut; source-based draft.",
      "narrative" => [ { "id" => "N1", "text" => "The crew follows a signal, bringing danger aboard.", "source_ids" => [ "S1" ] } ],
      "moments" => [ { "id" => "M1", "text" => "A quiet search becomes a sudden confrontation.", "source_ids" => [ "S1" ] } ],
      "synthesis" => "Uncertainty and confined space support sustained dread.",
      "sources" => [ { "id" => "S1", "reference" => "Curator viewing notes, theatrical cut, 27 October 2026" } ],
      "gaps" => [ "No independent account of audience responses." ]
    }
  end

  def analysis_candidate(name: "Sustained dread", dimension: @dimension)
    { name:, dimension:, evidence_references: [ "M1" ] }
  end

  def publish_analysis(film_analysis)
    film_analysis.film.publish_analysis!
  end

  def prepare_analysis(film: @film, quality_candidates: [ analysis_candidate ])
    film.edit_analysis!(content: analysis_content, quality_candidates:)
  end
end
