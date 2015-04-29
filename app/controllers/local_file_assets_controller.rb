require 'image_size'
class LocalFileAssetsController < ApplicationController

  include Blacklight::Catalog
  include Hydra::Controller::ControllerBehavior
  include TuftsFileAssetsHelper
  include Tufts::ModelMethods
  include Tufts::MetadataMethods
  include VideoDeliveryHelper

  #before_filter :require_fedora
  #Remove any instance of:
  #before_filter :require_solr
  #This is no longer necessary, solr is automatically configured.
  #before_filter :require_solr, :only => [:index, :create, :show, :destroy]
  #prepend_before_filter :sanitize_update_params


  def index

    if params[:layout] == "false"
      # action = "index_embedded"
      layout = false
    end

    if params[:asset_id].nil?
      # @solr_result = ActiveFedora::SolrService.instance.conn.query('has_model_field:info\:fedora/afmodel\:FileAsset', @search_params)
      @solr_result = TuftsBase.find_by_solr(:all)
    else
      container_uri = "info:fedora/#{params[:asset_id]}"
      escaped_uri = container_uri.gsub(/(:)/, '\\:')
      extra_controller_params = {:q => "is_part_of_s:#{escaped_uri}"}
      @response, @document_list = get_search_results(extra_controller_params)

      # Including this line so permissions tests can be run against the container
      @container_response, @document = get_solr_response_for_doc_id(params[:asset_id])

      # Including these lines for backwards compatibility (until we can use Rails3 callbacks)
      @container = ActiveFedora::Base.load_instance(params[:asset_id])
      @solr_result = @container.file_objects(:response_format => :solr)
    end

    # Load permissions_solr_doc based on params[:asset_id]
    #load_permissions_from_solr(params[:asset_id])

    render :action => params[:action], :layout => layout
  end

  def new
=begin
From file_assets/_new.html.haml
=render :partial=>"fluid_infusion/uploader"
=render :partial=>"fluid_infusion/uploader_js"
=end
    render :partial => "new", :layout => false
  end

  # Creates and Saves a File Asset to contain the the Uploaded file
  # If container_id is provided:
  # * the File Asset will use RELS-EXT to assert that it's a part of the specified container
  # * the method will redirect to the container object's edit view after saving
  def create
    if params.has_key?(:Filedata)
      @file_asset = create_and_save_file_asset_from_params
      apply_depositor_metadata(@file_asset)

      flash[:retrieval] = "The file #{params[:Filename]} has been saved in <a href=\"#{asset_url(@file_asset.pid)}\">#{@file_asset.pid}</a>."

      if !params[:asset_id].nil?
        associate_file_asset_with_container
      end

      ## Apply any posted file metadata
      unless params[:asset].nil?
        logger.debug("applying submitted file metadata: #{@sanitized_params.inspect}")
        apply_file_metadata
      end
      # If redirect_params has not been set, use {:action=>:index}
      logger.debug "Created #{@file_asset.pid}."
    else
      flash[:retrieval] = "You must specify a file to upload."
    end

    if !params[:asset_id].nil?
      redirect_params = {:controller => "catalog", :id => params[:asset_id], :action => :edit}
    end

    redirect_params ||= {:action => :index}

    redirect_to redirect_params
  end

  # Common destroy method for all AssetsControllers
  def destroy
    # The correct implementation, with garbage collection:
    # if params.has_key?(:container_id)
    #   container = ActiveFedora::Base.load_instance(params[:container_id])
    #   container.file_objects_remove(params[:id])
    #   TuftsBase.garbage_collect(params[:id])
    # else

    # The dirty implementation (leaves relationship in container object, deletes regardless of whether the file object has other containers)
    ActiveFedora::Base.load_instance(params[:id]).delete
    render :text => "Deleted #{params[:id]} from #{params[:asset_id]}."
  end

  def showGeneric
    #  generic_content = get_values_from_datastream(@document_fedora, "GENERIC-CONTENT", [:item])
    #  result = ""
    #  generic_content.each_with_index do |page, index|
    #    result+="<tr class=\"manifestRow\">"
    #    file_name = get_values_from_datastream(@document_fedora, "GENERIC-CONTENT", [:item, :fileName])[index]
    #    link = '/file_assets/generic/' + pid + "/" + String(index)
    #    mime_type = get_values_from_datastream(@document_fedora, "GENERIC-CONTENT", [:item, :mimeType])[index]
    #    result+="<td class=\"nameCol\"><a class=\"manifestLink\" href=\"#{link}\">#{file_name}</a></td>"
    #    result+="<td class=\"mimeCol\">#{mime_type}</td>"
    #    result+="</tr>"
    #  end
    #  return raw(result)
    #end
    #match '/file_assets/generic/:id/:index', :to => 'local_file_assets#showGeneric', :constraints => {:id => /.*/}, :as =>'file_asset'

    @file_asset = TuftsGenericObject.find(params[:id])
    if (@file_asset.nil?)
      logger.warn("No such file asset: " + params[:id])
      flash[:retrieval]= "No such file asset."
      redirect_to(:action => 'index', :q => nil, :f => nil)
    else
      # get containing object for this TuftsBase
      pid = params[:id]
      @downloadable = false
      # A TuftsBase is downloadable iff the user has read or higher access to a parent
      @response, @permissions_solr_document = get_solr_response_for_doc_id(pid)
      if reader?
        @downloadable = true
      end

      if isUnderEmbargo
        redirect_to(:root, :q => nil, :f => nil) and return false
      end

      index = Integer(params[:index])
      file_name = get_values_from_datastream(@file_asset, "GENERIC-CONTENT", [:item, :link])
      send_file(convert_url_to_local_path(file_name[0]))
      #if @file_asset.datastreams.include?("Advanced.jpg")
      #  send_file(convert_url_to_local_path(@file_asset.datastreams["Advanced.jpg"].dsLocation))
      #end

    end
  end

  # retrieve field values from datastream.
  # If :values is provided, skips accessing the datastream and returns the contents of :values instead.
  def get_values_from_datastream(resource, datastream_name, field_key, opts={})
    if opts.has_key?(:values)
      values = opts[:values]
      if values.nil? then
        values = [opts.fetch(:default, "")]
      end
    else
      values = resource.get_values_from_datastream(datastream_name, field_key, opts.fetch(:default, ""))
      if values.empty? then
        values = [opts.fetch(:default, "")]
      end
    end
    return values
  end

  def showArchival
    @file_asset = TuftsBase.find(params[:id])
    if (@file_asset.nil?)
      logger.warn("No such file asset: " + params[:id])
      flash[:retrieval]= "No such file asset."
      redirect_to(:action => 'index', :q => nil, :f => nil)
    elsif (current_user.nil? || !current_user.has_role?(:archivist))
      logger.warn((current_user.nil? ? "Logged-out" : "Non-archivist") + " user attempted to download high-res image: " + params[:id])
      flash[:retrieval]= "You do not have permission to view this asset."
      redirect_to root_path
    else
      # get containing object for this TuftsBase
      #pid = @file_asset.container_id
      pid = params[:id]
      @downloadable = false
      # A TuftsBase is downloadable iff the user has read or higher access to a parent
      @response, @permissions_solr_document = get_solr_response_for_doc_id(pid)
      if reader?
        @downloadable = true
      end

      if isUnderEmbargo
        redirect_to(:root, :q => nil, :f => nil) and return false
      end
      mapped_model_names = ModelNameHelper.map_model_names(@file_asset.relationships(:has_model))


      if (mapped_model_names.include?("info:fedora/afmodel:TuftsImage"))
        if @file_asset.datastreams.include?("Archival.tif")
          send_file(convert_url_to_local_path(@file_asset.datastreams["Archival.tif"].dsLocation))
        end
      end

      if (mapped_model_names.include?("info:fedora/afmodel:TuftsImageText"))
        if @file_asset.datastreams.include?("Archival.tif")
          send_file(convert_url_to_local_path(@file_asset.datastreams["Archival.tif"].dsLocation))
        end
      end

      if (mapped_model_names.include?("info:fedora/afmodel:TuftsWP"))
        if @file_asset.datastreams.include?("Archival.tif")
          send_file(convert_url_to_local_path(@file_asset.datastreams["Archival.tif"].dsLocation))
        end
      end
    end
  end

  def showAdvanced
    @file_asset = TuftsBase.find(params[:id])
    if (@file_asset.nil?)
      logger.warn("No such file asset: " + params[:id])
      flash[:retrieval]= "No such file asset."
      redirect_to(:action => 'index', :q => nil, :f => nil)
    else
      # get containing object for this TuftsBase
      #pid = @file_asset.container_id
      pid = params[:id]
      @downloadable = false
      # A TuftsBase is downloadable iff the user has read or higher access to a parent
      @response, @permissions_solr_document = get_solr_response_for_doc_id(pid)
      if reader?
        @downloadable = true
      end

      if isUnderEmbargo
        redirect_to(:root, :q => nil, :f => nil) and return false
      end
      mapped_model_names = ModelNameHelper.map_model_names(@file_asset.relationships(:has_model))


      if (mapped_model_names.include?("info:fedora/afmodel:TuftsImage"))
        if @file_asset.datastreams.include?("Advanced.jpg")
          send_file(convert_url_to_local_path(@file_asset.datastreams["Advanced.jpg"].dsLocation))
        end
      end

      if (mapped_model_names.include?("info:fedora/afmodel:TuftsImageText"))
        if @file_asset.datastreams.include?("Advanced.jpg")
          send_file(convert_url_to_local_path(@file_asset.datastreams["Advanced.jpg"].dsLocation))
        end
      end

      if (mapped_model_names.include?("info:fedora/afmodel:TuftsWP"))
        if @file_asset.datastreams.include?("Advanced.jpg")
          send_file(convert_url_to_local_path(@file_asset.datastreams["Advanced.jpg"].dsLocation))
        end
      end
    end
  end

  def showMedium
    @file_asset = TuftsBase.find(params[:id])
    if (@file_asset.nil?)
      logger.warn("No such file asset: " + params[:id])
      flash[:retrieval]= "No such file asset."
      redirect_to(:action => 'index', :q => nil, :f => nil)
    else
      # get containing object for this TuftsBase
      #pid = @file_asset.container_id
      pid = params[:id]
      @downloadable = false
      # A TuftsBase is downloadable iff the user has read or higher access to a parent
      @response, @permissions_solr_document = get_solr_response_for_doc_id(pid)
      if reader?
        @downloadable = true
      end

      if isUnderEmbargo
        redirect_to(:root, :q => nil, :f => nil) and return false
      end
      mapped_model_names = ModelNameHelper.map_model_names(@file_asset.relationships(:has_model))


      if (mapped_model_names.include?("info:fedora/afmodel:TuftsImage"))
        if @file_asset.datastreams.include?("Basic.jpg")
          send_file(convert_url_to_local_path(@file_asset.datastreams["Basic.jpg"].dsLocation))
        end
      end

      if (mapped_model_names.include?("info:fedora/afmodel:TuftsImageText"))
        if @file_asset.datastreams.include?("Basic.jpg")
          send_file(convert_url_to_local_path(@file_asset.datastreams["Basic.jpg"].dsLocation))
        end
      end

      if (mapped_model_names.include?("info:fedora/afmodel:TuftsWP"))
        if @file_asset.datastreams.include?("Basic.jpg")
          send_file(convert_url_to_local_path(@file_asset.datastreams["Basic.jpg"].dsLocation))
        end
      end
    end
  end


  def showThumb
    @file_asset = TuftsBase.find(params[:id])
    if (@file_asset.nil?)
      logger.warn("No such file asset: " + params[:id])
      flash[:retrieval]= "No such file asset."
      redirect_to(:action => 'index', :q => nil, :f => nil)
    else
      # get containing object for this TuftsBase
      #pid = @file_asset.container_id
      pid = params[:id]
      @downloadable = false
      # A TuftsBase is downloadable iff the user has read or higher access to a parent
      @response, @permissions_solr_document = get_solr_response_for_doc_id(pid)
      if reader?
        @downloadable = true
      end

      if isUnderEmbargo
        redirect_to(:root, :q => nil, :f => nil) and return false
      end
      mapped_model_names = ModelNameHelper.map_model_names(@file_asset.relationships(:has_model))


      if (mapped_model_names.include?("info:fedora/afmodel:TuftsImage"))
        if @file_asset.datastreams.include?("Thumbnail.png")
          send_file(convert_url_to_local_path(@file_asset.datastreams["Thumbnail.png"].dsLocation), :type => 'image/png', :disposition => 'inline')
        end
      end

      if (mapped_model_names.include?("info:fedora/afmodel:TuftsVideo"))
        if @file_asset.datastreams.include?("Thumbnail.png")
          send_file(convert_url_to_local_path(@file_asset.datastreams["Thumbnail.png"].dsLocation), :type => 'image/png', :disposition => 'inline')
        end
      end
      if (mapped_model_names.include?("info:fedora/afmodel:TuftsImageText"))
        if @file_asset.datastreams.include?("Thumbnail.png")
          send_file(convert_url_to_local_path(@file_asset.datastreams["Thumbnail.png"].dsLocation), :type => 'image/png', :disposition => 'inline')
        end
      end

      if (mapped_model_names.include?("info:fedora/afmodel:TuftsWP"))
        if @file_asset.datastreams.include?("Thumbnail.png")
          send_file(convert_url_to_local_path(@file_asset.datastreams["Thumbnail.png"].dsLocation), :type => 'image/png', :disposition => 'inline')
        end
      end
    end
  end

  def showTranscript
    @file_asset = TuftsBase.find(params[:id])

    if (@file_asset.nil?)
      logger.warn("No such file asset: " + params[:id])
      flash[:retrieval]= "No such file asset."
      redirect_to(:action => 'index', :q => nil, :f => nil)
    else
      # get containing object for this TuftsBase
      #pid = @file_asset.container_id
      pid = params[:id]
      @downloadable = false
      # A TuftsBase is downloadable iff the user has read or higher access to a parent
      @response, @permissions_solr_document = get_solr_response_for_doc_id(pid)

      if reader?
        @downloadable = true
      end

      if isUnderEmbargo
        redirect_to(:root, :q => nil, :f => nil) and return false
      end
      mapped_model_names = ModelNameHelper.map_model_names(@file_asset.relationships(:has_model))

      if (mapped_model_names.include?("info:fedora/afmodel:TuftsAudioText"))
        if @file_asset.datastreams.include?("ARCHIVAL_XML")
          send_file(convert_url_to_local_path(@file_asset.datastreams["ARCHIVAL_XML"].dsLocation))
        end
      end

      if (mapped_model_names.include?("info:fedora/afmodel:TuftsVideo"))

        if @file_asset.datastreams.include?("ARCHIVAL_XML")
          send_file(convert_url_to_local_path(@file_asset.datastreams["ARCHIVAL_XML"].dsLocation))
        end
      end
    end
  end

  def showRCR
    @file_asset = TuftsBase.find(params[:id])

    if (@file_asset.nil?)
      logger.warn("No such file asset: " + params[:id])
      flash[:retrieval]= "No such file asset."
      redirect_to(:action => 'index', :q => nil, :f => nil)
    else
      # get containing object for this TuftsBase
      #pid = @file_asset.container_id
      pid = params[:id]
      @downloadable = false
      # A TuftsBase is downloadable iff the user has read or higher access to a parent
      @response, @permissions_solr_document = get_solr_response_for_doc_id(pid)

      if reader?
        @downloadable = true
      end

      if isUnderEmbargo
        redirect_to(:root, :q => nil, :f => nil) and return false
      end
      mapped_model_names = ModelNameHelper.map_model_names(@file_asset.relationships(:has_model))

      if (mapped_model_names.include?("info:fedora/afmodel:TuftsRCR"))
        if @file_asset.datastreams.include?("RCR-CONTENT")
          send_file(convert_url_to_local_path(@file_asset.datastreams["RCR-CONTENT"].dsLocation))
        end
      end
    end
  end

  def image_gallery
    @document_fedora = TuftsTEI.find(params[:id])
    metadata = Tufts::ModelMethods.get_metadata(@document_fedora)
    title = metadata[:titles].nil? ? "" : metadata[:titles].first
    xml = @document_fedora.datastreams["Archival.xml"].ng_xml
    node_sets = xml.xpath('//figure')
    total_length = node_sets.length

    figures = Array.new

    start = Integer(params[:start])
    end_figure = Integer(params[:number])

    unless node_sets.nil?
      node_sets = node_sets.slice(start, end_figure)
      node_sets.each do |node|
        image_pid = Tufts::PidMethods.urn_to_pid(node[:n])
        image_title = ""
        full_title = ""
        @image = TuftsImage.find(image_pid)
        begin
          image_metadata = Tufts::ModelMethods.get_metadata(@image)
          image_title = image_metadata[:titles].nil? ? "" : image_metadata[:titles].first
          full_title = image_title
          if image_title.length > 20
            image_title = image_title.slice(0, 17) + '...'
          end

        rescue NoMethodError
          image_title = ""
        end

        figures << {:pid => image_pid, :caption => image_title, :full_title => full_title}
      end
    end

    render :json => {:figures => figures, :count => total_length, :title => "Illustrations from the " + title}
  end

  def image_overlay

    @document_fedora = TuftsBase.find(params[:id])
    metadata = Tufts::ModelMethods.get_metadata(@document_fedora)
    title = metadata[:titles].nil? ? "" : metadata[:titles].first
    temporal = if metadata[:temporals].nil? then
                 ""
               else
                 metadata[:temporals].first.nil? ? "" : metadata[:temporals].first
               end
    description = if metadata[:descriptions].nil? then
                    ""
                  else
                    metadata[:descriptions].first.nil? ? "" : metadata[:descriptions].first
                  end
    pid = params[:id]
    item_link = '/catalog/' + pid
    image_url = '/file_assets/medium/' + pid


    logger.error(convert_url_to_local_path(@document_fedora.datastreams["Basic.jpg"].dsLocation))
    imagesize = ImageSize.new File.open(convert_url_to_local_path(@document_fedora.datastreams["Basic.jpg"].dsLocation), "rb").read


    render :json => {:back_url => "#", :item_title => title, :item_date => temporal, :image_url => image_url, :item_link => item_link, :item_description => description, :width => imagesize.height, :height => imagesize.width}
  end

  def dimensions
    @file_asset = TuftsBase.find(params[:id])


    if (@file_asset.nil?)
      logger.warn("No such file asset: " + params[:id])
      flash[:retrieval]= "No such file asset."
      redirect_to(:action => 'index', :q => nil, :f => nil)
    else
      # get containing object for this TuftsBase
      #pid = @file_asset.container_id
      pid = params[:id]
      @downloadable = false
      # A TuftsBase is downloadable iff the user has read or higher access to a parent
      @response, @permissions_solr_document = get_solr_response_for_doc_id(pid)
      if reader?
        @downloadable = true
      end

      if isUnderEmbargo
        redirect_to(:root, :q => nil, :f => nil) and return false
      end
      mapped_model_names = ModelNameHelper.map_model_names(@file_asset.relationships(:has_model))


      if (mapped_model_names.include?("info:fedora/afmodel:TuftsImage"))
        if @file_asset.datastreams.include?("Advanced.jpg")
          imagesize = ImageSize.new File.open(convert_url_to_local_path(@file_asset.datastreams["Advanced.jpg"].dsLocation), "rb").read


          render :json => {:height => imagesize.height, :width => imagesize.width}
        end
      end

      if (mapped_model_names.include?("info:fedora/afmodel:TuftsImageText"))
        if @file_asset.datastreams.include?("Advanced.jpg")
          imagesize = ImageSize.new File.open(convert_url_to_local_path(@file_asset.datastreams["Advanced.jpg"].dsLocation), "rb").read
          render :json => {:height => imagesize.height, :width => imagesize.width}
        end
      end

      if (mapped_model_names.include?("info:fedora/afmodel:TuftsWP"))
        if @file_asset.datastreams.include?("Basic.jpg")
          imagesize = ImageSize.new File.open(convert_url_to_local_path(@file_asset.datastreams["Advanced.jpg"].dsLocation), "rb").read
          render :json => {:height => imagesize.height, :width => imagesize.width}.to_s
        end
      end
    end


  end

  def show


    @file_asset = TuftsBase.find(params[:id])
    if (@file_asset.nil?)
      logger.warn("No such file asset: " + params[:id])
      flash[:retrieval]= "No such file asset."
      redirect_to(:action => 'index', :q => nil, :f => nil)
    else
      # get containing object for this TuftsBase
      #pid = @file_asset.container_id
      pid = params[:id]
      @downloadable = false
      # A TuftsBase is downloadable iff the user has read or higher access to a parent
      @response, @permissions_solr_document = get_solr_response_for_doc_id(pid)
      if reader?
        @downloadable = true
      end

      if isUnderEmbargo
        redirect_to(:root, :q => nil, :f => nil) and return false
      end
      mapped_model_names = ModelNameHelper.map_model_names(@file_asset.relationships(:has_model))

      if (mapped_model_names.include?("info:fedora/afmodel:TuftsFacultyPublication"))
        if @file_asset.datastreams.include?("Archival.pdf")
          send_file(convert_url_to_local_path(@file_asset.datastreams["Archival.pdf"].dsLocation))
        end
      end

      if (mapped_model_names.include?("info:fedora/afmodel:TuftsImage"))
        if @file_asset.datastreams.include?("Basic.jpg")
          send_file(convert_url_to_local_path(@file_asset.datastreams["Basic.jpg"].dsLocation))
        end
      end

      if (mapped_model_names.include?("info:fedora/afmodel:TuftsImageText"))
        if @file_asset.datastreams.include?("Basic.jpg")
          send_file(convert_url_to_local_path(@file_asset.datastreams["Basic.jpg"].dsLocation))
        end
      end

      if (mapped_model_names.include?("info:fedora/afmodel:TuftsAudio"))
        if @file_asset.datastreams.include?("ACCESS_MP3")
          send_file(convert_url_to_local_path(@file_asset.datastreams["ACCESS_MP3"].dsLocation), :type => 'audio/mpeg')
        end
      end

      if (mapped_model_names.include?("info:fedora/afmodel:TuftsAudioText"))
        if @file_asset.datastreams.include?("ACCESS_MP3")
          send_file(convert_url_to_local_path(@file_asset.datastreams["ACCESS_MP3"].dsLocation), :type => 'audio/mpeg')
        end
      end

      if (mapped_model_names.include?("info:fedora/afmodel:TuftsVideo"))
        if @file_asset.datastreams.include?("Access.mp4")
          path = VideoDeliveryHelper.render_video_path(@file_asset.datastreams["Access.mp4"].dsLocation, 'mp4', params[:id])
          if path[/^http:\/\/bucket01/]
            send_file(convert_url_to_local_path(path), :type => 'video/mp4')
          else
            redirect_to path
          end
        end
      end

      if (mapped_model_names.include?("info:fedora/afmodel:TuftsWP"))
        if @file_asset.datastreams.include?("Basic.jpg")
          send_file(convert_url_to_local_path(@file_asset.datastreams["Basic.jpg"].dsLocation))
        end
      end

      if (mapped_model_names.include?("info:fedora/afmodel:TuftsPdf"))
        if @file_asset.datastreams.include?("Archival.pdf")
          send_file(convert_url_to_local_path(@file_asset.datastreams["Archival.pdf"].dsLocation))
        end
      end
      # else
      #   flash[:retrieval]= "You do not have sufficient access privileges to download this document, which has been marked private."
      #   redirect_to(:action => 'index', :q => nil , :f => nil)
      # end
    end
  end

  def showWebm
    @file_asset = TuftsBase.find(params[:id])
    if (@file_asset.nil?)
      logger.warn("No such file asset: " + params[:id])
      flash[:retrieval]= "No such file asset."
      redirect_to(:action => 'index', :q => nil, :f => nil)
    else
      # get containing object for this TuftsBase
      #pid = @file_asset.container_id
      pid = params[:id]
      @downloadable = false
      # A TuftsBase is downloadable iff the user has read or higher access to a parent
      @response, @permissions_solr_document = get_solr_response_for_doc_id(pid)
      if reader?
        @downloadable = true
      end

      if isUnderEmbargo
        redirect_to(:root, :q => nil, :f => nil) and return false
      end
      mapped_model_names = ModelNameHelper.map_model_names(@file_asset.relationships(:has_model))

      if (mapped_model_names.include?("info:fedora/afmodel:TuftsVideo"))
        if @file_asset.datastreams.include?("Access.webm")
          path = VideoDeliveryHelper.render_video_path(@file_asset.datastreams["Access.webm"].dsLocation, 'webm', params[:id])
          if path[/^http:\/\/bucket01/]
            send_file(convert_url_to_local_path(path), :type => 'video/webm')
          else
            redirect_to path
          end

        end
      end

    end
  end

  def isUnderEmbargo
    if @file_asset.datastreams["DCA-ADMIN"].under_embargo?
      logger.warn("File asset embargoed: " + params[:id])
      flash[:retrieval]= "File asset embargoed."
      return true
    end

  end

end
