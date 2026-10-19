# Group subclasses beneath their superclass without changing their class names.
Rails.autoloaders.main.collapse(Rails.root.join("app/models/user"))
