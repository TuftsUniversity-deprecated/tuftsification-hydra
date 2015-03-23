module Tufts
  module TeiMethods
    # this relies on all deliverable chunks being div1's or div2's
    #<xsl:variable name="front-chunks" select="(/TEI.2/text/front/div1|/TEI.2/text/front/titlePage)"/>
    #<xsl:variable name="body-chunks" select="(/TEI.2/text/body/div1[not(div2)]|/TEI.2/text/body/div1/div2)"/>
    #<xsl:variable name="back-chunks" select="(/TEI.2/text/back/div1)"/>
    TOC_PREDICATE = "<tr><td>&nbsp;</td><td>"
    TOC_COLLAPSE_PREDICATE = "<tr><td class='collapse_td'><a class='collapse' href='#'><img src='/assets/img/button_collapse.png' width='11' height='11' alt='collapse'></a></td><td>"
    TOC_SUFFIX ="</td></tr>"
    TOC_CHILD_PREDICATE = "<div class=collapsabile>"
    TOC_CHILD_SUFFIX="</div>"

    #####
    # Code for getting figures
    #####
    def self.get_figures(fedora_obj)
      result = ""
      xml = fedora_obj.datastreams["Archival.xml"].ng_xml
      node_sets = xml.xpath('//figure')

      unless node_sets.nil?
        node_sets.each do |node|
          #no op
        end
      end
      result
    end

    def self.get_figures_for_chapter(fedora_obj, chapter)
      result = ""
      xml = fedora_obj.datastreams["Archival.xml"].ng_xml
      node_sets = xml.xpath('//figure')

      unless node_sets.nil?
        node_sets.each do |node|
          #no op
        end
      end
      result
    end

    ####################
    # Table of Contents
    ####################
    def self.get_toc(fedora_obj)
      chapter_list = Array.new
      toc_result = ""
      xml = fedora_obj.datastreams["Archival.xml"].ng_xml
      node_sets = xml.xpath('/TEI.2/text/front/div1|/TEI.2/text/front/titlePage')
      unless node_sets.nil?
        node_sets.each do |node|
          title = "Title Page"
          if node['n'].nil?
            type = node['type']
            unless type.nil?
              if type == 'preface'
                title = "Preface"
              elsif type == 'dedication'
                title = 'Dedication'
              elsif type == 'frontispiece'
                title = 'Frontispiece'
              end
            end
          else
            title = node['n']
          end
          toc_result += TOC_PREDICATE + "<a href='/catalog/tei/"+ fedora_obj.pid+"/chapter/"+(node['id'].nil? ? "title" : node['id'])+"'>" + title + "</a>" + TOC_SUFFIX
          chapter_list << (node['id'].nil? ? 'title' : node['id'])
        end
      end
      
      node_sets = xml.xpath('/TEI.2/text/body/div1')

      unless node_sets.nil?
        node_sets.each do |node|
          if node['type'].to_s == 'section' || node['type'].to_s == "part" || (xml.xpath("//TEI.2/text/body/div1[@id='" + node['id'].to_s + "']/div2").to_s.length > 0)
            toc_result += TOC_COLLAPSE_PREDICATE + "<a class='collapse_td' href='/catalog/tei/"+ fedora_obj.pid+"/chapter/"+node['id'].to_s + "'>" + node['n'].to_s + "</a>"
            toc_result += "<div class='collapse_content'>"
            toc_result2, chapter_list = self.get_subsection(fedora_obj, node, chapter_list)
            toc_result += toc_result2
            toc_result += "</div>"
            toc_result += TOC_SUFFIX
          else
            toc_result += TOC_PREDICATE + "<a href='/catalog/tei/"+ fedora_obj.pid + "/chapter/" + node['id'].to_s + "'>" + node['n'].to_s + "</a>" + TOC_SUFFIX
            chapter_list << node['id'].to_s
          end
          #  result << ctext(node)
        end
      end

      node_sets = xml.xpath('/TEI.2/text/back/div1')

      unless node_sets.nil?
        node_sets.each do |node|
          title = "Back Page"

          unless node['n'].nil?
            title = node['n']
          end

          toc_result += TOC_PREDICATE + "<a href='/catalog/tei/"+ fedora_obj.pid+"/chapter/"+(node['id'].nil? ? "title" : node['id'])+"'>" + title + "</a>" + TOC_SUFFIX
          chapter_list << node['id']
        end
      end

      return toc_result, chapter_list
    end

    def self.get_subsection(fedora_obj, node, chapter_list)
      result = ""
      champter_list = ""
      id = node['id']
      if id.nil?
        n = node['n']
        node_sets = node.xpath('/TEI.2/text/body/div1[@n="'+ n +'"]/div2')
      else
        node_sets = node.xpath('/TEI.2/text/body/div1[@id="'+ id +'"]/div2')
      end
      unless node_sets.nil?
        node_sets.each do |node2|
          unless node2['id'].nil?
            chapter_title = node2['n'].to_s
            chapter_title.nil? ? chapter_title ='[chapter]' : chapter_title
            result << "<a href='/catalog/tei/"+ fedora_obj.pid + "/chapter/" + node2['id'].to_s + "'>" + chapter_title + "</a><br/>"
            chapter_list << node2['id'].to_s
          else
            chapter_title = node2['n'].to_s
            chapter_title.nil? ? chapter_title ='[chapter]' : chapter_title
            result << "<a href='/catalog/tei/" + fedora_obj.pid + "/chapter/" + node['id'].to_s + "'>" + chapter_title + "</a><br/>"
            chapter_list << node['id'].to_s
          end
        end
      end
      return result, chapter_list
    end


    ####################
    # TEI Cover Page
    ####################
    def self.show_tei_cover(fedora_obj, chapter)
      result = ""
      xml = fedora_obj.datastreams["Archival.xml"].ng_xml
      # tei cover will be one of these 2 elements.
      node_sets = xml.xpath('/TEI.2/text/front/div1|/TEI.2/text/front/titlePage')

      result += self.show_tei_table_start

      if chapter == 'title'
        node = node_sets.first
        if !node.nil? && node['type'] == 'frontispiece'
          node = node_sets.to_ary[1]
        end
        result << self.ctext(node)
      else
        unless node_sets.nil?
          node_sets.each do |node|
            if chapter == 'title' || (chapter != "title" && chapter == node['id'])
              result << self.ctext(node)
            end
          end
        end
      end

      result += self.show_tei_table_end

      result
    end

    def self.show_tei_backpage(fedora_obj, chapter)
      result = ""
      result += self.show_tei_table_start
      xml = fedora_obj.datastreams["Archival.xml"].ng_xml
      node_sets = xml.xpath('/TEI.2/text/back/div1')
      unless node_sets.nil?
        node_sets.each do |node|
          if chapter == 'title' || (chapter != "title" && chapter == node['id'])
            result << self.ctext(node)
          end
        end
      end

      result += self.show_tei_table_end
      result
    end

    # recursive function to walk the title page stick everything into divs
    def self.ctext(el)
      if el.nil?
        return ""
      end
      if el.text?
        return el.text
      end
      result = []
      for sel in el.children
        if sel.element?
          type = sel[:type]
          if sel.name == 'figure'
            pid = PidMethods.urn_to_pid(sel['n'])
            result.push("<br/><br/><img alt=\"\" src=\"" + "/file_assets/" + pid + "\"></img>")
          else
            result.push("<div class='" + sel.name + " " + (type.nil? ? "" : type) + "'>")
          end
        end
        result.push(ctext(sel))
        if sel.element?
          unless sel.name == 'figure'
            result.push("</div>")
          end
        end
      end
      return result.join
    end

    def self.show_tei_table_start
      return '<table cellpadding="2" cellspacing="5" class="noborder bookviewer_table"><tbody>'
    end

    def self.show_tei_table_end
      return '</tbody></table>'
    end

    def self.show_tei(fedora_obj, chapter)

      # if there's no chapter specified show the cover
      if chapter.nil?
        chapter = "title"
      end

      # special case show the cover
      if chapter == "title" || (chapter.start_with? "front")
        return show_tei_cover(fedora_obj, chapter)
      end

      # special case show the back cover
      if chapter.starts_with? "back"
        return show_tei_backpage(fedora_obj, chapter)
      end
      return show_tei_page(fedora_obj, chapter)
    end

    def self.render_pb(node)
     ## if node['n'] == "39"
     ##   puts "blah"
     ## end
      if node['n'].nil?
        result = ""
      else
        result = "<p>" + node['n'] + "</p>"
      end

      result
    end

    def self.get_block_quote(node)
      result = '<blockquote>'

      children = node.children
      children.each do |child|
        child_text = child.text.to_s.strip

        result += "<p>" + child.text + "</p>"
      end
      result += "</blockquote>"
      result
    end

    def self.render_subject_terms(tei_xml, chapter)
      result = '<tr><td>&nbsp;</td><td>'
      # at the end of the chapter/ look for subject terms list, print header.
      node_sets = tei_xml.xpath('//body/div1[@id="' + chapter +'"]/list/head|//body/div1/div2[@id="' + chapter +'"]/list/head')

      unless node_sets.nil?
        node_sets.each do |node|
          result += "<h5 class=subject_terms>" + node + "</h5>"

        end
      end

      # at the end of the chapter/ look for subject terms list, print actual list with subject searches.
      node_sets = tei_xml.xpath('//body/div1[@id="' + chapter +'"]/list/item|//body/div1/div2[@id="' + chapter +'"]/list/item')

      unless node_sets.nil?
        node_sets.each do |node|

          result += "<div class=subject_list_item><a href='/catalog?f[subject_facet][]="+ node+"'>" + node + "</a></div>"

        end
      end

      result += '</tr></td>'
      result
    end

    def self.get_foot_note(child)
      footnotes =""
      note_id = child['n'].nil? ? child['id'] : child['n']
      unless note_id.nil?
        result = "<a href='#'>[" + note_id + "]</a>&nbsp;"
      else
        note_id = ""
      end

      child_text = child.text.to_s.strip

      if child.name == "note"
        footnotes = "<p>["+ note_id +"] " + child_text + "</p>"
      end

      return result, footnotes
    end

    def self.render_table(node, in_left_td)
      result = "<table>"
      rows = node.children
      rows.each do |row|
        result += "<tr>"
        cols = row.children
        cols.each do |col|
          result += "<td>"
          text = col.text.to_s.strip
          result += (text.nil? || text.length == 0) ? "&nbsp;" : text
          result += "</td>"
        end
        result += "</tr>"
      end
      result += "</table>"
      result
    end

    def self.render_page_p(node, in_left_td)
      result = ""
      footnotes =""
      children = node.children
      result +="<p>"
      children.each do |child|
        child_text = child.text.to_s.strip
        if child.name == "text" && !child_text.empty? && child.type == 3
          if in_left_td
            result += switch_to_right
            result += "<td>"
            in_left_td = false
          end
          result += child.text
        elsif child.name == "pb"
          unless in_left_td
            result += switch_to_left
            in_left_td = true
          end
          result += render_pb(child)
          in_left_td = true
        elsif child.name == "figure"
          unless in_left_td
            result += switch_to_left
            in_left_td = true
          end
          result +="<ul class=thumbnails><li>"
          #result +='<a data-toggle="modal" href="#myImageOverlay"  class="thumbnail">'
          pid = PidMethods.urn_to_pid(child['n'])
          result +='<a data-pid="'+ pid+'" href="/catalog/' + pid + '"  class="thumbnail">'
          #          <%= link_to image_tag("/file_assets/thumb/"+document[:id] , :alt=>document[:title],:class=>"thumbnailwidth"), "/catalog/" + document[:id],:class=>"thumbnail" %>


          result +='<img src="/file_assets/thumb/' + pid + '">'
          result +="</a>"
          result +="</li></ul>"
        elsif child.name == "quote"
          if in_left_td
            result += switch_to_right
            result += "<td>"
            in_left_td = false
          end
          result += get_block_quote(child)
        elsif child.name == "table"
          if in_left_td
            result += switch_to_right
            result += "<td>"
            in_left_td = false
          end
          result += render_table(child, in_left_td)
        elsif child.name == "note"
          result_fn, result_foot = get_foot_note(child)
          unless result_fn.nil?
            result += result_fn
          end
          footnotes += result_foot
        end

      end
      result +="</p>"


      return result, in_left_td, footnotes
    end

    def self.switch_to_right
      return "</td>"
    end

    def self.switch_to_left
      return "</td><tr><td class=pagenumber>"
    end

    def self.render_footnotes(footnotes)
      result =""
      unless footnotes.nil? || footnotes.empty?
        result = "<tr><td>&nbsp;</td><td>"
        result += "<br/>"
        result += "<span class=maintextviewer-footnotesheader>Footnotes:</span><hr/>"
        result += footnotes
        result += "</td></tr>"
      end

      result
    end

    def self.render_image_page(fedora_obj, chapter)
      result = ""

      node_sets = fedora_obj.datastreams["Archival.xml"].ng_xml.xpath('//body/div1/div2[@id="' + chapter +'"]/p/figure/head|//body/div1[@id="'+chapter+'"]/figure/head')
      unless node_sets.nil?
        node_sets.each do |node|
          result += "<h6>" + node + "</h6><br/>"
        end
      end

      node_sets = fedora_obj.datastreams["Archival.xml"].ng_xml.xpath('//body/div1/div2[@id="' + chapter +'"]/p/figure|//body/div1[@id="'+chapter+'"]/figure')
      unless node_sets.nil?
        node_sets.each do |node|
          pid = PidMethods.urn_to_pid(node['n'])
          result += ("<br/><br/><img alt=\"\" src=\"" + "/file_assets/" + pid + "\"></img>")
        end
      end

      node_sets = fedora_obj.datastreams["Archival.xml"].ng_xml.xpath('//body/div1/div2[@id="' + chapter +'"]/p/figure/figDesc|//body/div1[@id="'+chapter+'"]/figure/figDesc')
      unless node_sets.nil?
        node_sets.each do |node|

          result += ("<p>"+ node+"</p>")
        end
      end


      result
    end

    def self.render_text_page(tei_xml, chapter, footnotes)
      result = self.show_tei_table_start
#result += "<p>render_text_page</p>" 
# get the chapter text.
      node_sets = tei_xml.xpath('//body/div1[@id="' + chapter +'"]/p|//body/div1/div2[@id="' + chapter +'"]/p|//body/div1[@id="' + chapter +'"]/quote|//body/div1/div2[@id="' + chapter +'"]/quote|//body/div1/div2[@id="' + chapter + '"]|//body/div1[@id="' + chapter + '"]')
      in_left_td = true
      unless node_sets.nil?
        if node_sets.first.name == "div1"
          node_sets = node_sets.first.children
        end
        node_sets.each do |node|
          node_text = node.text.to_s.strip
          unless node_text.nil? || node_text.empty?
            result += "<tr>"
            result += "<td class=pagenumber>"
            logger.warn "node name #{node.name}"
            case node.name
              when "pb"
                result += render_pb(node)
              when "quote"
                if in_left_td
                  result += switch_to_right
                  result += "<td>"
                  in_left_td = false
                end

                result += get_block_quote(node)
              when "p"
                #if we're in the left close it.
                if in_left_td
                  result += switch_to_right
                  in_left_td = false
                end

                result += "<td>"

                result_p, in_left_td2, footnotes2 = render_page_p(node, in_left_td)
                in_left_td = in_left_td2
                footnotes += footnotes2
                result += result_p
              when "table"
                result += render_table(node, in_left_td)
              when "list"
                result += "<p></p>"
              when "div2"
                if in_left_td
                  result += switch_to_right
                  in_left_td = false
                end
                if chapter.include? 'fig'
                  result += self.ctext(node)
                else
                  begin
                    ls = node.children
                    ls.each do |l|
                      result += "<p>" + l.text.to_s.strip + "</p>"
                    end
                  rescue
                    logger.warn "error #{result}"
                  end
                end
              when "lg"
                if in_left_td
                  result += switch_to_right
                  in_left_td = false
                end
                result += "<td>"
                begin
                ls = node.children
                ls.each do |l|
                  result += "<p>" + l.text.to_s.strip + "</p>"
                end
                rescue
                  logger.warn "error #{result}"
                end
              when "head"
                unless result.nil?
                  begin
                    result += "<p></p>"
                  rescue
                    puts "error #{result}"
                  end
                end
              else
                if in_left_td
                  result += switch_to_right
                  in_left_td = false
                end
                logger.warn "#{node.name}"
            end
            if in_left_td
              result +="</td><td>&nbsp;</td>"
              in_left_td = true
            else
              result += "</td>"
              in_left_td=true
            end
            result += "</tr>"
          end
        end
      end

      result += render_subject_terms(tei_xml, chapter)
      result += render_footnotes(footnotes)
      result += self.show_tei_table_end
      result
    end

    def self.is_chapter_image_book(fedora_obj, chapter)
      node_sets = fedora_obj.datastreams["Archival.xml"].ng_xml.xpath('//body/div1[@id="'+chapter+'"]/figure|//body/div1[@id="' + chapter +'"]/p|//body/div1/div2[@id="' + chapter +'"]/p|//body/div1[@id="' + chapter +'"]/quote|//body/div1/div2[@id="' + chapter +'"]/quote')
      unless node_sets.nil?
        node_sets.each do |node|
          if node.parent['rend'] == 'page-image'
            return true
          else
            return false
          end
        end
      end
      return false
    end

    def self.show_tei_page(fedora_obj, chapter)
      # render the requested chapter.
      # NOTE: should break this out into a method probably.
      result = ""
      footnotes =""
      tei_xml = fedora_obj.datastreams["Archival.xml"].ng_xml
      node_sets = tei_xml.xpath('//body/div1[@id="' + chapter +'"]/head|//body/div1/div2[@id="' + chapter +'"]/head')
      unless node_sets.nil?
        node_sets.each do |node|
          result += "<h6>" + node + "</h6><br/>"

        end
      end


      # render the bibl
      node_sets = tei_xml.xpath('//body/div1[@id="' + chapter +'"]/head|//body/div1/div2[@id="' + chapter +'"]/bibl')
      unless node_sets.nil?
        node_sets.each do |node|
          result += "<p class=" + node.name + ">" + node + "</p>"

        end
      end

      #peek ahead and see if this is an image book if not render it as a standard text book.
      #result +="<p> is chapter image book : "+ (is_chapter_image_book(fedora_obj, chapter).to_s) +"</p>"
      if is_chapter_image_book(fedora_obj, chapter)
        result += render_image_page(fedora_obj, chapter)
      else
        result += render_text_page(tei_xml, chapter, footnotes)
      end

      return result
    end


    # private # all methods that follow will be made private: not accessible for outside objects


  end

end
