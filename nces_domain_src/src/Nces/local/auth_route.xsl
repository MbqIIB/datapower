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

  <xsl:variable name="saml-assertion"
  select="$security-header/*[local-name()='Assertion']" />

  <xsl:variable name="saml-authn-statement"
  select="$saml-assertion/*[local-name()='AuthenticationStatement']" />

  <xsl:variable name="saml-issuer"
  select="$saml-assertion/@Issuer" />

  <xsl:variable name="saml-name-identifier-text"
  select="$saml-authn-statement/*[local-name()='Subject']/*[local-name()='NameIdentifier']/text()" />

  <!--
    This template actually runs the xacml request and returns the xacml response.
  -->
 <xsl:template name="run_xacml">
    <dp:url-open target="{document('config-xacml-service.xml')}" response="xml" content-type="text/xml">
      <S:Envelope xmlns:S="http://schemas.xmlsoap.org/soap/envelope/">
        <S:Body>
          <xacml:Request 
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="urn:oasis:names:tc:xacml:2.0:context:schema:os access_control-xacml-2.0-context-schema-os.xsd">
	  
            <xacml:Subject>

              <xacml:Attribute AttributeId="urn:net:mirius:security:1.0:saml-issuer"
              DataType="http://www.w3.org/2001/XMLSchema#string">
                <xacml:AttributeValue>
                  <xsl:value-of select="$saml-issuer"/>
                </xacml:AttributeValue>
              </xacml:Attribute>

              <xacml:Attribute AttributeId="urn:oasis:names:tc:xacml:1.0:subject:subject-id"
              DataType="urn:oasis:names:tc:xacml:1.0:data-type:x500Name">
                <xacml:AttributeValue>
                  <xsl:copy-of select="$saml-name-identifier-text" />
                </xacml:AttributeValue>
              </xacml:Attribute>

	      <xsl:apply-templates select="/*[local-name()='Envelope']/*[local-name()='Header']/*[local-name()='Security']/*[local-name()='Assertion']/*[local-name()='AttributeStatement']/*[local-name()='Attribute']"/>

            </xacml:Subject>


            <xacml:Resource>
              <xacml:Attribute AttributeId="urn:oasis:names:tc:xacml:1.0:resource:resource-id"
              DataType="http://www.w3.org/2001/XMLSchema#anyURI">
                <xacml:AttributeValue><xsl:value-of select="$policy_resource"/></xacml:AttributeValue>
              </xacml:Attribute>

              <xacml:Attribute AttributeId="urn:net:mirius:security:1.0:url-in"
              DataType="http://www.w3.org/2001/XMLSchema#anyURI">
                <xacml:AttributeValue><xsl:value-of select="dp:variable('var://service/URL-in')" /></xacml:AttributeValue>
              </xacml:Attribute>

              <xacml:Attribute AttributeId="urn:net:mirius:security:1.0:backend-url"
              DataType="http://www.w3.org/2001/XMLSchema#anyURI">
                <xacml:AttributeValue><xsl:value-of select="$backend_url" /></xacml:AttributeValue>
              </xacml:Attribute>

              <xacml:Attribute AttributeId="urn:net:mirius:security:1.0:path"
              DataType="http://www.w3.org/2001/XMLSchema#anyURI">
                <xacml:AttributeValue><xsl:value-of select="$path" /></xacml:AttributeValue>
              </xacml:Attribute>
            </xacml:Resource>


            <xacml:Action>
	    	    
              <xacml:Attribute AttributeId="urn:oasis:names:tc:xacml:1.0:action:action-id"
              DataType="http://www.w3.org/2001/XMLSchema#string">
                <xacml:AttributeValue><xsl:value-of select="$policy_action"/></xacml:AttributeValue>
              </xacml:Attribute>
	      	      
            </xacml:Action>

            <xacml:Environment />
          </xacml:Request>
        </S:Body>
      </S:Envelope>
    </dp:url-open>
  </xsl:template>


  <!--
    The next couple of templates take care of the heavy lifting involved
    int turning the SAML attributes from the original request into
    XACML attributes for the XACML request.
  -->
  <xsl:template match="/*[local-name()='Envelope']/*[local-name()='Header']/*[local-name()='Security']/*[local-name()='Assertion']/*[local-name()='AttributeStatement']/*[local-name()='Attribute']">
    <xacml:Attribute AttributeId="{@AttributeNamespace}/{@AttributeName}" DataType="http://www.w3.org/2001/XMLSchema#string">
      <xsl:apply-templates select="*[local-name()='AttributeValue']"/>
    </xacml:Attribute>
  </xsl:template>
  

  <xsl:template match="/*[local-name()='Envelope']/*[local-name()='Header']/*[local-name()='Security']/*[local-name()='Assertion']/*[local-name()='AttributeStatement']/*[local-name()='Attribute']/*[local-name()='AttributeValue']">
    <xacml:AttributeValue><xsl:value-of select="."/></xacml:AttributeValue>
  </xsl:template>
  

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
            <dp:set-variable name="'var://service/URI'"
                       value="$backend_path"/>
         </xsl:template>
	
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
