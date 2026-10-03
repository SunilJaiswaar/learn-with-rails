# Prediction blocks (spec 4): the learner must commit to an answer before the
# explanation is revealed, which is what makes the result stick.
class PredictionsController < ApplicationController
  def create
    topic = Topic.published.find_by_slug!(params[:topic_id])
    block = topic.lesson_blocks.prediction.find(params[:block_id])

    @outcome = Learning::TopicProgress.new(user: current_user, topic: topic)
                                      .record_prediction!(block: block,
                                                          choice: params[:choice])
    @block = block

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to topic_path(topic.slug) }
    end
  end
end
