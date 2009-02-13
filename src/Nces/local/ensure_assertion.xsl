<?xml version="1.0" encoding="iso-8859-1"?>

<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"
  xmlns:wsa="http://schemas.xmlsoap.org/ws/2003/03/addressing"
  xmlns:wsse='http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'
  xmlns:SOAP='http://schemas.xmlsoap.org/soap/envelope/'
  xmlns:saml='urn:oasis:names:tc:SAML:1.0:assertion'
  xmlns:date='http://exslt.org/dates-and-times'
  xmlns:dp='http://www.datapower.com/extensions'
  xmlns:dpconfig='http://www.datapower.com/param/config'
  extension-element-prefixes='date dp dpconfig'
  exclude-result-prefixes='date dp dpconfig'>

  <xsl:variable name="current-time" select="date:date-time()"/>
  <xsl:variable name="expiration" select="date:add($current-time, date:duration('300'))"/>

  <xsl:variable name="input-doc-authn-subject"
    select="/*[local-name()='Envelope']/*[local-name()='Header']/*[local-name()='Security']/*[local-name()='Assertion']/*[local-name()='AuthenticationStatement']/*[local-name()='Subject']"/>


  <!--
    SAML subject, pulled from either the input message or from configuration.
   -->

  <xsl:variable name="saml-subject">
    <xsl:choose>
      <xsl:when test="count($input-doc-authn-subject)>0">
        <xsl:copy-of select="$input-doc-authn-subject"/>
        <xsl:message dp:priority="debug">Using input doc subject!</xsl:message>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy-of select="document('config-saml-service.xml')/SAMLServiceConfiguration/DefaultIdentity/*[local-name()='Subject']"/>
        <xsl:message dp:priority="debug">Using configured subject!</xsl:message>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <!--
    HTTP headers sent with the saml request
  -->

  <xsl:variable name="httpHeaders">
    <header name="SOAPAction">SAML-Attribute-Request</header>
    <header name="Content-Type">text/xml</header>
  </xsl:variable>

 <xsl:variable name="input-doc-attr-statement"
    select="/*[local-name()='Envelope']/*[local-name()='Header']/*[local-name()='Security']/*[local-name()='Assertion']/*[local-name()='AttributeStatement']"/>

  <!--
    This is the request we will send to the saml provider if we need to
    send a request
   -->

  <xsl:variable name="saml-attr-request">
    <SOAP:Envelope>
      <SOAP:Body>
        <Request IssueInstant='{$current-time}'
        MinorVersion='1' RequestID='ID-{dp:generate-uuid()}'
        MajorVersion='1'
        xmlns='urn:oasis:names:tc:SAML:1.0:protocol'>
          <AttributeQuery>
            <xsl:copy-of select="$saml-subject"/>
            <xsl:copy-of select="document('config-saml-service.xml')/SAMLServiceConfiguration/QueryAttributes/*"/>
          </AttributeQuery>
        </Request>
      </SOAP:Body>
    </SOAP:Envelope>
  </xsl:variable>


  <!-- 
    Get the url of the saml provider
  -->

  <xsl:variable name="saml-service-location">
    <xsl:copy-of select="document('config-saml-service.xml')/SAMLServiceConfiguration/SAMLServiceLocation"/>
  </xsl:variable>

  <!--
    Set the saml-attribute-statement variable from either the
    input message or from a query to the saml provider.
  -->

  <xsl:variable name="saml-attribute-statement">
    <xsl:choose>

      <xsl:when test="count($input-doc-attr-statement) != 0">
        <xsl:message>input doc attr statement found</xsl:message>
        <xsl:copy-of select="$input-doc-attr-statement"/>
      </xsl:when>

      <xsl:otherwise>
        <xsl:copy-of select="dp:soap-call($saml-service-location, $saml-attr-request, '', 0, '', $http-headers )/*[local-name()='Envelope']/*[local-name()='Body']/*[local-name()='Response']/*[local-name()='Assertion']/*[local-name()='AttributeStatement']"/>
      </xsl:otherwise>

    </xsl:choose>
  </xsl:variable>


  <xsl:variable name="saml-authn-statement">
    <saml:AuthenticationStatement AuthenticationInstant="{$current-time}"
    AuthenticationMethod="urn:oasis:names:tc:SAML:1.0:am:X509-PKI">
      <xsl:copy-of select="$saml-subject"/>
    </saml:AuthenticationStatement>
  </xsl:variable>

  <xsl:variable name="saml-conditions">
    <saml:Conditions NotBefore="{$current-time}" NotOnOrAfter="{$expiration}"></saml:Conditions>
  </xsl:variable>

  <xsl:variable name="saml-assertion">
    <saml:Assertion AssertionID="id-{dp:generate-uuid()}"
                    IssueInstant="{$current-time}"
                    Issuer="{document('config-saml-service.xml')/SAMLServiceConfiguration/DefaultIdentity/Issuer}"
                    MajorVersion="1" MinorVersion="1" wsu:Id="id-{dp:generate-uuid()}">
      <xsl:copy-of select="$saml-conditions" />
      <xsl:copy-of select="$saml-authn-statement" />
      <xsl:copy-of select="$saml-attribute-statement" />
    </saml:Assertion>
  </xsl:variable>

  <!-- If there's no SOAP Header, add one. -->

  <xsl:template match="/*[local-name()='Envelope'][not(*[local-name()='Header'])]">
    <xsl:copy>
      <SOAP:Header>
        <wsse:Security>
          <xsl:copy-of select="$saml-assertion" />
        </wsse:Security>
      </SOAP:Header>
      <xsl:apply-templates select="*|@*|text()|processing-instruction()|comment()" />
    </xsl:copy>
  </xsl:template>

  <!-- If there's no WS-Security, add one. -->

  <xsl:template match="/*[local-name()='Envelope']/*[local-name()='Header'][not(*[local-name()='Security'])]">
    <xsl:copy>
      <wsse:Security>
        <xsl:apply-templates select="*|@*|text()|processing-instruction()|comment()" />
        <xsl:copy-of select="$saml-assertion" />
      </wsse:Security>
    </xsl:copy>
  </xsl:template>

  <!-- If there's no SAML Assertion, add one. -->

  <xsl:template match="/*[local-name()='Envelope']/*[local-name()='Header']/*[local-name()='Security'][not(*[local-name()='Assertion'])]">
    <xsl:copy>
      <xsl:apply-templates select="*|@*|text()|processing-instruction()|comment()" />
      <xsl:copy-of select="$saml-assertion" />
    </xsl:copy>
  </xsl:template>

  <!-- If there's no SAML AttributeStatement, add one. -->

  <xsl:template match="/*[local-name()='Envelope']/*[local-name()='Header']/*[local-name()='Security']/*[local-name()='Assertion'][not(*[local-name()='AttributeStatement'])]">

    <xsl:copy>
      <xsl:apply-templates select="*|@*|text()|processing-instruction()|comment()" />
      <xsl:copy-of select="$saml-attribute-statement" />
    </xsl:copy>
  </xsl:template>

  <!-- Main processing template -->

  <xsl:template match="/">
    <xsl:message><xsl:value-of select="$saml-attribute-statement"/></xsl:message>

    <xsl:message>Checking that we got an attribute statement</xsl:message>
    <xsl:message>*****************************</xsl:message>
    <xsl:message><xsl:value-of select="string-length($saml-attribute-statement)"/></xsl:message>
    <xsl:message>*****************************</xsl:message>

    <xsl:if test="string-length($saml-attribute-statement)=0">
      <xsl:message>No saml attr statement</xsl:message>
      <dp:reject>Could not get saml attribute statement</dp:reject>
    </xsl:if>

    <xsl:copy>
      <xsl:apply-templates select="*|@*|text()|processing-instruction()|comment()" />
    </xsl:copy>
  </xsl:template>

  <!-- By default, just copy everything. -->
  <xsl:template match="@*|*|processing-instruction()|comment()">
    <xsl:copy>
      <xsl:apply-templates select="*|@*|text()|processing-instruction()|comment()" />
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
