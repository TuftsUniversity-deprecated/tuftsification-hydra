class TuftsEADMeta < TuftsDatastream

  set_terminology do |t|
    # Since our old EADs have xmlns="http://dca.tufts.edu/schema/ead" and our new
    # ArchivesSpace-generated EADs have xmlns="urn:isbn:1-931666-22-9", do not
    # specify a namespace so that either (or any future) namespace will work.
    t.root(:path => "ead")

    t.eadheader(:path => "eadheader") {
      t.eadid(:path => "eadid")
      t.filedesc(:path => "filedesc") {
        t.titlestmt(:path => "titlestmt") {
          t.titleproper(:path => "titleproper")
        }
        t.publicationstmt(:path => "publicationstmt") {
          t.publisher(:path => "publisher")
          t.address(:path => "address") {
            t.addressline(:path => "addressline")
          }
          t.date(:path => "date")
        }
      }
    }

    t.frontmatter(:path => "frontmatter") {
      t.titlepage(:path => "titlepage") {
        t.titleproper(:path => "titleproper")
        t.num(:path => "num")
        t.publisher(:path => "publisher")
        t.address(:path => "address") {
          t.addressline(:path => "addressline")
        }
        t.date(:path => "date")
      }
    }

    t.archdesc(:path => "archdesc") {
      t.did(:path => "did") {
        t.head(:path => "head")
        t.repository(:path => "repository") {
          t.corpname(:path => "corpname")
          t.address(:path => "address") {
            t.addressline(:path => "addressline")
          }
        }
        t.origination(:path => "origination") {
          t.persname(:path => "persname")
          t.corpname(:path => "corpname")
          t.famname(:path => "famname")
        }
        t.unittitle(:path => "unittitle")
        t.unitdate(:path => "unitdate")
        t.physdesc(:path => "physdesc")
        t.unitid(:path => "unitid")
        t.abstract(:path => "abstract")
      }

      t.bioghist(:path => "bioghist") {
        t.head(:path => "head")
        t.note(:path => "note") {
          t.p(:path => "p")
        }
        t.p(:path => "p")
      }

      t.scopecontent(:path => "scopecontent") {
        t.head(:path => "head")
        t.note(:path => "note") {
          t.p(:path => "p")
        }
        t.p(:path => "p")
      }

      t.descgrp(:path => "descgrp") {
        t.accessrestrict(:path => "accessrestrict") {
          t.head(:path => "head")
          t.p(:path => "p")
        }

        t.userestrict(:path => "userestrict") {
          t.head(:path => "head")
          t.p(:path => "p")
        }

        t.prefercite(:path => "prefercite") {
          t.head(:path => "head")
          t.p(:path => "p")
        }
      }

      t.controlaccess(:path => "controlaccess") {
        t.head(:path => "head")
        t.controlaccess(:path => "controlaccess")
      }

      t.dsc(:path => "dsc") {
        t.c01(:path => "c01") {
          t.did(:path => "did")
          t.arrangement(:path => "arrangement")
          t.scopecontent(:path => "scopecontent") {
            t.note(:path => "note") {
              t.p(:path => "p")
            }
            t.p(:path => "p")
          }

          t.c02(:path => "c02") {
            t.did(:path => "did") {
              t.unittitle(:path => "unittitle")
            }
          }
        }

        t.c(:path => "c") {
          t.did(:path => "did")
          t.arrangement(:path => "arrangement")
          t.scopecontent(:path => "scopecontent") {
            t.note(:path => "note") {
              t.p(:path => "p")
            }
            t.p(:path => "p")
          }

          t.c(:path => "c") {
            t.did(:path => "did") {
              t.unittitle(:path => "unittitle")
            }
          }
        }
      }

      t.separatedmaterial(:path => "separatedmaterial") {
        t.head(:path => "head")
        t.p(:path => "p")
      }
      t.relatedmaterial(:path => "relatedmaterial") {
        t.head(:path => "head")
        t.p(:path => "p")
      }
      t.processinfo(:path => "processinfo") {
        t.head(:path => "head")
        t.p(:path => "p")
      }
      t.acqinfo(:path => "acqinfo") {
        t.head(:path => "head")
        t.p(:path => "p")
      }
    }

    # Overview
    t.unittitle(:proxy => [:archdesc, :did, :unittitle])
    t.unitdate(:proxy => [:archdesc, :did, :unitdate])
    t.physdesc(:proxy => [:archdesc, :did, :physdesc])
    t.unitid(:proxy => [:archdesc, :did, :unitid])
    t.abstract(:proxy => [:archdesc, :did, :abstract])
    t.persname(:proxy => [:archdesc, :did, :origination, :persname])
    t.corpname(:proxy => [:archdesc, :did, :origination, :corpname])
    t.famname(:proxy => [:archdesc, :did, :origination, :famname])

    # Contents
    t.bioghistp(:proxy => [:archdesc, :bioghist, :p])
    t.scopecontentp(:proxy => [:archdesc, :scopecontent, :p])

    # Series Descriptions
    t.series(:proxy => [:archdesc, :dsc, :c01])

    # Series Descriptions - new ArchivesSpace style
    t.aspaceseries(:proxy => [:archdesc, :dsc, :c])

    # Names and Subjects
    t.controlaccess(:proxy => [:archdesc, :controlaccess])

    # Related Collections
    t.separatedmaterialp(:proxy => [:archdesc, :separatedmaterial, :p])
    t.relatedmaterialp(:proxy => [:archdesc, :relatedmaterial, :p])

    # Access and Use
    t.accessrestrictp(:proxy => [:archdesc, :descgrp, :accessrestrict, :p])
    t.userestrictp(:proxy => [:archdesc, :descgrp, :userestrict, :p])
    t.prefercitep(:proxy => [:archdesc, :descgrp, :prefercite, :p])

    # Administrative Notes
    t.processinfop(:proxy => [:archdesc, :processinfo, :p])
    t.acqinfop(:proxy => [:archdesc, :acqinfo, :p])

  end

#    def self.xml_template
#      builder = Nokogiri::XML::Builder.new do |xml|
#        xml.tuftsEAD() {
#          xml.eadheader {
#            xml.eadid
#            xml.filedesc {
#              xml.titlestmt {
#                xml.titleproper
#              }
#              xml.publicationstmt {
#                xml.publisher
#                xml.address {
#                  xml.addressline
#                }
#                xml.date
#              }
#            }
#          }
#        }
#      end
#
#      return builder.doc
#    end

  def to_solr(solr_doc = Hash.new) # :nodoc:
    return solr_doc
  end
end
