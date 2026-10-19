# Group model families, including their root model, without changing their class names.
Rails.autoloaders.main.collapse(Rails.root.join("app/models/user"))
Rails.autoloaders.main.collapse(Rails.root.join("app/models/session"))
