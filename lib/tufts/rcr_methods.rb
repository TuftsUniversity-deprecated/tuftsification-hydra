module Tufts
  module RCRMethods


    @relationship_map = {"isPartOf" => "Part of",
      "reportsTo" => "Reports to",
      "hasReport" => "Has report",
      "isPartOf" => "Part of",
      "hasPart" => "Has part",
      "isMemberOf" => "Member of",
      "hasMember" => "Has member",
      "isPrecededBy" => "Preceded by",
      "isFollowedBy" => "Followed by",
      "isAssociatedWith" => "Associated with",
      "isChildOf" => "Child of",
      "isParentOf" => "Parent of",
      "isCousinOf" => "Cousin of",
      "isSiblingOf" => "Sibling of",
      "isSpouseOf" => "Spouse of",
      "isGrandchildOf" => "Grandchild of",
      "isGrandparentOf" => "Grandparent of"}


    def self.title(fedora_obj, datastream = "RCR-CONTENT")
      return fedora_obj.datastreams[datastream].get_values(:title).first
    end


    def self.dates(fedora_obj, datastream = "RCR-CONTENT")
      return fedora_obj.datastreams[datastream].get_values(:fromDate).first +
        "-" +
        fedora_obj.datastreams[datastream].get_values(:toDate).first
    end


    def self.abstract(fedora_obj, datastream = "RCR-CONTENT")
      return fedora_obj.datastreams[datastream].get_values(:bioghist_abstract).first
    end


    def self.abstract(fedora_obj, datastream = "RCR-CONTENT")
      return fedora_obj.datastreams[datastream].get_values(:bioghist_abstract).first
    end


    def self.history(fedora_obj, datastream = "RCR-CONTENT")
      return fedora_obj.datastreams[datastream].get_values(:bioghist_p)
    end


    def self.structure_or_genealogy_p(fedora_obj, datastream = "RCR-CONTENT")
      return fedora_obj.datastreams[datastream].get_values(:structure_or_genealogy_p)
    end


    def self.structure_or_genealogy_items(fedora_obj, datastream = "RCR-CONTENT")
      return fedora_obj.datastreams[datastream].get_values(:structure_or_genealogy_item)
    end


    def self.relationships(fedora_obj, datastream = "RCR-CONTENT")
      result_hash = {}
      relationships = fedora_obj.datastreams[datastream].find_by_terms_and_value(:cpf_relations)

      relationships.each do |relationship|
        role = @relationship_map.fetch(relationship.attribute("arcrole").text.sub("http://dca.lib.tufts.edu/ontology/rcr#", ""), "Unknown relationship")  # xlink:arcrole in the EAC
        name = ""
        pid = ""
        from_date = ""
        to_date = ""

        relationship.element_children.each do |child|
          childname = child.name

          if childname == "relationEntry"
            name = child.text
            pid = child.attribute("id")  # xml:id in the EAC
          elsif childname == "dateRange"
            child.element_children.each do |grandchild|
              grandchildname = grandchild.name

              if grandchildname == "fromDate"
                from_date = grandchild.text
              elsif grandchildname == "toDate"
                to_date = grandchild.text
              end
            end
          end
        end

        role_array = result_hash.fetch(role, nil)

        if role_array.nil?
          role_array = []
          result_hash.store(role, role_array)
        end

        role_array << {:name => name, :pid => pid, :from_date => from_date, :to_date => to_date}
      end

      return result_hash
    end


    def self.collections(fedora_obj, datastream = "RCR-CONTENT")
      result_array = []
      collections = fedora_obj.datastreams[datastream].find_by_terms_and_value(:resource_relations)

      collections.each do |collection|
        name = ""
        pid = collection.attribute("id").text  # xml:id in the EAC

        collection.element_children.each do |child|
          childname = child.name

          if childname == "relationEntry"
            name = child.text
            break
          end
        end

        result_array << {:name => name, :pid => pid}
      end

      return result_array
    end


  end
end
