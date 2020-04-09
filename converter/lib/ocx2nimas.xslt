<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output encoding="UTF-8" doctype-public="-//NISO//DTD dtbook 2005-3//EN" doctype-system="http://www.daisy.org/z3986/2005/dtbook-2005-3.dtd" method="xml" indent="yes"/>

  <xsl:template match="/root">
    <dtbook version="2005-3">
      <head/>
      <book>
        <frontmatter>
          <doctitle>
            <xsl:value-of select="title"/>
          </doctitle>
        </frontmatter>
        <bodymatter>
          <xsl:for-each select="sections">
            <level1 class="part">
              <xsl:copy-of select="section/node()"/>
            </level1>
          </xsl:for-each>
        </bodymatter>
      </book>
    </dtbook>
  </xsl:template>

</xsl:stylesheet>
