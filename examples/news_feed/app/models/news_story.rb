class NewsStory < DatomicRecord
  include Chronicle::Model

  datomic_attribute :headline, :string
  datomic_attribute :body, :string
  datomic_attribute :source, :string

  has_many :news_revisions, dependent: :destroy

  validates :headline, :body, :source, presence: true

  after_create :record_revision

  def update_with_revision!(attributes)
    transaction do
      update!(attributes)
      record_revision
    end
  end

  private

  def record_revision
    news_revisions.create!(headline:, body:, source:)
  end
end
