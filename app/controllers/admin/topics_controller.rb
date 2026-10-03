module Admin
  class TopicsController < BaseController
    before_action :set_topic, only: %i[show edit update destroy]

    def index
      authorize Topic, :index?
      @topics = Topic.includes(:curriculum_module, :skill, :lessons, :challenges, :questions)
                     .order(:position).page(params[:page]).per(25)
    end

    def show
      authorize @topic, :show?
      @definition_of_done = @topic.definition_of_done
    end

    def new
      authorize Topic, :create?
      @topic = Topic.new
    end

    def create
      authorize Topic, :create?
      @topic = Topic.new(topic_params)
      if @topic.save
        audit!("admin.topic.create", auditable: @topic)
        redirect_to admin_topic_path(@topic), notice: "Mission created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @topic, :update?
    end

    def update
      authorize @topic, :update?
      if @topic.update(topic_params)
        audit!("admin.topic.update", auditable: @topic)
        redirect_to admin_topic_path(@topic), notice: "Mission updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @topic, :destroy?
      @topic.destroy!
      audit!("admin.topic.destroy", metadata: { "name" => @topic.name })
      redirect_to admin_topics_path, notice: "Mission deleted."
    end

    private

    def set_topic
      @topic = Topic.find(params[:id])
    end

    def topic_params
      params.expect(topic: %i[name slug hook summary curriculum_module_id skill_id
                              technology_version_id position estimated_minutes
                              difficulty xp_award published])
    end
  end
end
