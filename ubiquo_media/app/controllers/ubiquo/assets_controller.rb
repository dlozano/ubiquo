class Ubiquo::AssetsController < UbiquoController
  ubiquo_config_call :assets_access_control, {:context => :ubiquo_media}
  before_filter :load_asset_visibilities
  before_filter :load_asset_types

  # GET /assets
  # GET /assets.xml
  def index
    filters = {
      "filter_created_start" => params[:filter_created_start],
      "filter_created_end" => params[:filter_created_end], :time_offset => 1.day,
      "per_page" => params[:per_page] || default_elements_per_page,
      "order_by" => params[:order_by] || default_order_field,
      "sort_order" => params[:sort_order] ||default_sort_order
    }.merge(uhook_index_filters)

    @assets_pages, @assets = uhook_index_search_subject.paginated_filtered_search(params.merge(filters))

    respond_to do |format|
      format.html{ } # index.html.erb
      format.xml{
        render :xml => @assets
      }
    end
  end

  # GET /assets/new
  # GET /assets/new.xml
  def new
    @asset = uhook_new_asset

    respond_to do |format|
      format.html{ } # new.html.erb
      format.xml{ render :xml => @asset }
    end
  end

  # GET /assets/1/edit
  def edit
    @asset = Asset.find(params[:id])
    return if uhook_edit_asset(@asset) == false
  end


  # POST /assets
  # POST /assets.xml
  def create
    @asset = uhook_create_asset asset_visibility
    respond_to do |format|
      if @asset.save && check_accepted_types(@asset)
        format.html do
          flash[:notice] = t('ubiquo.media.asset_created')
          redirect_to(ubiquo.assets_path)
        end
        format.xml { render :xml => @asset, :status => :created, :location => @asset }
        format.js { js_create_result(true) }
      else
        format.html do
          flash[:error] = t('ubiquo.media.asset_create_error')
          render :action => "new"
        end
        format.xml  { render :xml => @asset.errors, :status => :unprocessable_entity }
        format.js { js_create_result(false) }
      end
    end
  end

  # PUT /assets/1
  # PUT /assets/1.xml
  def update
    @asset = Asset.find(params[:id])
    respond_to do |format|
      if @asset.update_attributes(params[:asset])
        flash[:notice] = t('ubiquo.media.asset_updated')
        format.html { redirect_to(ubiquo.assets_path) }
        format.xml  { head :ok }
      else
        flash[:error] = t('ubiquo.media.asset_update_error')
        format.html { render :action => "edit" }
        format.xml  { render :xml => @asset.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /assets/1
  # DELETE /assets/1.xml
  def destroy
    @asset = Asset.find(params[:id])
    if uhook_destroy_asset(@asset)
      flash[:notice] = t('ubiquo.media.asset_removed')
    else
      flash[:error] = t('ubiquo.media.asset_remove_error')
    end

    respond_to do |format|
      format.html { redirect_to(ubiquo.assets_path) }
      format.xml  { head :ok }
    end
  end

  # GET /assets
  def search
    @field = params[:field]
    @counter = params[:counter]
    @search_text = params[:text]
    @page = params[:page] || 1
    per_page = params[:per_page] || default_media_selector_list_size

    filters = {
      "filter_type" => params[:asset_type_id],
      "filter_text" => @search_text,
      "filter_visibility" => params[:visibility],
      :per_page => per_page,
      :page => @page,
      "order_by" => order_by = params[:order_by] || default_order_field,
      "sort_order" => "desc"
    }.merge(uhook_index_filters)
    @assets_pages, @assets = uhook_index_search_subject.paginated_filtered_search(filters)
  end

  # GET /assets/1/advanced_edit
  def advanced_edit
    @asset = Asset.find(params[:id])
    if !@asset.is_resizeable?
      flash[:error] = t('ubiquo.media.asset_not_resizeable')
      redirect_to(ubiquo.assets_path)
    else
      render :layout => false
    end
  end

  # PUT /assets/1/advanced_update
  def advanced_update
    @asset = if params[:crop_resize_save_as_new].present?
      build_copy
    else
      Asset.find(params[:id])
    end
    @asset.keep_backup = params[:asset][:keep_backup] rescue default_keep_backup
    if params[:crop_resize] || @asset.save || @asset.is_resizeable
      params[:operation_type] == "original" ? crop_original : crop_copy
    else
      @asset.errors.add(:base, 'error in crop')
    end

    respond_to do |format|
      if @asset.errors.empty? && @asset.resource.errors.empty? && @asset_area.try(:errors).blank?
        flash[:notice] = if params[:crop_resize_save_as_new].present?
          t('ubiquo.media.image_saved_as_new')
        else
          t('ubiquo.media.image_updated')
        end

        if params[:apply] || params[:save_as_new]
          format.any{ redirect_to(ubiquo.advanced_edit_asset_path(@asset, :target => params[:target]) )}
        elsif params[:target]
          flash.delete :notice
          format.any{ render "advanced_update_target", :layout => false }
        else
          format.html { redirect_to(ubiquo.assets_path) }
          format.xml  { head :ok }
        end
      else
        destroy_duplicate
        if @rescued_exception
          flash[:error] = t('ubiquo.media.asset_original_crop_error') % @rescued_exception.record.errors.full_messages.join(" ")
        else
          flash[:error] = t('ubiquo.media.asset_update_error')
        end
        format.html { render :action => "advanced_edit", :layout => false }
        format.xml  { render :xml => @asset.errors, :status => :unprocessable_entity }
      end
    end
  end

  # POST /assets/1/restore
  def restore
    @asset = Asset.find(params[:id])
    return if uhook_edit_asset(@asset) == false
    if @asset.restore!
      flash[:notice] = t('ubiquo.media.image_updated')
    else
      flash[:error] = t('ubiquo.media.asset_update_error')
    end
    redirect_to ubiquo.advanced_edit_asset_path(@asset, :target => params[:target])
  end


  private

  def load_asset_visibilities
    @asset_visibilities = [
                           OpenStruct.new(:key => 'public', :name => t('ubiquo.media.public')),
                           OpenStruct.new(:key => 'private', :name => t('ubiquo.media.private'))
                          ]
  end

  def load_asset_types
    @asset_types = AssetType.all
  end

  def visibility
    @visibility ||= if force_visibility.present?
      force_visibility
    elsif %w{private 1 true}.include?(params[:asset].try(:[], :is_protected))
      "private"
    else
      "public"
    end
  end

  def counter
    @counter ||= params.delete(:counter)
  end

  def field
    @field ||= params.delete(:field)
  end

  def asset_visibility
    @asset_visibility ||= "asset_#{visibility}".classify.constantize
  end

  def accepted_types
    @accepted_types ||= params[:accepted_types]
  end

  def check_accepted_types(asset)
    if accepted_types.blank? || accepted_types.include?(asset.asset_type.key)
      true
    else
      asset.destroy
      asset.errors[:base] << t("ubiquo.media.invalid_asset_type")
      false
    end
  end

  def replace_asset_form(body, new_asset)
    old = @asset
    begin
      @asset = asset_visibility.new if new_asset
      body.replace_html(
        "add_#{counter}",
        :partial => "ubiquo/asset_relations/asset_form",
        :locals => {
          :counter => counter,
          :field => field,
          :visibility => visibility,
          :accepted_types => params[:accepted_types]
      })
    ensure
      @asset = old
    end
  end
  helper_method :replace_asset_form

  def js_create_result(success)
    asset = @asset
    flash.now[:error] = t('ubiquo.media.asset_create_error') unless success
    responds_to_parent do
      field, counter = field, counter
      render :update do |page|
        page << %[media_fields.add_element(
          '#{field}',
           null,
           #{@asset.id},
           #{@asset.name.to_s.to_json},
           #{counter},
           #{thumbnail_url(@asset).to_json rescue true},
           #{view_asset_link(@asset).to_json rescue true},
           null,
           {advanced_form:#{advanced_asset_form_for(@asset).to_json}});"
        ] if success
        replace_asset_form(page, success)
      end
    end
  end

   def build_copy
    # "find" method is used instead of @asset directly because with @asset doesn't work
    original_asset = Asset.find(params[:id])
    copy = original_asset.dup
    copy.name = params[:asset_name] if params[:asset_name].present?
    copy.save!
    copy
  end

  def crop_original
    if params[:crop_resize]["original"].detect { |_,v| v.to_i > 0 }
      begin
        crop_attributes = params[:crop_resize]["original"].merge({
          :asset => @asset,
          :style => "original"
        })
        AssetArea.original_crop!(crop_attributes)
      rescue ActiveRecord::RecordInvalid => e
        @rescued_exception = e
        @asset.errors.add(:base, "error in original crop")
      end
    end
  end

  def crop_copy
    params[:crop_resize].except(:original).detect { |style, attributes| !crop_style(style, attributes) }
    unless @asset.errors.any? || @asset_area.errors.any?
      @asset.resource.reprocess!
      @asset.touch
    end
  end

  def crop_style(style, attributes)
    if @asset_area = @asset.asset_areas.find_by_style(style)
      @asset_area.update_attributes(attributes)
    else
      @asset_area = @asset.asset_areas.create(
        attributes.slice(:width, :height, :top, :left).merge(:style => style)
      )
    end
    @asset_area.errors.blank?
  end

  def destroy_duplicate
    if params[:crop_resize_save_as_new].present?
      @asset.destroy
      @asset = Asset.find(params[:id])
    end
  end

  def default_order_field
    settings[:assets_default_order_field]
  end

  def default_sort_order
    settings[:assets_default_sort_order]
  end

  def default_elements_per_page
    settings[:assets_elements_per_page]
  end

  def default_keep_backup
    settings[:assets_default_keep_backup]
  end

  def force_visibility
    settings[:force_visibility]
  end

  def default_media_selector_list_size
    settings[:media_selector_list_size]
  end

  def settings
    Ubiquo::Settings[:ubiquo_media]
  end

end
