class CreateNewsStories < ActiveRecord::Migration[8.1]
  def change
    create_table :news_stories do |t|
      t.string :headline, null: false
      t.text :body, null: false
      t.string :source, null: false
      t.timestamps
    end

    create_table :news_revisions do |t|
      t.references :news_story, null: false
      t.string :headline, null: false
      t.text :body, null: false
      t.string :source, null: false
      t.timestamps
    end
  end
end
