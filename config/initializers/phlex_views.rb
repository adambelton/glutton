# Full-page Phlex views use Views::<Domain>; reusable components keep their
# normal app/components namespaces. Rails still resolves email ERB templates here.
module Views
end

Rails.autoloaders.main.push_dir(Rails.root.join("app/views"), namespace: Views)
