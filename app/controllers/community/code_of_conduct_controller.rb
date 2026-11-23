module Community
  class CodeOfConductController < ApplicationController
    allow_unauthenticated_access only: :show

    def show
      render Views::Community::CodeOfConduct.new(code: CodeOfConduct.current)
    end
  end
end
