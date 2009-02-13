<?xml version="1.0" encoding="iso-8859-1"?>

<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
xmlns:dp="http://www.datapower.com/extensions"
xmlns:dpconfig="http://www.datapower.com/param/config"
extension-element-prefixes="dp dpconfig"
exclude-result-prefixes="dp dpconfig"
xmlns:xacml="urn:oasis:names:tc:xacml:2.0:context:schema:os">

  <!--
    Strip off the mustUnderstand attribute from the security header
  -->

  <xsl:template match="/*[local-name()='Envelope']/*[local-name()='Header']/*[local-name()='Security']//@*[local-name()='mustUnderstand']"/>

  <xsl:template match="/*[local-name()='Envelope']/*[local-name()='Header']/*[local-name()='MessageID']//@*[local-name()='mustUnderstand']"/>

  <!-- The standard template to copy verbatim everything that we haven't
       special-cased above. -->

<xsl:template
  match="*|@*|comment()|processing-instruction()|text()">
  <xsl:copy>
    <xsl:apply-templates
     select="*|@*|comment()|processing-instruction()|text()"/>
  </xsl:copy>
</xsl:template>

</xsl:stylesheet>

