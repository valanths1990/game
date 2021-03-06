# encoding: utf-8
class TopicsController < ApplicationController
  before_filter :login_required, :except => [:index, :show]
  before_filter :admin_required, :only => :destroy

  def index
    #@topics = Topic.all
  end

  def show
    @topic = Topic.find(params[:id])
    authorize! :read, @topic
    @posts = @topic.posts.order("created_at DESC").page(params[:page])
  end

  def new
	  @syselaad = Syselaad.find(params[:syselaad]) if params[:syselaad]
    @topic = Topic.new
    @post = Post.new
  end

  def create
    @topic = Topic.new(
        :name => params[:topic][:name],
        :last_poster_id => current_user.id,
        :last_post_at => Time.now,
        :syselaad_id => params[:topic][:syselaad_id],
        :user_id => current_user.id
    )
    if @topic.save
      if @topic.posts << Post.new(
          :content => params[:post][:content],
          #:topic_id => @topic.id, 
          :user_id => current_user.id
      )
        flash[:notice] = "Uspesne jste vytvoril vlakno."
        redirect_to syselaad_path(@topic.syselaad.kind)
      else
	      @topic.delete
	      redirect_to :back, :alert => "Milosti zabudli jste napsat obsah vlakna."
      end
    else
	    redirect_to :back, :alert => "Chybi jmeno vlakna."
    end
  end

  def edit
    @topic = Topic.find(params[:id])
  end

  def update
    @topic = Topic.find(params[:id])
    if @topic.update_attributes(params[:topic])
      redirect_to syselaad_path(@topic.syselaad.kind), :notice => "Vlakno uspesne upraveno."
    else
      render :action => 'edit'
    end
  end

  def destroy
    @topic = Topic.find(params[:id])
    @topic.destroy
    redirect_to syselaad_path(@topic.syselaad.kind), :notice => "Vlakno uspesne zmazano."
  end
end
