module Tufts
  module MetadataMethods
    def self.get_metadata(fedora_obj)
      datastream = fedora_obj.datastreams["DCA-META"]

      # create the union (ie, without duplicates) of subject, geogname, persname, and corpname
      subjects = []
      Tufts::MetadataMethods.union(subjects, datastream.find_by_terms_and_value(:subject))
      Tufts::MetadataMethods.union(subjects, datastream.find_by_terms_and_value(:geogname))
      Tufts::MetadataMethods.union(subjects, datastream.find_by_terms_and_value(:persname))
      Tufts::MetadataMethods.union(subjects, datastream.find_by_terms_and_value(:corpname))

      return {
          :titles => datastream.find_by_terms_and_value(:title),
          :creators => datastream.find_by_terms_and_value(:creator),
          :dates => datastream.find_by_terms_and_value(:date),
          :descriptions => datastream.find_by_terms_and_value(:description),
          :sources => datastream.find_by_terms_and_value(:source2),
          :citable_urls => datastream.find_by_terms_and_value(:identifier),
          :citations => datastream.find_by_terms_and_value(:bibliographicCitation),
          :publishers => datastream.find_by_terms_and_value(:publisher),
          :genres => datastream.find_by_terms_and_value(:genre),
          :types => datastream.find_by_terms_and_value(:type2),
          :formats => datastream.find_by_terms_and_value(:format2),
          :rights => datastream.find_by_terms_and_value(:rights),
          :subjects => subjects,
          :temporals => datastream.find_by_terms_and_value(:temporal)
      }
    end

     #Deprecated - may not work
    def show_rights
      logger.warn "[DEPRECATION] 'show_rights' is deprecated please use 'Tufts::MetadataMethods.get_metadata instead"
      result =""
      rights_array = @document_fedora.datastreams["DCA-META"].rights

      if rights_array.empty?
        result << "<a href=\"http://www.tufts.edu\">Link to generic rights statement</a>"
      else
        result << "<a href=\"" + rights_array.first + "\">Detailed Rights</a>"
      end
      result
    end

    def get_collection_link_for_object()
      get_ead_title(@document_fedora)
    end

    def show_creator
      showMetadataItem(nil, "creator", :creator, "h5")
    end

    def show_title
      showMetadataItem(nil, "title", :title, nil)

    end

    def showMetadataItem(label, tagID, metadataKey, *args)
      return showMetadataItemForDatastreamWrap("DCA-META", label, tagID, metadataKey, args[0])
    end

    def show_pid(pid)
      result =""
      result += "<div class=\"metadata_row\" id=\"" + "pid" + "\"><div class=\"metadata_label\">" + "ID" + "</div><div class=\"metadata_values\">"
      result += pid +"</div></div>"
    end

    def showMetadataItemForDatastream(datastream, label, tagID, metadataKey)
      return showMetadataItemForDatastreamWrap(datastream, label, tagID, metadataKey, nil)
    end

    def showMetadataItemForDatastreamWrap(datastream, label, tagID, metadataKey, wrap_tag)
      value_array = @document_fedora.datastreams[datastream].send(metadataKey)
      result = ""

      unless value_array.first.empty?

        unless label.nil?
          result += "<div class=\"metadata_row\" id=\"" + tagID + "\"><div class=\"metadata_label\">" + label + "</div><div class=\"metadata_values\">"
        end

        value_array.each do |metadataItem|
          if wrap_tag.nil?
            result += metadataItem
          else
            result += "<" +wrap_tag + ">" + metadataItem + "</" +wrap_tag +">"
          end
        end

        unless label.nil?
          result += "</div></div>"
        end
      end
      raw result
    end


     #Deprecated - may not work
    def get_subject_terms
      logger.warn "[DEPRECATION] 'get_subject_terms' is deprecated please use 'Tufts::MetadataMethods.get_metadata instead"
      result =""
      subject_array = @document_fedora.datastreams["DCA-META"].subject

      unless subject_array.empty?
        result << "<dd>Subject</dd>"
      end
      subject_array.each do |subject|
        result << "<dt>"+link_to(subject, "/catalog?f[subject_facet][]="+ subject)+"</dt>"
      end

      raw result
    end

     #Deprecated - may not work
    def get_genre
      logger.warn "[DEPRECATION] 'get_genre' is deprecated please use 'Tufts::MetadataMethods.get_metadata instead"
      result =""
      genre_array = @document_fedora.datastreams["DCA-META"].genre

      unless genre_array.empty? || genre_array.first.blank?
        result << "<dd>Genre</dd>"
      end

      genre_array.each do |genre|
        result << "<dt>"+genre+"</dt>"
      end


      raw result
    end

     #Deprecated - may not work
    def get_handle
      logger.warn "[DEPRECATION] 'get_handle' is deprecated please use 'Tufts::MetadataMethods.get_metadata instead"
      result ="<dd>Permanent URL</dd>"
      handle_array = @document_fedora.datastreams["DCA-META"].identifier
      result << "<dt>"+handle_array.first+"</dt>"
      raw result
    end

     #Deprecated - may not work
    def get_original_publication
      logger.warn "[DEPRECATION] 'get_original_publication' is deprecated please use 'Tufts::MetadataMethods.get_metadata instead"
      result =""
      bib_array = @document_fedora.datastreams["DCA-META"].bibliographicCitation

      unless bib_array.empty?
        result ="<dd>Original Publication</dd>"
      end

      bib_array.each do |bib|
        result << "<dt>"+bib+"</dt>"
      end


      raw result

    end

     #Deprecated - may not work
    def show_date
      logger.warn "[DEPRECATION] 'show_date' is deprecated please use 'Tufts::MetadataMethods.get_metadata instead"
      result =""
      dates_array = @document_fedora.datastreams["DCA-META"].date

      if dates_array.first.blank?
        dates_array = @document_fedora.datastreams["DCA-META"].temporal
      end

      dates_array.each do |metadataItem|
        result += "<h6>" + metadataItem + "</h6>"
      end

      raw result
    end

    def get_appears_in_text()

      ebook = @document_fedora.relationships(:is_dependent_of)
      ebook_title = nil

      if ebook.first.nil?
        # there is no hasDescription
        return ""

      else
        ebook = ebook.first.gsub('info:fedora/', '')
        ebook_obj = nil
        begin
          ebook_obj=TuftsTEI.find(ebook)
        rescue ActiveFedora::ObjectNotFoundError => e
         logger.warn e.message
        end

        if ebook_obj.nil?
          Rails.logger.debug "EAD Nil " + ebook
        else

          ebook_title = ebook_obj.datastreams["DCA-META"].get_values(:title).first
          ebook_title = Tufts::ModelUtilityMethods.clean_ead_title(ebook_title)

        end
      end

      if ebook_title.blank?
        return ""
      else
        result = ""
        result << "<dd>This illustration appears in:</dd>"
        result << "<dt>"+link_to(ebook_title, "/catalog/"+ ebook)+"</dt>"
        raw result
      end


    end

    def self.read_more_or_less(text, length, read_more_text = "read more", read_less_text = "read less")
      # First parameter is a string.
      # Second parameter is the length at which the output should be abbreviated with a "read more" link.
      # Optional third and fourth parameters are the text for the "read more" and "read less" links.
      # Output is a string;  if the length of the string exceeds the abbreviation length,
      # html span tags will be inserted at the abbreviation point and at the end.
      # No formatting tags like <p> or <br> are inserted;  the calling method can (must) arrange the text as needed.
      # When the "read more" link is clicked the hidden span will be shown, and there will be a "read less" link that
      # will have the opposite effect.  If no "read less" link is desired, pass "" for the fourth parameter.
      # Also include the javascript file read_more_or_less.js which has the functions that hide/show the spans.
      result = ""

      if text.length <= length
        result << text
      else
        result << (text[0..(length - 1)] +
            "<span id=\"readmore\" style=" ">...  <a href=\"javascript:readmore();\">" + read_more_text + "</a></span><span id=\"readless\" style=\"display:none\">" +
            text[length..text.length] +
            "  <a href=\"javascript:readless();\">" + read_less_text + "</a></span>")
      end

      return result
    end

    def self.union(array1, array2)
      # Params are two arrays of Nokogiri elements.  Add elements of array2 to array1 and return array1.
      # Leave out duplicate elements, where e.g. <dcadesc:geogname>Somerville (Mass.)</dcadesc:geogname> and
      # <dcadesc:subject>Somerville (Mass.)</dcadesc:subject> are defined as duplicate (i.e., their .text is ==).

      array2.each do |element2|
        dup = false

        array1.each do |element1|
          if element1 == element2
            dup = true
            break
          end
        end

        if !dup
          array1 << element2
        end
      end

      return array1
    end
  end
end
