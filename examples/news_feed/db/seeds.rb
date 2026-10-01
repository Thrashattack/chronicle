story = NewsStory.find_or_initialize_by(headline: "Datomic gets a memory")
story.assign_attributes(
	body: "Chronicle keeps today's Active Record workflow connected to an immutable history of changes.",
	source: "The Chronicle Desk"
)
story.save! if story.new_record?
