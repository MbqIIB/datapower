<?xml version="1.0" encoding="iso-8859-1"?>

<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
xmlns:dp="http://www.datapower.com/extensions"
xmlns:dpconfig="http://www.datapower.com/param/config"
extension-element-prefixes="dp dpconfig"
exclude-result-prefixes="dp dpconfig"
xmlns:xacml="urn:oasis:names:tc:xacml:2.0:context:schema:os">


  <!--
    Pull out the uri of the original request - this is the /foo/bar part of
    http://server:1234/foo/bar
  -->
  <xsl:variable name="path"><xsl:value-of select="dp:variable('var://service/URI')"/></xsl:variable>
  
  <!--
    Load in the config file that tells us which services are configured,
    where those services are really found and the details of how to interrogate
    the policy about those services.
   -->
  <xsl:variable name="service_config" select="document('service_config.xml')/services/service[@path=$path]"/>
  
  <xsl:variable name="backend_protocol"><xsl:value-of select="$service_config/backend/protocol"/></xsl:variable>
  <xsl:variable name="backend_host"><xsl:value-of select="$service_config/backend/host"/></xsl:variable>
  <xsl:variable name="backend_port"><xsl:value-of select="$service_config/backend/port"/></xsl:variable>
  <xsl:variable name="backend_path"><xsl:value-of select="$service_config/backend/path"/></xsl:variable>
  
  <xsl:variable name="backend_url"
    select="concat($backend_protocol,'://', $backend_host, ':', $backend_port, $backend_path)"/>

 
  
  <xsl:variable name="policy_action"><xsl:value-of select="$service_config/policy/action"/></xsl:variable>
  <xsl:variable name="policy_resource"><xsl:value-of select="$service_config/policy/resource"/></xsl:variable>

  <!--
    Pull out various bits and pieces of the header for use in the xacml
    request.
  -->
  <xsl:variable name="envelope"
  select="/*[local-name()='Envelope']" />

  <xsl:variable name="security-header"
  select="/*[local-name()='Envelope']/*[local-name()='Header']/*[local-name()='Security']" />

  <!--
    This is the main template: it looks up the service url in the
    service_config map file. If the service is not there, it rejects the
    request. If the service is there, this template fires off a xacml
    request to see if the requester is allowed to access the service.
  -->
  <xsl:template match="/">
   
  
    <xsl:choose>
      <xsl:when test="count($service_config) = 0">
	<dp:reject>No service for URI</dp:reject>
      </xsl:when>
      
      <xsl:otherwise>	
            <xsl:message dp:priority="debug">OK</xsl:message>


	    <dp:set-variable name="'var://service/routing-url'"
			     value="$backend_url"/>


            <xsl:message dp:priority="debug"> *** backend-url</xsl:message>
            <xsl:message dp:priority="debug">
               <xsl:value-of select="$backend_url"/>
            </xsl:message>

	    <dp:set-variable name="'var://service/URI'"
			    value="$backend_path"/>	    
	    
	    <dp:set-variable name="'var://service/backend-url'"
			    value="$backend_path"/>

            <dp:set-variable name="'var://context/amberpoint/backend-url'" value="$backend_url"/>      
      </xsl:otherwise>
    </xsl:choose>

    <xsl:apply-templates/>

  </xsl:template>

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
