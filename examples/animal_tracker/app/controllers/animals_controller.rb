class AnimalsController < ApplicationController
  before_action :set_animal, only: %i[show locations]

  def index
    @animals = Animal.order(:name)
    @location_counts = AnimalLocation.all.to_a.each_with_object(Hash.new(0)) do |location, counts|
      counts[location.animal_id] += 1
    end
  end

  def show
    @locations = AnimalLocation.where(animal_id: @animal.id).to_a.sort_by(&:recorded_at)
    @latest = @locations.last
  end

  def new
    @animal = Animal.new
  end

  def create
    @animal = Animal.new(animal_params)

    if @animal.save
      redirect_to @animal, notice: "Animal added to the map."
    else
      render :new, status: :unprocessable_content
    end
  end

  def locations
    location = AnimalLocation.new(location_params.merge(animal_id: @animal.id, recorded_at: Time.current))

    if location.save
      redirect_to @animal, notice: "Position recorded."
    else
      redirect_to @animal, alert: location.errors.full_messages.to_sentence
    end
  end

  private

  def set_animal
    @animal = Animal.find(params[:id])
  end

  def animal_params
    params.require(:animal).permit(:name, :species)
  end

  def location_params
    params.require(:animal_location).permit(:latitude, :longitude)
  end
end
