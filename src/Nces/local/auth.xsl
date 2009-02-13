<?xml version="1.0" encoding="iso-8859-1"?>

<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
xmlns:dp="http://www.datapower.com/extensions"
xmlns:dpconfig="http://www.datapower.com/param/config"
extension-element-prefixes="dp dpconfig"
exclude-result-prefixes="dp dpconfig"
xmlns:xacml="urn:oasis:names:tc:xacml:2.0:context:schema:os">

  <!--
    Pick up the dn from the cert
  -->
  <xsl:variable name="cert-dn" select="dp:client-subject-dn()"/>

  <!--
    Load in the config file that tells us which services are configured,
    where those services are really found and the details of how to interrogate
    the policy about those services.
   -->
  <xsl:variable name="valid_dns" select="document('valid_dns.xml')/valid_dns/dn"/>
  
  <!--
    Look into the message that is coming in and pull out
    the saml subject and asserter
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
    This is the main template: it looks up the service url in the
    service_config map file. If the service is not there, it rejects the
    request. If the service is there, this template fires off a xacml
    request to see if the requester is allowed to access the service.
  -->
  <xsl:template match="/">
  
    <xsl:variable name="authorized_dn">
      <xsl:for-each select="$valid_dns">
        <xsl:if test="dp:same-dn(., $cert-dn)">
          <xsl:value-of select="."/>
        </xsl:if>
      </xsl:for-each>
    </xsl:variable>
        
    <xsl:choose>

<!--    
      <xsl:when test="$cert-dn != $saml-issuer">
          <xsl:message dp:priority="debug">Cert/SAML Issuer don't match</xsl:message>
          <xsl:message dp:priority="debug">CERT: <xsl:value-of select="$cert-dn"/></xsl:message>
          <xsl:message dp:priority="debug">ISSUER: <xsl:value-of select="$saml-issuer"/></xsl:message>
          <dp:reject>SSL Cert did not match SAML Issuer/></dp:reject>
      </xsl:when>    
-->
      <xsl:when test="not(dp:same-dn($cert-dn, $saml-name-identifier-text))">
          <xsl:message dp:priority="debug">Cert/SAML Name don't match</xsl:message>
          <xsl:message dp:priority="debug">CERT: <xsl:value-of select="$cert-dn"/></xsl:message>
          <xsl:message dp:priority="debug">SAML Name: <xsl:value-of select="$saml-name-identifier-text"/></xsl:message>
          <dp:reject>SSL Cert did not match SAML ID  cert dn [<xsl:value-of select="$cert-dn"/>] saml id: [<xsl:value-of select="$saml-name-identifier-text"/>]</dp:reject>
      </xsl:when>  
          
      <xsl:when test="string-length($authorized_dn) = 0">
          <xsl:message dp:priority="debug">Requester is not authorized to use this web service</xsl:message>
          <dp:reject>DN is not authorized<xsl:value-of select="$cert-dn"/></dp:reject>
      </xsl:when>
      
      <xsl:otherwise>
          <xsl:message dp:priority="debug">Authorized: <xsl:value-of select="$cert-dn"/></xsl:message>
          <xsl:apply-templates/>
      </xsl:otherwise>
      
    </xsl:choose>
    
    

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

