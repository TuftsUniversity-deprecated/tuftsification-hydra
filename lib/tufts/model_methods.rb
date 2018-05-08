# COPIED From https://github.com/mkorcy/tdl_hydra_head/blob/master/lib/tufts/model_methods.rb
require 'chronic'
require 'titleize'
require 'tufts/metadata_methods'
# MISCNOTES:
# There will be no facet for RCR. There will be no way to reach RCR via browse.
# 3. There will be a facet for "collection guides", namely EAD, namely the landing page view we discussed on Friday.

module Tufts
  module ModelMethods
    include TuftsFileAssetsHelper

    def self.get_metadata(fedora_obj)
      datastream = fedora_obj.datastreams["DCA-META"]
      detailed_datastream = fedora_obj.datastreams["DC-DETAIL-META"]

      # create the union (ie, without duplicates) of subject, geogname, persname, and corpname
      subjects = []
      Tufts::MetadataMethods.union(subjects, datastream.subject)
      Tufts::MetadataMethods.union(subjects, datastream.geogname)
      Tufts::MetadataMethods.union(subjects, datastream.persname)
      Tufts::MetadataMethods.union(subjects, datastream.corpname)

      return {
          :titles => datastream.title,
          :creators => datastream.creator,
          :dates => datastream.date,
          :descriptions => datastream.description,
          :sources => datastream.source,
          :citable_urls => datastream.identifier,
          :citations => datastream.bibliographic_citation,
          :publishers => datastream.publisher,
          :genres => datastream.genre,
          :types => datastream.type,
          :formats => datastream.format,
          :rights => datastream.rights,
          :access_rights => detailed_datastream.access_rights,
          :subjects => subjects,
          :temporals => datastream.temporal,
	 			  :is_parts_of => datastream.isPartOf
      }
    end

    def index_permissions(solr_doc)
      indexer = Solrizer::Descriptor.new(:string, :stored, :indexed, :multivalued)

      Solrizer.insert_field(solr_doc, 'read_access_group', 'public', indexer)


      #Solrizer.insert_field(solr_doc, 'read_access_person', 'public', :unstemmed_searchable)
    end

    def index_sort_fields(solr_doc)
      #CREATOR SORT
      Solrizer.insert_field(solr_doc, 'author', creator.first, :sortable) unless creator.empty?

      #TITLE SORT
      Solrizer.insert_field(solr_doc, 'title', title, :sortable) if title
    end

    def get_ead_title(document, includeHtml=true)

      begin
        collections = document.relationships(:is_member_of_collection)
        ead = document.relationships(:has_description)
      rescue
        Rails.logger.debug "Bad RDF " + document.pid.to_s
      end

      pid = document.pid.to_s
      ead_title = nil

      if ead.first.nil?
        # there is no hasDescription
        ead_title = get_collection_from_pid(ead_title, pid)

      else
        ead = ead.first.gsub('info:fedora/', '')
        ead_obj = nil
        begin
          ead_obj=TuftsEAD.find(ead)
        rescue ActiveFedora::ObjectNotFoundError => e
          logger.warn e.message
        end
        if ead_obj.nil?
          Rails.logger.debug "EAD Nil " + ead
        else
          ead_title = ead_obj.datastreams["DCA-META"].get_values(:title).first
          ead_title = Tufts::ModelUtilityMethods.clean_ead_title(ead_title)

          #4 additional collections, unfortunately defined by regular expression parsing. If one of these has hasDescription PID takes precedence
          #"Undergraduate scholarship": PID in tufts:UA005.*
          #"Graduate scholarship": PID in tufts:UA015.012.*
          #"Faculty scholarship": PID in tufts:PB.001.001* or tufts:ddennett*
          #"Boston Streets": PID in tufts:UA069.005.DO.* should be merged with the facet hasDescription UA069.001.DO.MS102

        end
      end

      if ead_title.blank?
        return ""
      else
        ead_title = ead_title.class == Array ? ead_title.first : ead_title
        ead = ead.class == Array ? ead.first : ead
        unless ead.nil?
          if (includeHtml)
            result=""
            result << "<dd>This object is in collection:</dd>"
            result << "<dt>" + link_to(ead_title, "/catalog/" + ead) + "</dt>"
          else
            result = ead_title
          end
        end

        raw result
      end
    end

    private

    def index_fulltext(fedora_object, solr_doc)
      full_text = ""

      # p.datastreams['Archival.xml'].content
      # doc = Nokogiri::XML(p.datastreams['Archival.xml'].content)
      # doc.xpath('//text()').text.gsub(/[^0-9A-Za-z]/, ' ')
      begin
        models = self.relationships(:has_model)
      rescue
        Rails.logger.debug "BAD RDF " + fedora_object.pid.to_s
      end

      unless models.nil?
        models.each { |model|
          case model
            when "info:fedora/afmodel:TuftsPdf", "info:fedora/cm:Text.FacPub", "info:fedora/afmodel:TuftsFacultyPublication", "info:fedora/cm:Text.PDF"
              #http://dev-processing01.lib.tufts.edu:8080/tika/TikaPDFExtractionServlet?doc=http://repository01.lib.tufts.edu:8080/fedora/objects/tufts:PB.002.001.00001/datastreams/Archival.pdf/content&amp;chunkList=true'
              processing_url = Settings.processing_url
              repository_url = Settings.repository_url
              unless processing_url == "SKIP"
                pid = fedora_object.pid.to_s
                url = processing_url + '/tika/TikaPDFExtractionServlet?doc='+ repository_url +'/fedora/objects/' + pid + '/datastreams/Archival.pdf/content&amp;chunkList=true'
                puts "#{url}"
                begin
                  nokogiri_doc = Nokogiri::XML(open(url).read)
                  full_text = nokogiri_doc.xpath('//text()').text.gsub(/[^0-9A-Za-z]/, ' ')
                rescue => e
                  case e
                    when OpenURI::HTTPError
                      puts "HTTPError while indexing full text #{pid}"
                    when SocketError
                      puts "SocketError while indexing full text #{pid}"
                    else
                      puts "Error while indexing full text #{pid}"
                  end
                rescue SystemCallError => e
                  if e === Errno::ECONNRESET
                    puts "Connection Reset while indexing full text #{pid}"
                  else
                    puts "SystemCallError while indexing full text #{pid}"
                  end
                end
              end
            when "info:fedora/cm:Text.TEI", "info:fedora/afmodel.TuftsTEI", "info:fedora/cm:Audio.OralHistory", "info:fedora/afmodel:TuftsAudioText", "info:fedora/cm:Text.EAD", "info:fedora/afmodel:TuftsEAD", "info:fedora/afmodel:TuftsVideo"
              #nokogiri_doc = Nokogiri::XML(self.datastreams['Archival.xml'].content)
              datastream = fedora_object.datastreams["Archival.xml"]

              # some objects have inconsistent name for the datastream
              if datastream.nil?
                datastream = fedora_object.datastreams["ARCHIVAL_XML"]
              end

              unless datastream.nil? || datastream.dsLocation.nil?
                nokogiri_doc = Nokogiri::XML(File.open(convert_url_to_local_path(datastream.dsLocation)).read)
                full_text = nokogiri_doc.xpath('//text()').text.gsub(/[^0-9A-Za-z]/, ' ')
              end
            else
              model_s="Unclassified"
          end
        }
      end

      ::Solrizer::Extractor.insert_solr_field_value(solr_doc, "all_text_timv", full_text)
    end


    def index_unstemmed_values(solr_doc)
      titleize_and_index_array(solr_doc, 'corpname', self.send(:corpname), :unstemmed_searchable)
      titleize_and_index_array(solr_doc, 'geogname', self.send(:geogname), :unstemmed_searchable)
      titleize_and_index_array(solr_doc, 'subject_topic', self.send(:subject), :unstemmed_searchable)
      titleize_and_index_array(solr_doc, 'persname', self.send(:persname), :unstemmed_searchable)
      titleize_and_index_array(solr_doc, 'author', self.send(:creator), :unstemmed_searchable)
      titleize_and_index_single(solr_doc, 'title', self.send(:title), :unstemmed_searchable)

    end

    def index_names_info(solr_doc)
      [:creator, :persname, :corpname].each do |name_field|
        names = self.send(name_field)
        titleize_and_index_array(solr_doc, 'names', names, :facetable) #names_sim
      end
    end


    def index_corpora_collection(solr_doc)
      [:subject, :corpname, :persname, :geogname].each do |subject_field|
        subjects = self.send(subject_field)
        subjects.each do |subject|
          if subject == "Bengali Intellectuals Oral History Project" || subject == "Islam on the Indian Ocean Rim" || subject == "Bay of Bengal" || subject == "Conflict & Natural Resources"
            titleize_and_index_single(solr_doc, 'corpora_collection', subject, :facetable)
            titleize_and_index_single(solr_doc, 'corpora_collection', subject, :stored_searchable)
          end
        end
      end

      #hack for this one object that doesn't have the right metadata maybe some day it will this is as of 1/21/2014
      if self.pid == "tufts:MS165.002.001.00001"
        titleize_and_index_single(solr_doc, 'corpora_collection', "Islam on the Indian Ocean Rim", :facetable)
        titleize_and_index_single(solr_doc, 'corpora_collection', "Islam on the Indian Ocean Rim", :stored_searchable)
      end
      is_part_of_many = self.isPartOf
      is_part_of_many.each do |part|
        titleize_and_index_single(solr_doc, 'corpora_collection', part, :facetable)
        titleize_and_index_single(solr_doc, 'corpora_collection', part, :stored_searchable)
      end
      sources = self.source
      sources.each do |source|
        titleize_and_index_single(solr_doc, 'corpora_collection', 'This I Believe', :facetable) if source == 'MS025'
        titleize_and_index_single(solr_doc, 'corpora_collection', 'This I Believe', :stored_searchable) if source == 'MS025'
        titleize_and_index_single(solr_doc, 'corpora_collection', 'Lost Theatres of Somerville', :facetable) if source == 'MS124'
        titleize_and_index_single(solr_doc, 'corpora_collection', 'Lost Theatres of Somerville', :stored_searchable) if source == 'MS124'
        titleize_and_index_single(solr_doc, 'corpora_collection', 'West Medford African-American Remembrance Project', :facetable) if source == 'MS123'
        titleize_and_index_single(solr_doc, 'corpora_collection', 'West Medford African-American Remembrance Project', :stored_searchable) if source == 'MS123'

      end
    end

    def index_subject_info(solr_doc)
      [:subject, :corpname, :persname, :geogname].each do |subject_field|
        subjects = self.send(subject_field)
        titleize_and_index_array(solr_doc, 'subject', subjects, :facetable) #subject_sim
      end
    end


    def titleize_and_index_array(solr_doc, field_prefix, values, index_type)
      values.each do |name|
        titleize_and_index_single(solr_doc, field_prefix, name, index_type)
      end
    end

    def titleize_and_index_single(solr_doc, field_prefix, name, index_type)
      if name.present? && !name.downcase.include?('unknown')
        clean_name = Titleize.titleize(name)
        Solrizer.insert_field(solr_doc, field_prefix, clean_name, index_type)
      end
    end

    #
    # Adds metadata about the depositor to the asset
    # Most important behavior: if the asset has a rightsMetadata datastream, this method will add +depositor_id+ to its individual edit permissions.
    #
    # Exposed visibly to users as Collection name, under the heading "Collection")
    #
    # Note: this could also be exposed via the Dublin core field "source", but the RDF is superior because it
    # contains all the possible collections, and thus would reveal, say, that Dan Dennett papers are both faculty
    # publications and part of the Dan Dennett manuscript collection.

    # Possible counter argument: because displayed facets tend to be everything before the long tail, arguably
    # collections shouldn't be displaying unless sufficient other resources in the same collections are part of the
    # result set, in which case the fine tuning enabled by using the RDF instead of the Dublin core would become
    # less relevant.


    def index_collection_info(solr_doc)

      begin
        collections = self.relationships(:is_member_of_collection)
        ead = self.relationships(:has_description)
      rescue
        Rails.logger.error "BAD RDF " + self.pid.to_s
      end

      pid = self.pid.to_s
      ead_title = nil

      if ead.first.nil?
        # there is no hasDescription
        ead_title = get_collection_from_pid(ead_title, pid)
        ead_title = get_collection_from_subject_is_part_of(ead_title)
        if ead_title.nil?
          COLLECTION_ERROR_LOG.error "Could not determine Collection for : #{self.pid}"
        else
          clean_ead_title = Titleize.titleize(ead_title);
          ::Solrizer::Extractor.insert_solr_field_value(solr_doc, "collection_sim", clean_ead_title)
        end
      else
        ead = ead.first.gsub('info:fedora/', '')
        begin
          ead_obj=TuftsEAD.find(ead)
        rescue ActiveFedora::ObjectNotFoundError => e
          logger.warn e.message
        end

        if ead_obj.nil?
          Rails.logger.debug "EAD Nil " + ead
        else
          ead_title = ead_obj.datastreams["DCA-META"].get_values(:title).first
          ead_title = Tufts::ModelUtilityMethods.clean_ead_title(ead_title)

          #4 additional collections, unfortunately defined by regular expression parsing. If one of these has hasDescription PID takes precedence
          #"Undergraduate scholarship": PID in tufts:UA005.*
          #"Graduate scholarship": PID in tufts:UA015.012.*
          #"Faculty scholarship": PID in tufts:PB.001.001* or tufts:ddennett*
          #"Boston Streets": PID in tufts:UA069.005.DO.* should be merged with the facet hasDescription UA069.001.DO.MS102

          ead_title = get_collection_from_pid(ead_title, pid)
          ead_title = get_collection_from_subject_is_part_of(ead_title)

        end

        unless ead_title.nil?
          clean_ead_title = Titleize.titleize(ead_title)
          ::Solrizer::Extractor.insert_solr_field_value(solr_doc, "collection_sim", clean_ead_title)
          ::Solrizer::Extractor.insert_solr_field_value(solr_doc, "collection_title_tesim", clean_ead_title)
        end
        ::Solrizer::Extractor.insert_solr_field_value(solr_doc, "collection_id_sim", ead)

        ::Solrizer::Extractor.insert_solr_field_value(solr_doc, "collection_id_tim", ead)
      end

      # unless collections.nil?
      #   collections.each {|collection|
      #   ::Solrizer::Extractor.insert_solr_field_value(solr_doc, "collection_facet", "#{collection}") }
      # end
    end

    def get_collection_from_subject_is_part_of(ead_title)
      undergrad_scholarship = "Senior honors thesis.".freeze
      graduate_scholarship = "Tufts University electronic theses and dissertations.".freeze

      subjects = self.datastreams["DCA-META"].get_values(:subject)
      is_parts = self.datastreams["DCA-META"].get_values(:isPartOf)

      if ((subjects.select{|part| part.downcase.match(/senior honor/)}.any?) || (is_parts.select{|part| part.downcase.match(/senior honor/)}.any?))
        ead_title = "Undergraduate scholarship"
      end

      if (is_parts.include? graduate_scholarship)
        ead_title = "Graduate scholarship"
      end

      ead_title
    end

    def get_collection_from_pid(ead_title, pid)
      if pid.starts_with? "tufts:UA005"
        ead_title = "Undergraduate scholarship"
      elsif pid.starts_with? "tufts:UA015.012"
        ead_title = "Graduate scholarship"
      elsif (pid.starts_with? "tufts:PB.") || (pid.starts_with? "tufts:ddennett")
        ead_title = "Faculty scholarship"
      elsif pid.starts_with? "tufts:UA069.005.DO"
        ead_title = "Boston Streets"
      end

      ead_title
    end

    def index_pub_date(solr_doc)
      dates = self.date

      if dates.empty?
        dates = self.temporal
      end

      unless dates.empty?
        date = dates[0]

        #remove trailing period
        date = date.chomp('.') if (date)

        valid_date = Time.new

        date = date.to_s

        if (!date.nil? && !date[/^c/].nil?)
          date = date.split[1..10].join(' ')
        end

				if  /^Circa \d{4}–\d{4}$/ =~ date
          earliest, latest = date.split('--').flat_map(&:to_i)
          date = earliest
        end

				if  /^\d{4}--\d{4}$/ =~ date
          earliest, latest = date.split('--').flat_map(&:to_i)
          date = earliest
        end

				if  /^\d{4}-\d{4}$/ =~ date
          earliest, latest = date.split('-').flat_map(&:to_i)
          date = earliest
        end
        #end handling circa dates

        #handle 01/01/2004 style dates
        if (!date.nil? && !date[/\//].nil?)
          date = date[date.rindex('/')+1..date.length()]
          #check for 2 digit year
          if (date.length() == 2)
            date = "19" + date
          end
        end
        #end handle 01/01/2004 style dates

        #handle n.d.
        if (!date.nil? && date[/n\.d/])
          date = "0"
        end
        #end n.d.

        #handle YYYY-MM-DD and MM-DD-YYYY
        if (!date.nil? && !date[/-/].nil?)
          if (date.index('-') == 4)
            date = date[0..date.index('-')-1]
          else
            date = date[date.rindex('-')+1..date.length()]
          end
        end
        #end YYYY-MM-DD

        #handle ua084 collection which has dates set as 0000-00-00
        pid = self.pid.to_s.downcase
        if pid[/tufts\:ua084/]
          date="1980"
        end
        #end ua084

        #Chronic is not gonna like the 4 digit date here it may interpret as military time, and
        #this may be imperfect but lets try this.

        unless (date.nil? || date == "0")
          if date.length() == 4
            date += "-01-01"
          elsif date.length() == 9
            date = date[0..3] += "-01-01"
          elsif date.length() == 7
            date = date[0..3] += "-01-01"
          end

          unparsed_date =Chronic.parse(date)
          unless unparsed_date.nil?
            valid_date = Time.at(unparsed_date)
          end

        end
        if date == "0"
          valid_date_string = "0"
        else
          valid_date_string = valid_date.strftime("%Y")
        end

        Solrizer.insert_field(solr_doc, 'pub_date', valid_date_string.to_i, :stored_sortable)
      end

    end

    #if possible, exposed as ranges, cf. the Virgo catalog facet "publication era". Under the heading
    #"Date". Also, if possible, use Temporal if "Date.Created" is unavailable.)

    #Only display these as years (ignore the MM-DD) and ideally group them into ranges. E.g.,
    ##if we had 4 items that had the years 2001, 2004, 2006, 2010, the facet would look like 2001-2010.
    #Perhaps these could be 10-year ranges, or perhaps, if it's not too difficult, the ranges could generate
    #automatically based on the available data.

    def index_date_info(solr_doc)
      dates = self.date

      if dates.empty?
        dates = self.temporal
      end

      unless dates.empty?
        dates.each do |date|

          if date.length() == 4
            date += "-01-01"
          end

          valid_date = Chronic.parse(date)
          unless valid_date.nil?
            last_digit= valid_date.year.to_s[3, 1]
            decade_lower = valid_date.year.to_i - last_digit.to_i
            decade_upper = valid_date.year.to_i + (10-last_digit.to_i)
            if decade_upper >= 2020
              decade_upper ="Present"
            end
            Solrizer.insert_field(solr_doc, 'year', "#{decade_lower} to #{decade_upper}", :facetable)
          end
        end
      end

    end

    # The facets in this category will have labels and several types of digital objects might fit under one label.
    #For example, if you look at the text bullet here, you will see that we have the single facet "format" which
    #includes PDF, faculty publication, and TEI).

    #The labels are:


    #Text Includes PDF, faculty publication, TEI, captioned audio.

    #Images Includes 4 DS image, 3 DS image
    #Preferably, not PDF page images, not election record images.
    #Note that this will include the individual images used in image books and other TEI, but not the books themselves.
    ##Depending on how we deal with the PDFs, this might include individual page images for PDF. Problem?

    #Datasets include wildlife pathology, election records, election images (if possible), Boston streets splash pages.
    #Periodicals any PID that begins with UP.
    #Collection guides Text.EAD
    #Audio Includes audio, captioned audio, oral history.

    def index_format_info(solr_doc)

      begin
        models = self.relationships(:has_model)
      rescue
        Rails.logger.debug "BAD RDF " + self.pid.to_s
      end

      if models
        models.each do |model|
          insert_object_type(solr_doc, model)
        end
      end
    end

    def insert_object_type(solr_doc, model)
      model_s = case model
                  when "info:fedora/afmodel:TuftsVotingRecord", "info:fedora/cm:VotingRecord"
                    "Datasets"
                  when "info:fedora/cm:Text.EAD", "info:fedora/afmodel:TuftsEAD"
                    "Collection Guides"
                  when "info:fedora/cm:Audio", "info:fedora/afmodel:TuftsAudio", "info:fedora/cm:Audio.OralHistory", "info:fedora/afmodel:TuftsAudioText"
                    "Audio"
                  when "info:fedora/cm:Image.4DS", "info:fedora/cm:Image.3DS", "info:fedora/afmodel:TuftsImage"
                    pid.starts_with?("tufts:MS115") ? "Datasets" : "Images"
                  when "info:fedora/cm:Text.PDF", "info:fedora/afmodel:TuftsPdf", "info:fedora/afmodel:TuftsTEI", "info:fedora/cm:Text.TEI", "info:fedora/cm:Text.FacPub", "info:fedora/afmodel:TuftsFacultyPublication"
                    pid.starts_with?("tufts:UP") ? "Periodicals" : "Text"
                  when "info:fedora/cm:Object.Generic", "info:fedora/afmodel:TuftsGenericObject"
                    "Generic Objects"
                  when "info:fedora/afmodel:TuftsVideo"
                    "Videos"
                  when "info:fedora/cm:Text.RCR", "info:fedora/afmodel:TuftsRCR"
                    "Collection Creators"
                  else
                    # COLLECTION_ERROR_LOG.error "Could not determine Format for : #{pid} with model #{model.inspect}"
                end

      Solrizer.insert_field(solr_doc, 'object_type', model_s, :facetable) if model_s


      # At this point primary classification is complete but there are some outlier cases where we want to
      # Attribute two classifications to one object, now's the time to do that
      ##,"info:fedora/cm:Audio.OralHistory","info:fedora/afmodel:TuftsAudioText" -> needs text
      ##,"info:fedora/cm:Image.HTML" -->needs text
      if ["info:fedora/cm:Audio.OralHistory", "info:fedora/afmodel:TuftsAudioText"].include? model
        Solrizer.insert_field(solr_doc, 'object_type', 'Text', :facetable)
      end
    end
  end
end
