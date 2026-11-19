module Admin
  class TableCell < Shared::Base
    def initialize(heading: false, **attributes)
      @element = heading ? :th : :td
      @attributes = heading ? { scope: "col", **attributes } : attributes
    end

    def view_template(&)
      tag(@element, **@attributes) do
        div(class: "admin-table-cell", &)
      end
    end
  end
end
