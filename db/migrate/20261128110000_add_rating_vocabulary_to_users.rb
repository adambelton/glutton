class AddRatingVocabularyToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :rating_vocabulary, :string
  end
end
