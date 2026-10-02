class NewsStoriesController < ApplicationController
  before_action :set_news_story, only: %i[show edit update destroy]

  def index
    @news_stories = NewsStory.all
  end

  def show
    @revisions = @news_story.news_revisions.order(created_at: :desc)
  end

  def new
    @news_story = NewsStory.new
  end

  def create
    @news_story = NewsStory.new(news_story_params)

    if @news_story.save
      redirect_to @news_story, notice: 'Story published.'
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    if @news_story.update_with_revision!(news_story_params)
      redirect_to @news_story, notice: 'Story updated and revision recorded.'
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @news_story.destroy!
    redirect_to news_stories_path, notice: 'Story and its revision history were deleted.'
  end

  private

  def set_news_story
    @news_story = NewsStory.find(params[:id])
  end

  def news_story_params
    params.require(:news_story).permit(:headline, :body, :source)
  end
end
