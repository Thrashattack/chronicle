class NewsRevision < ApplicationRecord
  belongs_to :news_story

  validates :headline, :body, :source, presence: true
end
