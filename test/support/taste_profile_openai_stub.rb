module TasteProfileOpenaiStub
  def taste_profile_openai_stub(handler)
    responses = Object.new
    responses.define_singleton_method(:create) do |input:, instructions:, text:, **|
      result = handler.call(input: JSON.parse(input), instructions:, schema: text.fetch(:format).fetch(:schema))
      usage = result.fetch("usage")
      content = Struct.new(:type, :text).new(:output_text, JSON.generate(result.except("provider", "model", "usage")))
      message = Struct.new(:type, :content).new(:message, [ content ])
      tokens = Struct.new(:input_tokens, :output_tokens).new(usage.fetch("input"), usage.fetch("output"))
      Struct.new(:status, :output, :model, :usage).new(:completed, [ message ], result.fetch("model"), tokens)
    end
    Struct.new(:responses).new(responses)
  end
end
