class RemoveNewsStoryForeignKey < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :news_revisions, :news_stories if foreign_key_exists?(:news_revisions, :news_stories)
  end
end